import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/greeting.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../providers/preference_provider.dart';
import '../data/mock_recipes.dart';
import '../models/recipe.dart';
import '../services/recipe_recommender.dart';
import '../widgets/preference_modal.dart';

class CookingScreen extends ConsumerWidget {
  const CookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferenceProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    // 👤 这里预留后端对接：未来通过API获取用户的昵称
    final String userName = "美食家";

    // 按偏好筛选 + 排序，规则都在 services/recipe_recommender.dart 里
    final filteredRecipes = recommendRecipes(all: mockRecipes, prefs: prefs);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // --- 顶部栏：头像 + 动态问候语 + 用户画像入口 ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 动态问候语
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // 🕒 时段判断在 core/utils/greeting.dart，文案在 l10n
                          '$userName, ${l10n.dayPart(dayPartForHour(DateTime.now().hour))}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.cookingSubtitle,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    // 用户画像入口
                    GestureDetector(
                      onTap: () => _showPreferenceModal(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.cardShadow(context),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              l10n.dietMode(prefs.dietMode),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Icon(Icons.arrow_drop_down, size: 16, color: scheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 扩大后的 AI 拍照识别区域 (核心区域，占据剩余空间) ---
              Expanded(
                flex: 3, // 占据高度的主要部分
                child: GestureDetector(
                  onTap: () {
                    // TODO: 未来在这里唤起相机并调用后端 AI 识别接口
                    debugPrint('唤起相机');
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.softPrimary(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFF7A00), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 64, color: Color(0xFFFF7A00)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.cookingCameraTitle,
                          style: const TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.cookingCameraSubtitle,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 缩小后的推荐区域 (单行横向滑动) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.cookingRecommendTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    prefs.crowds.isEmpty
                        ? l10n.cookingRecommendAll
                        : l10n.cookingRecommendFor(l10n.crowdList(prefs.crowds)),
                    style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 固定高度，只展示一行
              SizedBox(
                height: 130, // 高度限制，防止占据太多屏幕
                child: filteredRecipes.isEmpty
                    ? Center(child: Text(l10n.cookingNoResults))
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    return _buildHorizontalRecipeCard(context, recipe);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 弹出偏好设置底部弹窗
  void _showPreferenceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PreferenceModal(),
    );
  }

  // 渲染横向滑动的单个菜谱卡片（改小了尺寸）
  Widget _buildHorizontalRecipeCard(BuildContext context, Recipe recipe) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 150, // 固定宽度，实现横向滑动
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(child: Text(recipe.emoji, style: const TextStyle(fontSize: 32))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(recipe.time, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}