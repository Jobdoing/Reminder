import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/services/notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reminderNotificationId uses a stable known FNV-1a value', () {
    expect(reminderNotificationId('abc'), 0x1a47e90b);

    const uuid = 'a1b2c3d4-0000-1111-2222-333344445555';
    final a = reminderNotificationId(uuid);
    final b = reminderNotificationId(uuid);
    expect(a, b); // stable for the same id
    expect(a, greaterThanOrEqualTo(0)); // positive
    expect(a, lessThanOrEqualTo(0x7fffffff)); // fits notification id range
  });

  test('different record ids map to different notification ids', () {
    expect(
      reminderNotificationId('id-one'),
      isNot(reminderNotificationId('id-two')),
    );
  });

  test('startedSeriesIds includes started reminders but not future ones', () {
    final ids = NotificationService.startedSeriesIds({
      'past': 999,
      'now': 1000,
      'future': 1001,
      'invalid': '999',
    }, 1000);

    expect(ids, unorderedEquals(['past', 'now']));
  });

  test(
    'schedule permission requests exact alarms when notifications work',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return switch (call.method) {
              'areNotificationsEnabled' => true,
              'canScheduleExactNotifications' => false,
              'requestExactAlarmsPermission' => true,
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      expect(await NotificationService.requestSchedulePermission(), isTrue);
      expect(calls, [
        'areNotificationsEnabled',
        'canScheduleExactNotifications',
        'requestExactAlarmsPermission',
      ]);
    },
  );

  test(
    'schedule permission stops when notification permission is denied',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return false;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      expect(await NotificationService.requestSchedulePermission(), isFalse);
      expect(calls, [
        'areNotificationsEnabled',
        'requestNotificationsPermission',
      ]);
    },
  );

  test('notification settings opens the platform settings page', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    expect(await NotificationService.openNotificationSettings(), isTrue);
    expect(calls, ['openAppNotificationSettings']);
  });

  test('a partial scheduling failure cancels the entire series', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    Hive.init(null);
    await Hive.openBox('reminder_series', bytes: Uint8List(0));
    addTearDown(() async {
      await Hive.close();
    });

    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    var schedules = 0;
    var cancels = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'getNotificationAppLaunchDetails':
              return null;
            case 'areNotificationsEnabled':
            case 'canScheduleExactNotifications':
              return true;
            case 'zonedSchedule':
              schedules++;
              if (schedules == 2) {
                throw PlatformException(code: 'SCHEDULE_FAILED');
              }
              return null;
            case 'cancel':
              cancels++;
              return null;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await NotificationService.init();
    await expectLater(
      NotificationService.scheduleSeries(
        recordId: 'partial',
        body: '吃藥',
        at: DateTime.now().add(const Duration(hours: 1)),
      ),
      throwsA(isA<PlatformException>()),
    );

    expect(schedules, 2);
    expect(cancels, 7);
    expect(Hive.box('reminder_series').containsKey('partial'), isFalse);
  });
}
