import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/greeting.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_profile.dart';
import '../../../providers/me_provider.dart';
import '../../../providers/recommend_provider.dart';
import '../models/recipe.dart';
import '../models/recipe_page.dart';
import '../widgets/preference_modal.dart';

class CookingScreen extends ConsumerWidget {
  const CookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final page = ref.watch(recommendProvider);
    final prefs = me.valueOrNull?.preferences;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

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
                          _greetingLine(me, l10n),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.cardShadow(context),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person,
                                size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              // 偏好还没到时显示占位符，别先显示一个会跳变的错值
                              prefs == null
                                  ? '—'
                                  : l10n.dietMode(prefs.dietMode),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Icon(Icons.arrow_drop_down,
                                size: 16, color: scheme.onSurfaceVariant),
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
                        const Icon(Icons.camera_alt,
                            size: 64, color: Color(0xFFFF7A00)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.cookingCameraTitle,
                          style: const TextStyle(
                              color: Color(0xFFFF7A00),
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.cookingCameraSubtitle,
                          style:
                              TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
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
                  Text(l10n.cookingRecommendTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    // 偏好来自服务端；还没到时先说「综合推荐」，别空着
                    prefs == null || prefs.crowds.isEmpty
                        ? l10n.cookingRecommendAll
                        : l10n.cookingRecommendFor(l10n.crowdList(prefs.crowds)),
                    style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildRecommendSection(context, ref, page),
            ],
          ),
        ),
      ),
    );
  }

  /// 问候语。昵称来自 GET /me；首次加载还没到时先只显示问候语，
  /// 而不是先拼出「…, 早上好」再跳变。
  String _greetingLine(AsyncValue<UserProfile> me, AppLocalizations l10n) {
    final greeting = l10n.dayPart(dayPartForHour(DateTime.now().hour));
    final nickname = me.valueOrNull?.nickname;
    if (nickname == null || nickname.isEmpty) return greeting;
    return '$nickname, $greeting';
  }

  /// 推荐区。四态：首屏加载 / 出错 / 空 / 有数据。
  ///
  /// 出错时**替换**列表而不是叠在旧数据上：契约的「中间态约定」要求
  /// 「保存成功但重拉推荐失败」必须显式报错并给重试入口，不得静默展示
  /// 「偏好已更新、推荐还是旧的」这种不一致状态。
  Widget _buildRecommendSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<RecipePage> page,
  ) {
    final l10n = context.l10n;

    if (page.hasError) {
      return _RecommendError(
        message: _errorMessage(page.error),
        // 重试即让 provider 重建 → 从第一页重新拉（旧游标一并丢弃）
        onRetry: () => ref.invalidate(recommendProvider),
      );
    }
    if (!page.hasValue) {
      return const SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final items = page.valueOrNull?.items ?? const <Recipe>[];
    final hasMore = page.valueOrNull?.hasMore ?? false;

    if (items.isEmpty) {
      return SizedBox(
        height: 130,
        child: Center(child: Text(l10n.cookingNoResults)),
      );
    }

    return SizedBox(
      height: 130,
      child: Column(
        children: [
          // 刷新中（例如刚保存完偏好、推荐正在重拉）给一条细进度条，
          // 否则列表内容变了之前看不出任何动静，像是没反应。
          if (page.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              // 有下一页时多渲染一张「加载更多」卡片
              itemCount: items.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return _buildLoadMoreCard(context, ref);
                }
                return _buildHorizontalRecipeCard(context, items[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 「加载更多」卡片 —— 翻页在界面上是真的会发生的一件事，不是隐藏逻辑。
  /// 游标由 RecommendController 持有，这里只管触发。
  Widget _buildLoadMoreCard(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(recommendProvider.notifier).loadMore();
        } catch (e) {
          // 翻页失败不影响已拿到的推荐，提示一下即可
          messenger.showSnackBar(SnackBar(content: Text(_errorMessage(e))));
        }
      },
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text('更多',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                  child: Text(recipe.emoji, style: const TextStyle(fontSize: 32))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  // 契约把时长从字符串改成了数字，展示文案前端自己拼
                  recipe.cookTimeText,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 把异常转成可展示的文案。契约保证服务端下发的 message 就是给人看的，
  /// 网络层自己合成的那几条（超时 / 连不上）也是中文，可直接用。
  static String _errorMessage(Object? error) {
    if (error is ApiException) return error.message;
    return '加载失败，请重试';
  }
}

class _RecommendError extends StatelessWidget {
  const _RecommendError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 130,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
