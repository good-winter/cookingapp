// lib/features/cooking/models/recipe.dart

/// 一道菜谱。
///
/// 目前数据写死在 data/mock_recipes.dart；接入后端后换成接口返回的
/// Model 即可，只要保持这几个字段不变，筛选逻辑和 UI 都不用动。
class Recipe {
  final String name;
  final String emoji;
  final String time;

  /// 属性标签，如 ['孕妇', '学生', '素食'] —— 同时用于人群匹配和素食判断
  final List<String> tags;

  /// 忌口标签，如 ['猪肉'] —— 和用户的忌口列表求交集，命中就剔除
  final List<String> avoidTags;

  const Recipe(this.name, this.emoji, this.time, this.tags, this.avoidTags);
}
