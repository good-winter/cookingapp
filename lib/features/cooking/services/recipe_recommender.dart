// lib/features/cooking/services/recipe_recommender.dart
import '../../../models/user_preferences.dart';
import '../models/recipe.dart';

/// 根据用户的饮食偏好筛选并排序菜谱。
///
/// 纯函数：不读全局状态、不碰 UI，也不会修改传入的 [all]。
///
/// 规则：
///  - **饮食习惯**（素食主义）：只保留带「素食」标签的菜 —— 硬过滤
///  - **忌口/过敏**：命中任一忌口标签的菜直接剔除 —— 硬过滤
///  - **人群**：只调整顺序，一道都不删 —— 命中的排前面
List<Recipe> recommendRecipes({
  required List<Recipe> all,
  required UserPreferences prefs,
}) {
  final suitable = all.where((recipe) => _isSuitable(recipe, prefs));

  // 没选人群就保持原顺序
  if (prefs.crowds.isEmpty) return suitable.toList();

  return _crowdFirst(suitable, prefs.crowds);
}

/// 这道菜是否符合用户的饮食习惯和忌口
bool _isSuitable(Recipe recipe, UserPreferences prefs) {
  if (prefs.dietMode == '素食主义' && !recipe.tags.contains('素食')) {
    return false;
  }
  return !recipe.avoidTags.any(prefs.avoidFoods.contains);
}

/// 把命中人群的菜排到前面。
///
/// 这里故意不用 `List.sort`：Dart 的排序**不保证稳定**，菜谱数量一多
/// （接后端之后就是几十上百条），没命中的菜顺序会被打乱成随机的。
/// 分组再拼接是 O(n) 且稳定的 —— 没命中的菜严格保持原有顺序。
List<Recipe> _crowdFirst(Iterable<Recipe> recipes, List<String> crowds) {
  final matched = <Recipe>[];
  final rest = <Recipe>[];

  for (final recipe in recipes) {
    if (recipe.tags.any(crowds.contains)) {
      matched.add(recipe);
    } else {
      rest.add(recipe);
    }
  }

  return [...matched, ...rest];
}
