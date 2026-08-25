import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android notifications are configured without a startup permission prompt',
    () {
      final service = File(
        'lib/services/notification_service.dart',
      ).readAsStringSync();

      expect(
        service,
        contains("AndroidInitializationSettings('@mipmap/ic_launcher')"),
      );
      expect(service, contains('requestNotificationsPermission()'));
      expect(service, contains("AndroidNotificationAction('stop', '停止'"));
      expect(
        service,
        contains(
          'onDidReceiveBackgroundNotificationResponse: _onNotificationTap',
        ),
      );
      expect(service, contains("'reminders_alarm_v2'"));
      expect(service, contains("'提醒鈴聲'"));
      expect(service, contains("RawResourceAndroidNotificationSound('y2408')"));
      expect(
        service,
        contains('audioAttributesUsage: AudioAttributesUsage.alarm'),
      );
      expect(service, contains('visibility: NotificationVisibility.public'));
      expect(service, contains('presentBanner: true'));
      expect(service, contains('presentList: true'));
      expect(service, contains('interruptionLevel: InterruptionLevel.active'));

      final main = File('lib/main.dart').readAsStringSync();
      expect(main, isNot(contains('NotificationService.requestPermission()')));

      final settings = File(
        'lib/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(settings, isNot(contains('測試通知')));
      expect(service, isNot(contains('scheduleTest')));
      expect(settings, contains('設定提醒顯示與聲音'));
    },
  );
}
