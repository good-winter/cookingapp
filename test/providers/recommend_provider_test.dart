// test/providers/recommend_provider_test.dart

import 'package:cooking_app/core/network/api_exception.dart';
import 'package:cooking_app/features/cooking/models/recipe.dart';
import 'package:cooking_app/models/user_preferences.dart';
import 'package:cooking_app/providers/api_providers.dart';
import 'package:cooking_app/providers/me_provider.dart';
import 'package:cooking_app/providers/recommend_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_cooking_api.dart';

/// 造 n 条菜谱，id 递增，便于断言分页顺序与不重不漏。
List<Recipe> manyRecipes(int n) => [
      for (var i = 1; i <= n; i++)
        Recipe(
          id: 'r_${i.toString().padLeft(2, '0')}',
          name: '菜$i',
          emoji: '🍲',
          cookTimeMinutes: 10,
          isVegetarian: true,
          calories: 100,
          nutrition: const Nutrition(),
        ),
    ];

ProviderContainer containerWith(FakeCookingApi api) {
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('游标分页', () {
    test('首屏拉第一页，loadMore 追加下一页且不重不漏', () async {
      final api = FakeCookingApi(recipes: manyRecipes(8));
      final container = containerWith(api);

      final first = await container.read(recommendProvider.future);
      expect(first.items.length, RecommendController.pageSize);
      expect(first.hasMore, isTrue);
      expect(api.receivedCursors, [null], reason: '第一页不该带游标');

      await container.read(recommendProvider.notifier).loadMore();

      final after = container.read(recommendProvider).requireValue;
      expect(after.items.length, 8);
      expect(after.hasMore, isFalse);
      expect(api.receivedCursors.last, isNotNull, reason: '第二页必须带游标');
      // 不重不漏
      expect(after.items.map((r) => r.id).toSet().length, 8);
    });

    test('没有下一页时 loadMore 是空操作，不再发请求', () async {
      final api = FakeCookingApi(); // 默认 4 条 < pageSize，一页拉完
      final container = containerWith(api);

      final page = await container.read(recommendProvider.future);
      expect(page.hasMore, isFalse);

      await container.read(recommendProvider.notifier).loadMore();
      expect(api.recommendCalls, 1, reason: '没有下一页就不该再发请求');
    });
  });

  group('偏好变更与游标失效', () {
    // 契约接口 2/4 的核心要求：保存偏好后必须重新拉推荐**并丢弃游标**。
    // 只断言「列表回到了第一页」不够 —— 那和「带着旧游标又拉了一次」长得一样，
    // 所以必须断言那次请求确实没带游标。
    test('保存偏好后重新拉推荐，且这次请求不带旧游标', () async {
      final api = FakeCookingApi(recipes: manyRecipes(8));
      final container = containerWith(api);

      await container.read(recommendProvider.future);
      await container.read(recommendProvider.notifier).loadMore();
      expect(container.read(recommendProvider).requireValue.items.length, 8);

      await container.read(meProvider.future);
      await container.read(meProvider.notifier).savePreferences(
            const UserPreferences(dietMode: 'vegetarian'),
          );

      // 推荐被 invalidate：游标随 state 一起丢弃，重新拉第一页
      final after = await container.read(recommendProvider.future);
      expect(after.items.length, RecommendController.pageSize);
      expect(api.receivedCursors.last, isNull,
          reason: '保存偏好后那次请求必须不带游标');
    });

    test('保存失败时不动推荐列表，也不重新拉取', () async {
      final api = FakeCookingApi(recipes: manyRecipes(8))
        ..failNextUpdate = const ApiException(
          code: 'INTERNAL_ERROR',
          message: '服务器内部错误',
        );
      final container = containerWith(api);

      await container.read(recommendProvider.future);
      await container.read(meProvider.future);
      final callsBefore = api.recommendCalls;

      await expectLater(
        () => container
            .read(meProvider.notifier)
            .savePreferences(const UserPreferences(dietMode: 'vegetarian')),
        throwsA(isA<ApiException>()),
      );

      // 服务端没变，推荐就还是对的 —— 不该白拉一次，更不该显示成别的东西
      expect(api.recommendCalls, callsBefore);
      expect(container.read(recommendProvider).requireValue.items.length,
          RecommendController.pageSize);
    });

    // 万一还是撞上了失效游标（例如别处改了偏好），正确反应是丢弃游标重拉，
    // 而不是把这个错误摊给用户看。
    test('游标被服务端拒绝时丢弃游标重拉，而不是抛给用户', () async {
      final api = FakeCookingApi(recipes: manyRecipes(8));
      final container = containerWith(api);

      await container.read(recommendProvider.future);

      api.failNextRecommend = const ApiException(
        code: ApiException.invalidParameterCode,
        message: '游标已失效（偏好已变更），请丢弃后重新请求',
      );
      await container.read(recommendProvider.notifier).loadMore();

      // invalidateSelf 后重新拉第一页，用户看到的是正常列表而不是错误
      final after = await container.read(recommendProvider.future);
      expect(after.items.length, RecommendController.pageSize);
      expect(api.receivedCursors.last, isNull);
      expect(api.recommendCalls, 3, reason: '首屏 + 失败那次 + 重拉');
    });

    // 翻页失败是网络问题，不该把已经拿到的推荐清空。
    test('翻页遇到网络错误时保留已有列表', () async {
      final api = FakeCookingApi(recipes: manyRecipes(8));
      final container = containerWith(api);

      await container.read(recommendProvider.future);

      api.failNextRecommend = const ApiException(
        code: ApiException.networkErrorCode,
        message: '连不上后端服务',
      );

      await expectLater(
        () => container.read(recommendProvider.notifier).loadMore(),
        throwsA(isA<ApiException>()),
      );

      expect(container.read(recommendProvider).requireValue.items.length,
          RecommendController.pageSize,
          reason: '已拿到的推荐不该因为翻页失败而消失');
    });
  });
}
