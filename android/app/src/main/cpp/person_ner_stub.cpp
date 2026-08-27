#include <jni.h>

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_pyramius_reminder_PersonDetector_detectNative(
    JNIEnv* env,
    jobject,
    jstring,
    jstring) {
  jclass string_class = env->FindClass("java/lang/String");
  return env->NewObjectArray(0, string_class, nullptr);
}
