// lib/l10n/enum_labels.dart
import '../core/utils/greeting.dart';
import 'generated/app_localizations.dart';

/// 枚举值 → 显示文案的映射表。
///
/// ⚠️ **只改「给人看的字」，不碰存储与匹配用的值。**
///
/// `UserPreferences` 里存的仍是中文常量（`'素食主义'` 等），
/// `recipe_recommender` 也仍按那些值做匹配 —— 这张表只负责把它们渲染成
/// 当前界面语言的文字。所以**新增语言时只改这里，不会影响业务逻辑**。
///
/// 等接口契约的枚举编码落地（`vegetarian` / `pork` …），这张表的键换成
/// 英文码即可，结构完全不变。契约 docs/API_CONTRACT.md 同样要求前端提供这张表。
extension EnumLabels on AppLocalizations {
  String dayPart(DayPart part) => switch (part) {
        DayPart.morning => greetingMorning,
        DayPart.noon => greetingNoon,
        DayPart.evening => greetingEvening,
      };

  String dietMode(String value) => switch (value) {
        '正常人' => dietNormal,
        '素食主义' => dietVegetarian,
        // 不认识的值原样显示 —— 总好过显示空白，也便于发现脏数据
        _ => value,
      };

  String crowd(String value) => switch (value) {
        '孕妇' => crowdPregnant,
        '学生' => crowdStudent,
        '健身人群' => crowdFitness,
        '老人' => crowdElderly,
        '运动员' => crowdAthlete,
        _ => value,
      };

  String avoidFood(String value) => switch (value) {
        '猪肉' => avoidPork,
        '牛肉' => avoidBeef,
        '海鲜' => avoidSeafood,
        '香菜' => avoidCilantro,
        '辛辣' => avoidSpicy,
        _ => value,
      };

  /// 一串人群值 → 「孕妇/学生」这样的展示串
  String crowdList(List<String> values) => values.map(crowd).join('/');
}
