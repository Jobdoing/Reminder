# Baidu LAC Lite

This project redistributes the official Baidu LAC Android Lite model,
dictionaries, C++ inference sources, Paddle Lite headers, and Android runtime
libraries under the Apache License 2.0.

- Source: https://github.com/baidu/lac
- Source commit: `3e10dbed9bfd87bea927c84a6627a167c17b5617`
- LAC source modifications: none
- Paddle arm64 runtime modification: ELF boundary symbols with invalid local
  binding are normalized to global binding by
  `tool/third_party/normalize_paddle_elf.py` for NDK 28 linker compatibility.
- Integration bridge: `android/app/src/main/cpp/person_ner.cpp`

Asset SHA-256 values:

```text
df087c346e626586fc6d9a7ff2c27bf3ee373bf74577e042f72a8a4c6e541104  model.nb
c776a03c9cfd0f7d250c82d405030ce282d65e0e41083a35f81b8ab7f91aa4c7  q2b.dic
0e10caa505cd12e6f43630505503ccf24ee081f61a155fcc186041601cfd0bfe  tag.dic
fe4cf2f3c6ebfc229d756a2c26934472d7bc8999f3d07d2b8f70a60741782e70  word.dic
e8f4e216b821047ca654923a4954c9856fd5889c3416051985d9385b2187387c  arm64-v8a/libpaddle_lite_jni.so
c4b1a2c5f0f323a23b4be22f62331c013cdf9dce695af053c001c0821c5e464b  armeabi-v7a/libpaddle_light_api_shared.so
```
