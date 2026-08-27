import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android and iOS package byte-identical LAC sources and model assets',
    () {
      final pairs = {
        for (final name in ['lac.cpp', 'lac.h', 'lac_util.cpp', 'lac_util.h'])
          'android/app/src/main/cpp/$name':
              'third_party/baidu_lac/ios/src/$name',
        for (final name in ['model.nb', 'q2b.dic', 'tag.dic', 'word.dic'])
          'android/app/src/main/assets/lac_model/$name':
              'third_party/baidu_lac/ios/assets/lac_model/$name',
      };

      for (final pair in pairs.entries) {
        expect(
          File(pair.value).readAsBytesSync(),
          File(pair.key).readAsBytesSync(),
          reason: '${pair.key} and ${pair.value} must stay identical',
        );
      }
    },
  );

  test('iOS registers the shared PERSON channel and production runtime', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final service = File(
      'lib/services/person_span_service.dart',
    ).readAsStringSync();
    final runtime = File(
      'third_party/baidu_lac/ios/lib/libpaddle_api_light_bundled.a',
    );

    expect(appDelegate, contains('PaddleLACPersonSpanChannel.register'));
    expect(podfile, contains("pod 'PaddleLAC'"));
    expect(service, contains('Platform.isIOS'));
    expect(runtime.lengthSync(), 41056112);
  });
}
