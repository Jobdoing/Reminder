#include <jni.h>

#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "lac.h"

namespace {
std::mutex predictor_mutex;
std::unique_ptr<LAC> predictor;
std::string loaded_model_path;
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_pyramius_reminder_PersonDetector_detectNative(
    JNIEnv* env,
    jobject,
    jstring model_path,
    jstring source_text) {
  const char* model_chars = env->GetStringUTFChars(model_path, nullptr);
  const char* text_chars = env->GetStringUTFChars(source_text, nullptr);
  const std::string model(model_chars);
  const std::string text(text_chars);
  env->ReleaseStringUTFChars(model_path, model_chars);
  env->ReleaseStringUTFChars(source_text, text_chars);

  std::vector<std::string> people;
  {
    std::lock_guard<std::mutex> lock(predictor_mutex);
    if (!predictor || loaded_model_path != model) {
      predictor = std::make_unique<LAC>(model, 1);
      loaded_model_path = model;
    }
    for (const auto& item : predictor->lexer(text)) {
      if (item.tag == "PER") people.push_back(item.word);
    }
  }

  jclass string_class = env->FindClass("java/lang/String");
  jobjectArray output = env->NewObjectArray(
      static_cast<jsize>(people.size()), string_class, nullptr);
  for (size_t index = 0; index < people.size(); ++index) {
    env->SetObjectArrayElement(
        output,
        static_cast<jsize>(index),
        env->NewStringUTF(people[index].c_str()));
  }
  return output;
}
