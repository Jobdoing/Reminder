# Baidu LAC Lite

This project redistributes the official Baidu LAC Lite model, dictionaries, C++
inference sources, Paddle Lite headers, and Android/iOS runtime libraries under
the Apache License 2.0.

- Source: https://github.com/baidu/lac
- Source commit: `3e10dbed9bfd87bea927c84a6627a167c17b5617`
- LAC source modifications: none
- Paddle arm64 runtime modification: ELF boundary symbols with invalid local
  binding are normalized to global binding by
  `tool/third_party/normalize_paddle_elf.py` for NDK 28 linker compatibility.
- Integration bridge: `android/app/src/main/cpp/person_ner.cpp`
- iOS runtime: official Paddle Lite v2.6.0 arm64 `with_extra` tiny publish
  library, linked through the local `PaddleLAC` pod.
- iOS bridge: `ios/src/PaddleLACPersonSpanChannel.mm`
- The platform copies of LAC sources and model assets are guarded by
  `test/model_platform_parity_test.dart` and must remain byte-identical.

Asset SHA-256 values:

```text
df087c346e626586fc6d9a7ff2c27bf3ee373bf74577e042f72a8a4c6e541104  model.nb
c776a03c9cfd0f7d250c82d405030ce282d65e0e41083a35f81b8ab7f91aa4c7  q2b.dic
0e10caa505cd12e6f43630505503ccf24ee081f61a155fcc186041601cfd0bfe  tag.dic
fe4cf2f3c6ebfc229d756a2c26934472d7bc8999f3d07d2b8f70a60741782e70  word.dic
e8f4e216b821047ca654923a4954c9856fd5889c3416051985d9385b2187387c  arm64-v8a/libpaddle_lite_jni.so
c4b1a2c5f0f323a23b4be22f62331c013cdf9dce695af053c001c0821c5e464b  armeabi-v7a/libpaddle_light_api_shared.so
02aa1aa024c3657bd5e36c372f587c2e5dcb1e5ed4161e156b073ebac46f7c49  ios/lib/libpaddle_api_light_bundled.a
```

The official iOS archive used to obtain the static library is
`inference_lite_lib.ios.armv8.with_extra.tiny_publish.tar.gz` from Paddle Lite
v2.6.0. Its SHA-256 is
`c073e84dd961c1a753efc4c5e8776b19b1100445b4908f098f6ef4e81a56939e`.
