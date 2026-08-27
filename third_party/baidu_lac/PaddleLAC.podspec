Pod::Spec.new do |spec|
  spec.name = 'PaddleLAC'
  spec.version = '2.6.0'
  spec.summary = 'On-device Baidu LAC PERSON detection for iOS.'
  spec.homepage = 'https://github.com/baidu/lac'
  spec.license = { type: 'Apache-2.0', file: 'PADDLE_LITE_LICENSE' }
  spec.author = 'Baidu'
  spec.source = {
    git: 'https://github.com/PaddlePaddle/Paddle-Lite.git',
    tag: 'v2.6.0',
  }
  spec.platform = :ios, '13.0'
  spec.source_files = 'ios/src/**/*.{h,mm,cpp}'
  spec.public_header_files = 'ios/src/PaddleLACPersonSpanChannel.h'
  spec.private_header_files = 'ios/src/lac.h', 'ios/src/lac_util.h'
  spec.preserve_paths = 'ios/include/**/*', 'ios/lib/libpaddle_api_light_bundled.a'
  spec.resource_bundles = {
    'PaddleLACModels' => ['ios/assets/lac_model/*'],
  }
  spec.dependency 'Flutter'
  spec.libraries = 'c++'
  spec.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/ios/include" "${PODS_TARGET_SRCROOT}/ios/src"',
    'EXCLUDED_SOURCE_FILE_NAMES[sdk=iphonesimulator*]' => 'lac.cpp lac_util.cpp',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '"${PODS_TARGET_SRCROOT}/ios/lib/libpaddle_api_light_bundled.a"',
  }
end
