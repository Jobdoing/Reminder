import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Stable, positive 31-bit base id derived from a record's UUID.
/// Dart hashCode is not stable across app launches, so use fixed FNV-1a.
int reminderNotificationId(String recordId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in recordId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

// A reminder fires as a short series so it keeps ringing for a while, but is
// capped (~2 minutes) so it always stops on its own, and can be stopped at any
// time via the "停止" action or by opening the app.
const int _seriesCount = 7; // ~2 minutes total
const int _seriesIntervalSeconds = 18; // relaxed cadence (calm, not urgent)
const String _reminderCategory = 'reminder';
const String _reminderChannelId = 'reminders_alarm_v2';

int _seriesId(String recordId, int i) =>
    (reminderNotificationId(recordId) & 0x7fffff00) + i;

// Tapping the notification or its "停止" action cancels the rest of the series.
@pragma('vm:entry-point')
void _onNotificationTap(NotificationResponse response) {
  final rid = response.payload;
  if (rid != null && rid.isNotEmpty) {
    NotificationService.cancelSeries(rid);
  }
}

/// Local reminder notifications: fire at the reminder time with a custom sound,
/// repeated (capped) so they keep ringing until stopped.
///
/// Three ways to stop, any one works:
///  1. the "停止" button on the notification,
///  2. opening the app (see [stopActive]),
///  3. the built-in ~2 minute cap.
///
/// NOTE(ceiling): time zone hardcoded to Asia/Taipei (UTC+8, no DST) because the
/// target users are in Taiwan and the timezone package can't read the device
/// zone by itself. Add flutter_timezone for other regions.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // Tracks each ringing series by recordId → start time (epoch ms). Persisted so
  // that opening the app after a cold start can still stop a series that is
  // ringing. iOS clears the delivered banner on foreground, so we cannot rely on
  // querying delivered notifications to know what is ringing.
  static const _seriesBoxName = 'reminder_series';
  static Box? get _seriesBox =>
      Hive.isBoxOpen(_seriesBoxName) ? Hive.box(_seriesBoxName) : null;

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_seriesBoxName)) {
      await Hive.openBox(_seriesBoxName);
    }
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _reminderCategory,
              actions: [
                DarwinNotificationAction.plain(
                  'stop',
                  '停止',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
    );
    // If launched by tapping a reminder, stop the rest of its series.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final rid = launch?.notificationResponse?.payload;
    if (rid != null && rid.isNotEmpty) {
      await cancelSeries(rid);
    }
    _ready = true;
  }

  /// Ask the user for permission to show notifications.
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    if (androidGranted != null) return androidGranted;

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  /// Requests every permission required to deliver a scheduled reminder.
  static Future<bool> requestSchedulePermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final notificationsEnabled =
          await android.areNotificationsEnabled() ?? false;
      if (!notificationsEnabled) {
        final granted = await android.requestNotificationsPermission() ?? false;
        if (!granted) return false;
      }

      final exactEnabled =
          await android.canScheduleExactNotifications() ?? false;
      if (exactEnabled) return true;
      return await android.requestExactAlarmsPermission() ?? false;
    }

    return requestPermission();
  }

  static Future<bool> openNotificationSettings() async =>
      await _plugin.openAppNotificationSettings() ?? false;

  /// Schedule a repeating reminder series starting at [at]. No-op if not
  /// initialised. Occurrences already in the past are skipped.
  static Future<void> scheduleSeries({
    required String recordId,
    required String body,
    required DateTime at,
  }) async {
    if (!_ready) return;
    final now = DateTime.now();
    if (!at.isAfter(now)) {
      throw ArgumentError.value(
        at,
        'at',
        'Reminder time must be in the future',
      );
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null &&
        (await android.areNotificationsEnabled() != true ||
            await android.canScheduleExactNotifications() != true)) {
      throw StateError('Scheduled reminder permission is not granted');
    }
    try {
      for (var i = 0; i < _seriesCount; i++) {
        final fireAt = at.add(Duration(seconds: i * _seriesIntervalSeconds));
        await _plugin.zonedSchedule(
          id: _seriesId(recordId, i),
          title: '提醒',
          body: body,
          payload: recordId,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          notificationDetails: _details,
        );
      }
      // Remember when this series starts so foregrounding can stop it later.
      await _seriesBox?.put(recordId, at.millisecondsSinceEpoch);
    } catch (error, stackTrace) {
      // Never leave a partly scheduled reminder series behind.
      await cancelSeries(recordId);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Cancel every occurrence of a reminder series (pending and delivered).
  /// Cancels are issued in parallel so all the platform-channel messages are
  /// posted in one event-loop turn — critical because this often runs in the
  /// brief foreground moment after a notification tap, before iOS may suspend
  /// the app. Sequential awaits would leave a suspension point between each,
  /// letting later occurrences still fire if the user leaves immediately.
  static Future<void> cancelSeries(String recordId) async {
    await Future.wait([
      for (var i = 0; i < _seriesCount; i++)
        _plugin.cancel(id: _seriesId(recordId, i)),
    ]);
    await _seriesBox?.delete(recordId);
  }

  /// Stop every reminder series that has already started ringing. Called when
  /// the app comes to the foreground, so "open the app" stops the noise. Series
  /// scheduled for the future (start time still ahead) are left untouched, so a
  /// reminder for later today/tomorrow is not cancelled just by opening the app.
  ///
  /// Uses the persisted start times rather than querying iOS for delivered
  /// notifications, which are cleared once the app is foregrounded — the reason
  /// the previous approach let a later occurrence still fire.
  static Future<void> stopActive() async {
    if (!_ready) return;
    final box = _seriesBox;
    if (box == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final recordId in startedSeriesIds(box.toMap(), now)) {
      await cancelSeries(recordId);
    }
  }

  /// recordIds whose series has already started (start <= [nowMs]); these are
  /// the ones "open the app" should stop. Reminders still scheduled for the
  /// future are excluded so foregrounding never cancels them.
  static List<String> startedSeriesIds(
    Map<dynamic, dynamic> entries,
    int nowMs,
  ) {
    final out = <String>[];
    entries.forEach((k, v) {
      if (v is int && v <= nowMs) out.add(k as String);
    });
    return out;
  }

  static const NotificationDetails _details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      sound: 'y2408.caf',
      subtitle: '銀髮記憶',
      categoryIdentifier: _reminderCategory,
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    ),
    android: AndroidNotificationDetails(
      _reminderChannelId,
      '提醒鈴聲',
      channelDescription: '需要準時顯示及播放聲音的提醒',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('y2408'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('stop', '停止'),
      ],
    ),
  );
}
