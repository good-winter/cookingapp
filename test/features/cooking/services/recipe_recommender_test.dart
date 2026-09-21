// test/features/cooking/services/recipe_recommender_test.dart
import 'package:cooking_app/features/cooking/data/mock_recipes.dart';
import 'package:cooking_app/features/cooking/models/recipe.dart';
import 'package:cooking_app/features/cooking/services/recipe_recommender.dart';
import 'package:cooking_app/models/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// 生成 [count] 道菜，每 3 道有 1 道命中「孕妇」。
/// 用几十条的规模模拟接后端之后的量级 —— 小数据量掩盖不了排序问题。
List<Recipe> _manyRecipes(int count) => [
      for (var i = 0; i < count; i++)
        Recipe(
          '菜$i',
          '🍲',
          '10分钟',
          i % 3 == 0 ? const ['孕妇'] : const ['正常人'],
          const [],
        ),
    ];

List<String> _names(Iterable<Recipe> recipes) =>
    recipes.map((r) => r.name).toList();

void main() {
  group('无偏好', () {
    test('原样返回全部菜谱，顺序不变', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(),
      );

      expect(_names(result), _names(mockRecipes));
    });

    test('空列表返回空列表', () {
      final result = recommendRecipes(
        all: const <Recipe>[],
        prefs: const UserPreferences(crowds: ['孕妇'], avoidFoods: ['猪肉']),
      );

      expect(result, isEmpty);
    });
  });

  group('饮食习惯（硬过滤）', () {
    test('素食主义只保留带「素食」标签的菜', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(dietMode: '素食主义'),
      );

      expect(_names(result), ['番茄炒蛋', '白灼西兰花']);
    });

    test('正常人不过滤任何菜', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(dietMode: '正常人'),
      );

      expect(result.length, mockRecipes.length);
    });
  });

  group('忌口（硬过滤）', () {
    test('忌猪肉时剔除红烧肉', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(avoidFoods: ['猪肉']),
      );

      expect(_names(result), isNot(contains('红烧肉')));
      expect(result.length, mockRecipes.length - 1);
    });

    test('多个忌口叠加，命中任一即剔除', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(avoidFoods: ['猪肉', '海鲜', '辛辣']),
      );

      expect(_names(result), ['番茄炒蛋', '香煎鸡胸肉', '白灼西兰花']);
    });

    test('素食 + 忌口同时生效', () {
      // 素食剩下 番茄炒蛋 / 白灼西兰花，都不是海鲜，所以都留下
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(dietMode: '素食主义', avoidFoods: ['海鲜']),
      );

      expect(_names(result), ['番茄炒蛋', '白灼西兰花']);
    });

    test('全部被过滤掉时返回空列表，而不是抛异常', () {
      final onlyMeat = [
        const Recipe('红烧肉', '🥩', '45分钟', ['正常人'], ['猪肉']),
      ];

      final result = recommendRecipes(
        all: onlyMeat,
        prefs: const UserPreferences(dietMode: '素食主义'),
      );

      expect(result, isEmpty);
    });
  });

  group('人群（只排序，不删菜）', () {
    test('选人群不会减少菜谱数量', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(crowds: ['孕妇']),
      );

      expect(result.length, mockRecipes.length);
      expect(_names(result), containsAll(_names(mockRecipes)));
    });

    test('命中的菜全部排在未命中的前面', () {
      final result = recommendRecipes(
        all: _manyRecipes(40),
        prefs: const UserPreferences(crowds: ['孕妇']),
      );

      final matchedCount =
          result.where((r) => r.tags.contains('孕妇')).length;

      expect(
        result.take(matchedCount).every((r) => r.tags.contains('孕妇')),
        isTrue,
        reason: '前 $matchedCount 个应该全是命中的菜',
      );
    });

    test('未命中的菜保持原有相对顺序（稳定排序回归测试）', () {
      // 这条曾经会挂：List.sort 不保证稳定，40 条时未命中的菜会被打乱。
      // 见 services/recipe_recommender.dart 里 _crowdFirst 的注释。
      final all = _manyRecipes(40);

      final result = recommendRecipes(
        all: all,
        prefs: const UserPreferences(crowds: ['孕妇']),
      );

      final expected =
          all.where((r) => !r.tags.contains('孕妇')).map((r) => r.name);
      final actual =
          result.where((r) => !r.tags.contains('孕妇')).map((r) => r.name);

      expect(actual, expected, reason: '未命中的菜必须严格保持原有顺序');
    });

    test('多个人群标签，命中任一个就算命中', () {
      final result = recommendRecipes(
        all: mockRecipes,
        prefs: const UserPreferences(crowds: ['孕妇', '运动员']),
      );

      // 番茄炒蛋、清蒸鲈鱼（孕妇）、香煎鸡胸肉（运动员）应该排前面
      expect(
        _names(result).take(3),
        containsAll(['番茄炒蛋', '清蒸鲈鱼', '香煎鸡胸肉']),
      );
    });
  });

  group('纯函数约束', () {
    test('不会修改传入的菜谱列表', () {
      final all = _manyRecipes(40);
      final before = _names(all);

      recommendRecipes(
        all: all,
        prefs: const UserPreferences(crowds: ['孕妇'], avoidFoods: ['猪肉']),
      );

      expect(_names(all), before, reason: '入参必须保持不变');
    });

    test('连续调用的结果一致（没有隐藏状态）', () {
      const prefs = UserPreferences(crowds: ['孕妇'], avoidFoods: ['海鲜']);
      final all = _manyRecipes(40);

      expect(
        _names(recommendRecipes(all: all, prefs: prefs)),
        _names(recommendRecipes(all: all, prefs: prefs)),
      );
    });
  });
}
