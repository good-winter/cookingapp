// lib/features/cooking/models/recipe_page.dart

import 'recipe.dart';

/// `GET /recipes/recommend` 的响应：一页菜谱 + 下一页游标。
///
/// 游标是**不透明**的（契约如此规定），前端只能原样回传，不能解析或自己拼。
class RecipePage {
  const RecipePage({required this.items, this.nextCursor});

  final List<Recipe> items;

  /// null 表示没有下一页（契约：`nextCursor` 为 null 或缺失都表示结束）。
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory RecipePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return RecipePage(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => Recipe.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
