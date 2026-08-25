import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/semantic/intent_classifier.dart';
import 'package:reminder/semantic/note_analysis.dart';

void main() {
  const c = IntentClassifier();
  final cases = {
    '打電話給小明': Intent.call,
    '明天去看王醫師': Intent.visit,
    '早上吃藥': Intent.medication,
    '去超市買菜': Intent.shopping,
    '晚上七點吃飯': Intent.meal,
    '週末跟朋友聚餐': Intent.meal,
    '明天上課': Intent.classSession,
    '早上去散步運動': Intent.exercise,
    '下週要看投資基金': Intent.investment,
    '週五跟小美約會': Intent.date,
    '下午去拜訪老朋友': Intent.visitor,
    '參加小明的婚禮': Intent.social,
    '下午開會': Intent.work,
    '下週出國旅遊': Intent.travel,
    '孫子生日': Intent.birthday, // birthday keyword before family
    '打給兒子': Intent.call, // call keyword wins over family
    '記得倒垃圾': Intent.reminder,
    '今天天氣很好': Intent.record,
  };
  cases.forEach((text, want) {
    test('"$text" -> $want', () => expect(c.classify(text), want));
  });

  test('social visit is not classified as medical care', () {
    expect(c.classify('明天去拜訪王先生'), Intent.visitor);
  });

  test('specific new category wins over a broader existing category', () {
    expect(c.classify('旅遊聚會'), Intent.travel);
    expect(c.classify('約會開會'), Intent.date);
  });
}
