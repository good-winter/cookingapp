// test/core/storage/preference_storage_test.dart
import 'dart:convert';

import 'package:cooking_app/core/storage/preference_storage.dart';
import 'package:cooking_app/models/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final storage = PreferenceStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('load', () {
    test('从没存过时，返回默认偏好', () async {
      final loaded = await storage.load();

      expect(loaded.dietMode, '正常人');
      expect(loaded.crowds, isEmpty);
      expect(loaded.avoidFoods, isEmpty);
    });

    test('存进去的数据能原样读回来', () async {
      await storage.save(const UserPreferences(
        dietMode: '素食主义',
        crowds: ['孕妇', '老人'],
        avoidFoods: ['海鲜'],
      ));

      final loaded = await storage.load();

      expect(loaded.dietMode, '素食主义');
      expect(loaded.crowds, ['孕妇', '老人']);
      expect(loaded.avoidFoods, ['海鲜']);
    });

    test('存储内容不是合法 JSON 时，退回默认值而不是抛异常', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceStorage.storageKey: '这不是 JSON',
      });

      final loaded = await storage.load();

      expect(loaded.dietMode, '正常人');
      expect(loaded.avoidFoods, isEmpty);
    });

    test('dietMode 是不认识的值时，退回默认', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceStorage.storageKey:
            jsonEncode({'dietMode': '生酮饮食', 'crowds': [], 'avoidFoods': []}),
      });

      expect((await storage.load()).dietMode, '正常人');
    });

    test('列表里混入非字符串时，只保留合法元素', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceStorage.storageKey: jsonEncode({
          'dietMode': '正常人',
          'crowds': ['孕妇', 42, null, '老人'],
          'avoidFoods': '不是列表',
        }),
      });

      final loaded = await storage.load();

      expect(loaded.crowds, ['孕妇', '老人']);
      expect(loaded.avoidFoods, isEmpty);
    });
  });

  group('clear', () {
    test('清空后回到默认偏好', () async {
      await storage.save(const UserPreferences(dietMode: '素食主义'));
      await storage.clear();

      expect((await storage.load()).dietMode, '正常人');
    });
  });
}
