import 'package:reminder/screens/privacy_policy_screen.dart';
import 'package:reminder/screens/settings_screen.dart';
import 'package:reminder/services/contact_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  testWidgets('privacy policy is available from settings', (tester) async {
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('contacts', bytes: Uint8List(0));
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.tap(find.text('隱私政策'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('永遠免費與開放原始碼'), findsOneWidget);
    expect(find.textContaining('「銀髮記憶」官方版本永遠免費'), findsOneWidget);
    expect(find.textContaining('Apache License 2.0'), findsOneWidget);
    expect(find.textContaining('不會上傳到本 App 開發者的伺服器'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('https://github.com/Jobdoing/Reminder/issues'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining('https://github.com/Jobdoing/Reminder/issues'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });

  testWidgets('clear removes only the app contact list after confirmation', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('contacts', bytes: Uint8List(0));
      await ContactStore.setNames(['王小明', '陳美玲']);
    });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    expect(find.text('王小明\n陳美玲'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '清除').first);
    await tester.pumpAndSettle();
    expect(find.text('只會清除 App 內的名單，不會刪除手機聯絡人。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();

    expect(ContactStore.names(), isEmpty);
    expect(find.text('王小明\n陳美玲'), findsNothing);
    expect(find.text('已清除 App 內的聯絡人'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });

  testWidgets('denied contact permission offers to open app settings', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('contacts', bytes: Uint8List(0));
    });
    var openedSettings = false;
    const channel = MethodChannel('flutter_contacts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'permissions.request') {
            return 'permanentlyDenied';
          }
          if (call.method == 'permissions.openSettings') {
            openedSettings = true;
            return null;
          }
          return null;
        });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.tap(find.text('載入手機聯絡人'));
    await tester.pumpAndSettle();

    expect(find.text('需要聯絡人權限'), findsOneWidget);
    expect(find.text('請在下一頁開啟「聯絡人」，再回到 App 重新匯入。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '開啟系統設定'));
    await tester.pumpAndSettle();
    expect(openedSettings, isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });

  testWidgets('reload replaces stale app contacts with current device names', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('contacts', bytes: Uint8List(0));
      await ContactStore.setNames(['Old Name', 'Manual Name']);
    });
    const channel = MethodChannel('flutter_contacts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'permissions.request') return 'granted';
          if (call.method == 'crud.getAll') {
            return <Map<String, dynamic>>[
              {'id': '1', 'displayName': 'Current Name'},
              {'id': '2', 'displayName': 'Current Name'},
              {'id': '3', 'displayName': '   '},
            ];
          }
          return null;
        });

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.tap(find.text('載入手機聯絡人'));
    await tester.pumpAndSettle();

    expect(ContactStore.names(), ['Current Name']);
    expect(find.text('Current Name'), findsOneWidget);
    expect(find.textContaining('Old Name'), findsNothing);
    expect(find.text('已匯入，共 1 位聯絡人'), findsOneWidget);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });

  testWidgets('settings stays usable with large text', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('contacts', bytes: Uint8List(0));
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('載入手機聯絡人'), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });

  testWidgets('reminder settings guidance matches the phone platform', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('contacts', bytes: Uint8List(0));
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const SettingsScreen(),
        ),
      );
      await tester.tap(find.text('設定提醒顯示與聲音'));
      await tester.pumpAndSettle();

      if (platform == TargetPlatform.android) {
        expect(find.textContaining('手機不是震動模式'), findsOneWidget);
        expect(find.textContaining('手機不是靜音模式'), findsNothing);
      } else {
        expect(find.textContaining('手機不是靜音模式'), findsOneWidget);
        expect(find.textContaining('Android'), findsNothing);
      }

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });
}
