// lib/l10n/enum_labels.dart
import '../core/utils/greeting.dart';
import 'generated/app_localizations.dart';

/// 枚举值 → 显示文案的映射表。
///
/// ⚠️ **只改「给人看的字」，不碰存储与匹配用的值。**
///
/// 键是契约定义的英文码（`normal` / `pregnant` / `pork` …），与
/// `UserPreferences` 里存的值、以及提交给服务端的值完全一致 ——
/// 所以新增语言时只改这里，不会影响任何数据（契约「枚举编码」一节）。
///
/// 对不认识的码一律**原样返回**，不返回空串：这样既便于发现脏数据，
/// 也让 [dietModeOption] 那组包装能据此判断「本地还没有这条文案」。
extension EnumLabels on AppLocalizations {
  String dayPart(DayPart part) => switch (part) {
        DayPart.morning => greetingMorning,
        DayPart.noon => greetingNoon,
        DayPart.evening => greetingEvening,
      };

  String dietMode(String value) => switch (value) {
        'normal' => dietNormal,
        'vegetarian' => dietVegetarian,
        _ => value,
      };

  String crowd(String value) => switch (value) {
        'pregnant' => crowdPregnant,
        'student' => crowdStudent,
        'fitness' => crowdFitness,
        'elderly' => crowdElderly,
        'athlete' => crowdAthlete,
        _ => value,
      };

  String avoidFood(String value) => switch (value) {
        'pork' => avoidPork,
        'beef' => avoidBeef,
        'seafood' => avoidSeafood,
        'cilantro' => avoidCilantro,
        'spicy' => avoidSpicy,
        _ => value,
      };

  /// 一串人群值 → 「孕妇/学生」这样的展示串
  String crowdList(List<String> values) => values.map(crowd).join('/');

  // --- 字典项的展示文案 ---
  //
  // 后端是数据驱动的：往字典表加一行就能下发新选项，前端无需发版。所以本地映射
  // 表**一定**会滞后于服务端。这三个包装负责在本地还没这份文案时回退到服务端
  // 下发的 label，避免把 `vegan` 这种英文码直接露给用户。

  String dietModeOption(String code, String serverLabel) =>
      _preferLocal(code, serverLabel, dietMode);

  String crowdOption(String code, String serverLabel) =>
      _preferLocal(code, serverLabel, crowd);

  String avoidFoodOption(String code, String serverLabel) =>
      _preferLocal(code, serverLabel, avoidFood);

  String _preferLocal(
    String code,
    String serverLabel,
    String Function(String) translate,
  ) {
    final translated = translate(code);
    if (translated != code) return translated;
    // 本地没有这条文案：用服务端下发的 label；它也没有才退回码本身。
    return serverLabel.isEmpty ? code : serverLabel;
  }
}
