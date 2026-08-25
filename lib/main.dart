import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'services/contact_store.dart';
import 'services/notification_service.dart';
import 'services/part_of_day_store.dart';
import 'services/photo_store.dart';
import 'services/record_store.dart';
import 'services/stt/native_stt_service.dart';
import 'services/stt/stt_service.dart';
import 'services/stt/stub_stt_service.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the UI portrait for a stable elderly layout; the captured photo
  // orientation follows the physical device orientation (see CameraScreen).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  PhotoStore.init(dir);
  await RecordStore.init();
  await ContactStore.init();
  await PartOfDayStore.init();
  await NotificationService.init();
  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '銀髮記憶',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 28),
          bodyMedium: TextStyle(fontSize: 24),
        ),
      ),
      home: CameraScreen(stt: _sttService()),
    );
  }
}

/// iOS and Android use their native speech recognizers. Desktop platforms
/// retain the typing stub because this app currently targets phones.
SttService _sttService() => Platform.isIOS || Platform.isAndroid
    ? NativeSttService.instance
    : StubSttService();
