// test/core/storage/auth_storage_test.dart

import 'package:cooking_app/core/storage/auth_storage.dart';
import 'package:cooking_app/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('load', () {
    // 没登录过是正常状态，不是错误。
    test('从没存过时返回 null（未登录）', () async {
      expect(await AuthStorage().load(), isNull);
    });

    test('存进去的会话能原样读回来', () async {
      final storage = AuthStorage();
      await storage.save(
        const AuthSession(token: 'abc123', phone: '13800138000'),
      );

      final loaded = await storage.load();
      expect(loaded?.token, 'abc123');
      expect(loaded?.phone, '13800138000');
    });

    test('确实写进了本地存储', () async {
      await AuthStorage().save(
        const AuthSession(token: 'abc123', phone: '13800138000'),
      );

      final raw = await readStored(AuthStorage.storageKey);
      expect(raw?['token'], 'abc123');
      expect(raw?['phone'], '13800138000');
    });

    // 本地数据坏了应该表现为「需要重新登录」，而不是让 App 启动就崩 ——
    // 这是启动路径上的代码，抛异常等于整个 App 打不开。
    test('存储内容不是合法 JSON 时返回 null 而不是抛异常', () async {
      SharedPreferences.setMockInitialValues({
        AuthStorage.storageKey: '这不是 JSON',
      });
      expect(await AuthStorage().load(), isNull);
    });

    test('JSON 合法但缺 token 时返回 null', () async {
      SharedPreferences.setMockInitialValues({
        AuthStorage.storageKey: '{"phone":"13800138000"}',
      });
      expect(await AuthStorage().load(), isNull);
    });

    // 空 token 发出去就是 'Bearer '，后端会判无效并回 401。
    // 与其等到那时，不如现在就当成未登录。
    test('token 是空串时视为未登录', () async {
      SharedPreferences.setMockInitialValues({
        AuthStorage.storageKey: '{"token":"","phone":"13800138000"}',
      });
      expect(await AuthStorage().load(), isNull);
    });

    test('缺 phone 字段时退回空串，不影响 token', () async {
      SharedPreferences.setMockInitialValues({
        AuthStorage.storageKey: '{"token":"abc123"}',
      });

      final loaded = await AuthStorage().load();
      expect(loaded?.token, 'abc123');
      expect(loaded?.phone, '');
    });
  });

  group('clear', () {
    test('清空后回到未登录', () async {
      final storage = AuthStorage();
      await storage.save(
        const AuthSession(token: 'abc123', phone: '13800138000'),
      );

      await storage.clear();
      expect(await storage.load(), isNull);
    });
  });

  group('手机号掩码', () {
    test('11 位手机号打码中间四位', () {
      const session = AuthSession(token: 't', phone: '13800138000');
      expect(session.maskedPhone, '138****8000');
    });

    // 开发期用 --dart-define=API_TOKEN 注入时没有手机号。
    // 硬凑格式会显示出一串看着像乱码的东西。
    test('没有手机号时原样返回空串', () {
      const session = AuthSession(token: 't', phone: '');
      expect(session.maskedPhone, '');
    });

    test('长度异常时原样返回，不硬凑格式', () {
      const session = AuthSession(token: 't', phone: '123');
      expect(session.maskedPhone, '123');
    });
  });
}
