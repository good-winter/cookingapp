// lib/features/cooking/models/recipe.dart

/// 菜谱的营养构成，三项百分比之和为 100。
///
/// ⚠️ 种子数据里的数值是**演示用估值**，不是营养学准确数据（契约「未决事项」）。
class Nutrition {
  const Nutrition({
    this.carbsPercent = 0,
    this.proteinPercent = 0,
    this.fatPercent = 0,
  });

  final int carbsPercent;
  final int proteinPercent;
  final int fatPercent;

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      carbsPercent: _asInt(json['carbsPercent']),
      proteinPercent: _asInt(json['proteinPercent']),
      fatPercent: _asInt(json['fatPercent']),
    );
  }
}

/// 一道菜谱，对应契约「数据模型 → Recipe」。
///
/// 筛选与排序已迁到服务端（`GET /recipes/recommend` 按当前偏好算好后返回），
/// 所以这里不再有「按偏好筛掉荤菜 / 剔除忌口」的逻辑 —— `isVegetarian` 与
/// `crowds` 现在只用于展示。
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cookTimeMinutes,
    required this.isVegetarian,
    required this.calories,
    required this.nutrition,
    this.imageUrl,
    this.crowds = const [],
    this.avoidTags = const [],
  });

  final String id;
  final String name;
  final String emoji;

  /// 契约里可为 null —— 种子数据没有配图，此时返回 null 而不是空串。
  final String? imageUrl;

  /// 契约把原来的字符串 `'10分钟'` 改成了数字，展示文案由前端自行格式化
  /// （见 [cookTimeText]）。数字才好排序与统计。
  final int cookTimeMinutes;

  final bool isVegetarian;

  /// 适配人群的英文码，如 `['pregnant', 'student']`。
  final List<String> crowds;

  /// 忌口标签的英文码，如 `['pork']`。
  final List<String> avoidTags;

  /// 单位 kcal。
  final int calories;

  final Nutrition nutrition;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      cookTimeMinutes: _asInt(json['cookTimeMinutes']),
      isVegetarian: json['isVegetarian'] as bool? ?? false,
      crowds: _stringList(json['crowds']),
      avoidTags: _stringList(json['avoidTags']),
      calories: _asInt(json['calories']),
      nutrition: Nutrition.fromJson(
        (json['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  /// 展示用的时长文案，如「10分钟」。
  String get cookTimeText => '$cookTimeMinutes分钟';
}

/// JSON 里的数字统一走它，避免 int/double 的类型差异让解析炸掉。
int _asInt(Object? value) => value is num ? value.toInt() : 0;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
