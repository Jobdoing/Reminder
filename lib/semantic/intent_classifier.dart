import 'note_analysis.dart';

// NOTE(ceiling): Heuristic priority-ordered keyword match. First matching
// category wins. Ceiling: overlapping phrases (e.g. "打電話去買東西") resolve
// to the first-matched category, which may not reflect the dominant intent.
// Upgrade path: weighted multi-keyword scoring or a small intent model.

class IntentClassifier {
  const IntentClassifier();

  // Priority order: call > visit > medication > shopping > investment > meal >
  // class > exercise > travel > date > visitor > social > work > birthday >
  // family > reminder > record (default).
  // Each entry: (Intent, list of keywords — Traditional AND Simplified variants).
  static const List<(Intent, List<String>)> _rules = [
    (Intent.call, ['打電話', '打给', '打給', '回電', '回电', '通話', '通话']),
    (Intent.visit, ['看醫生', '看医生', '醫師', '医师', '回診', '回诊', '門診', '门诊']),
    (Intent.medication, ['吃藥', '吃药', '拿藥', '拿药', '血壓', '血压', '復健', '复健']),
    (Intent.shopping, ['買', '买', '購物', '购物', '超市', '繳費', '缴费']),
    (Intent.investment, ['投資', '投资', '股票', '基金', '證券', '证券']),
    (Intent.meal, ['吃飯', '吃饭', '聚餐', '晚餐', '午餐', '早餐']),
    (Intent.classSession, ['上課', '上课', '課程', '课程', '講座', '讲座']),
    (Intent.exercise, ['運動', '运动', '散步', '健走', '游泳', '瑜伽', '體操', '体操']),
    (Intent.travel, ['出國', '出国', '旅遊', '旅游', '機票', '机票', '護照', '护照']),
    (Intent.date, ['約會', '约会', '相親', '相亲']),
    (Intent.visitor, ['訪客', '访客', '客人', '來訪', '来访', '拜訪', '拜访']),
    (Intent.social, ['結婚', '结婚', '婚禮', '婚礼', '宴席', '喜酒', '聚會', '聚会']),
    (Intent.work, ['開會', '开会', '會議', '会议', '上班', '報告', '报告']),
    (Intent.birthday, ['生日', '慶生', '庆生', '蛋糕']),
    (Intent.family, ['兒子', '儿子', '女兒', '女儿', '孫子', '孙子', '老伴', '家人']),
    (Intent.reminder, ['記得', '记得', '提醒', '別忘', '别忘']),
  ];

  Intent classify(String text) {
    for (final (intent, keywords) in _rules) {
      for (final kw in keywords) {
        if (text.contains(kw)) return intent;
      }
    }
    return Intent.record;
  }
}
