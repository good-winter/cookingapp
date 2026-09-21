import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/preference_provider.dart';
import '../widgets/preference_modal.dart';

// 模拟菜谱数据结构（未来替换为后端返回的Model）
class MockRecipe {
  final String name;
  final String emoji;
  final String time;
  final List<String> tags;
  final List<String> avoidTags;

  MockRecipe(this.name, this.emoji, this.time, this.tags, this.avoidTags);
}

// 模拟数据库
final mockRecipes = [
  MockRecipe('番茄炒蛋', '🍲', '10分钟', ['孕妇', '学生', '素食'], []),
  MockRecipe('红烧肉', '🥩', '45分钟', ['正常人'], ['猪肉']),
  MockRecipe('香煎鸡胸肉', '🍗', '15分钟', ['健身人群', '运动员'], []),
  MockRecipe('清蒸鲈鱼', '🐟', '20分钟', ['老人', '孕妇'], ['海鲜']),
  MockRecipe('麻婆豆腐', '🌶️', '15分钟', ['学生', '正常人'], ['辛辣']),
  MockRecipe('白灼西兰花', '🥦', '8分钟', ['健身人群', '素食', '老人'], []),
];

class CookingScreen extends ConsumerWidget {
  const CookingScreen({super.key});

  // 🕒 获取基于时间的问候语（纯前端逻辑）
  String _getGreeting() {
    // 这里为了演示固定了时间，实际开发中请使用下面注释掉的代码
    // final hour = DateTime.now().hour;
    final hour = 8; // 模拟早上8点

    if (hour >= 5 && hour < 12) {
      return '早上好';
    } else if (hour >= 12 && hour < 18) {
      return '中午好';
    } else {
      return '晚上好';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferenceProvider);

    // 👤 这里预留后端对接：未来通过API获取用户的昵称
    final String userName = "美食家";

    // 1. 过滤逻辑
    List<MockRecipe> filteredRecipes = mockRecipes.where((recipe) {
      if (prefs.dietMode == '素食主义' && !recipe.tags.contains('素食')) return false;
      for (var avoid in prefs.avoidFoods) {
        if (recipe.avoidTags.contains(avoid)) return false;
      }
      return true;
    }).toList();

    // 2. 排序逻辑 (人群优先)
    if (prefs.crowds.isNotEmpty) {
      filteredRecipes.sort((a, b) {
        bool aMatch = a.tags.any((tag) => prefs.crowds.contains(tag));
        bool bMatch = b.tags.any((tag) => prefs.crowds.contains(tag));
        return (bMatch ? 1 : 0).compareTo(aMatch ? 1 : 0);
      });
    }

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
                          '$userName, ${_getGreeting()}', // 👈 触发动态问候
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('今天想做点什么？', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    // 用户画像入口
                    GestureDetector(
                      onTap: () => _showPreferenceModal(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              prefs.dietMode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
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
                      color: const Color(0xFFFFF0E5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFF7A00), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 64, color: Color(0xFFFF7A00)),
                        const SizedBox(height: 16),
                        const Text(
                          'AI 拍照识别食材',
                          style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '自动判断荤素与新鲜度，保障饮食安全',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
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
                  const Text('🔥 为你推荐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    prefs.crowds.isEmpty ? '(综合推荐)' : '(适配: ${prefs.crowds.join("/")})',
                    style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 固定高度，只展示一行
              SizedBox(
                height: 130, // 高度限制，防止占据太多屏幕
                child: filteredRecipes.isEmpty
                    ? const Center(child: Text('没有找到符合您当前偏好的菜谱。'))
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    return _buildHorizontalRecipeCard(recipe, prefs.crowds);
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
  Widget _buildHorizontalRecipeCard(MockRecipe recipe, List<String> userCrowds) {
    return Container(
      width: 150, // 固定宽度，实现横向滑动
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
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
                Text(recipe.time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}