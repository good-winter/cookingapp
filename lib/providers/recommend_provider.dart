// lib/providers/recommend_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../features/cooking/models/recipe_page.dart';
import 'api_providers.dart';

/// 按服务端存的偏好算出的推荐（`GET /recipes/recommend`）。
///
/// **本 provider 的 state 就是游标的持有者。** 偏好保存成功后由 MeController
/// invalidate 它 —— 游标随 state 一起被丢弃，下次 build 从第一页重来。
///
/// 把游标放在 state 里、而不是散在界面字段或某个变量里，是为了让「丢弃游标」
/// 无法被遗漏：invalidate 是原子的，不存在「偏好改了但游标还留着」的中间状态。
class RecommendController extends AsyncNotifier<RecipePage> {
  /// 每页条数。刻意取小（种子库共 12 条），让翻页**真的会发生** ——
  /// 游标这条路径在 App 里能被走到、被看见，而不是一段永不执行的死代码。
  static const int pageSize = 6;

  /// 防重入：连点「加载更多」不该发出两个同样的请求。
  bool _loadingMore = false;

  @override
  Future<RecipePage> build() {
    // 永远从第一页开始，不带游标。
    return ref.read(apiClientProvider).recommend(limit: pageSize);
  }

  /// 追加下一页。已在拉取、没有下一页、或首屏还没数据时都是空操作。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || _loadingMore) return;

    _loadingMore = true;
    try {
      final next = await ref
          .read(apiClientProvider)
          .recommend(limit: pageSize, cursor: cursor);
      state = AsyncData(RecipePage(
        items: [...current.items, ...next.items],
        nextCursor: next.nextCursor,
      ));
    } on ApiException catch (e) {
      if (e.isInvalidParameter) {
        // 服务端拒绝了游标 —— 契约接口 2/4 规定偏好变更后旧游标返回 400，
        // 此时正确反应是丢弃游标从头拉，而不是把这个错误丢给用户看。
        ref.invalidateSelf();
        return;
      }
      // 其他错误多为网络问题：抛给界面提示，**不动已有列表** ——
      // 已经拿到的推荐没必要因为翻页失败而清空。
      rethrow;
    } finally {
      _loadingMore = false;
    }
  }
}

final recommendProvider = AsyncNotifierProvider<RecommendController, RecipePage>(
  RecommendController.new,
);
