import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS cold start uses a running explicit Flutter engine', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final sceneDelegate = File(
      'ios/Runner/SceneDelegate.swift',
    ).readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final launchScreen = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();

    expect(
      appDelegate,
      contains('let flutterEngine = FlutterEngine(name: "main")'),
    );
    expect(
      appDelegate,
      contains('guard flutterEngine.run() else { return false }'),
    );
    expect(appDelegate, isNot(contains('FlutterImplicitEngineDelegate')));
    expect(sceneDelegate, contains('engine: appDelegate.flutterEngine'));
    expect(infoPlist, isNot(contains('<key>UISceneStoryboardFile</key>')));
    expect(infoPlist, isNot(contains('<key>UIMainStoryboardFile</key>')));
    expect(infoPlist, contains('<string>銀髮記憶</string>'));
    expect(infoPlist, contains('<string>Reminder</string>'));
    expect(infoPlist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
    expect(infoPlist, contains('<key>UISupportedInterfaceOrientations</key>'));
    expect(infoPlist, isNot(contains('UIInterfaceOrientationLandscape')));
    expect(
      infoPlist,
      isNot(contains('UIInterfaceOrientationPortraitUpsideDown')),
    );
    expect(project, contains('TARGETED_DEVICE_FAMILY = 1;'));
    expect(
      RegExp(r'DEVELOPMENT_TEAM = 3VWR3F7ZZR;').allMatches(project),
      hasLength(6),
    );
    expect(project, isNot(contains('DEVELOPMENT_TEAM = 3QR9879MU8;')));
    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.pyramius\.reminder(?:\.RunnerTests)?;',
      ).allMatches(project),
      hasLength(6),
    );
    expect(project, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2";')));
    expect(launchScreen, isNot(contains('LaunchImage')));
  });

  test('iOS speech may use Apple online recognition when needed', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(appDelegate, contains('requiresOnDeviceRecognition = false'));
    expect(appDelegate, contains('reminder/speech_events'));
    expect(appDelegate, contains('reminder/speech_cmd'));
    expect(appDelegate, isNot(contains('strictly offline; never upload')));
  });
}
