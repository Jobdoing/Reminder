import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android enables core library desugaring for notifications', () {
    final buildFile = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildFile, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(
      buildFile,
      contains(
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
      ),
    );
  });

  test('Android release uses the local upload signing configuration', () {
    final buildFile = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildFile, contains('rootProject.file("key.properties")'));
    expect(buildFile, contains('create("release")'));
    expect(
      buildFile,
      contains('signingConfig = signingConfigs.getByName("release")'),
    );
    expect(
      buildFile,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
  });

  test('Android uses the Reminder application identity', () {
    final buildFile = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildFile, contains('namespace = "com.pyramius.reminder"'));
    expect(buildFile, contains('applicationId = "com.pyramius.reminder"'));
  });

  test('Android declares read access for contact import', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.READ_CONTACTS'));
    expect(manifest, contains('android:label="銀髮記憶"'));
  });

  test('Android removes legacy shared-storage permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final permission in [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]) {
      final declaration = RegExp(
        '<uses-permission\\s+android:name="$permission"\\s+'
        'tools:node="remove"\\s*/>',
      );
      expect(manifest, matches(declaration));
    }
  });

  test('Android declares exact reminder scheduling and reboot recovery', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationReceiver'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(manifest, contains('ActionBroadcastReceiver'));
  });

  test('Android packages a playable WAV reminder sound', () {
    final sound = File('android/app/src/main/res/raw/y2408.wav');

    expect(sound.existsSync(), isTrue);
    final bytes = sound.readAsBytesSync();
    expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
  });

  test('Android uses an adaptive launcher icon without legacy shrinking', () {
    final adaptiveIcon = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final foreground = File(
      'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
    );

    expect(adaptiveIcon, contains('<adaptive-icon'));
    expect(adaptiveIcon, contains('@android:color/white'));
    expect(adaptiveIcon, contains('@drawable/ic_launcher_foreground'));
    expect(foreground.existsSync(), isTrue);
    expect(foreground.readAsBytesSync().sublist(1, 4), [0x50, 0x4e, 0x47]);
  });

  test('Android excludes private records from system backup and transfer', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final legacyRules = File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsStringSync();
    final extractionRules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    for (final domain in [
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ]) {
      expect(legacyRules, contains('domain="$domain"'));
      expect(extractionRules, contains('domain="$domain"'));
    }
  });

  test('Android registers native speech with online fallback', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/pyramius/reminder/MainActivity.kt',
    ).readAsStringSync();
    final speechChannel = File(
      'android/app/src/main/kotlin/com/pyramius/reminder/SpeechChannel.kt',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.speech.RecognitionService'));
    expect(activity, contains('SpeechChannel.register'));
    expect(speechChannel, contains('createOnDeviceSpeechRecognizer'));
    expect(speechChannel, contains('createSpeechRecognizer(context)'));
    expect(speechChannel, contains('triggerModelDownload'));
    expect(speechChannel, contains('reminder/speech_events'));
    expect(speechChannel, contains('reminder/speech_cmd'));
  });
}
