cmake_minimum_required(VERSION 3.22.1)
project(person_ner)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a")
  add_library(
    person_ner
    SHARED
    person_ner.cpp
    lac.cpp
    lac_util.cpp
  )
  target_include_directories(person_ner PRIVATE paddle/include)

  add_library(paddle_runtime SHARED IMPORTED)
  if(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(PADDLE_LIBRARY libpaddle_light_api_shared.so)
  else()
    set(PADDLE_LIBRARY libpaddle_lite_jni.so)
  endif()
  set_target_properties(
    paddle_runtime
    PROPERTIES IMPORTED_LOCATION
    "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/${PADDLE_LIBRARY}"
  )
  target_link_libraries(person_ner PRIVATE paddle_runtime)
else()
  add_library(person_ner SHARED person_ner_stub.cpp)
endif()

find_library(log_library log)
target_link_libraries(person_ner PRIVATE ${log_library})
target_link_options(person_ner PRIVATE "-Wl,-z,max-page-size=16384")
