// test/core/storage/settings_storage_test.dart
import 'dart:convert';

import 'package:cooking_app/core/storage/settings_storage.dart';
import 'package:cooking_app/models/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final storage = SettingsStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('load', () {
    test('从没存过时，返回默认设置', () async {
      final loaded = await storage.load();

      expect(loaded.themeMode, ThemeMode.light);
      expect(loaded.locale.languageCode, 'zh');
      expect(loaded.signature, isEmpty);
      expect(loaded.ttsEnabled, isTrue);
      expect(loaded.ttsSpeechRate, AppSettings.defaultSpeechRate);
    });

    test('存进去的设置能原样读回来', () async {
      await storage.save(const AppSettings(
        themeMode: ThemeMode.dark,
        locale: Locale('en'),
        signature: '好好吃饭',
        ttsEnabled: false,
        ttsSpeechRate: 0.7,
      ));

      final loaded = await storage.load();

      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.locale.languageCode, 'en');
      expect(loaded.signature, '好好吃饭');
      expect(loaded.ttsEnabled, isFalse);
      expect(loaded.ttsSpeechRate, 0.7);
    });

    test('存储内容不是合法 JSON 时，退回默认值而不是抛异常', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStorage.storageKey: '这不是 JSON',
      });

      expect((await storage.load()).themeMode, ThemeMode.light);
    });

    test('themeMode 是不认识的值时，退回 light', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStorage.storageKey: jsonEncode({'themeMode': 'sepia'}),
      });

      expect((await storage.load()).themeMode, ThemeMode.light);
    });

    test('locale 不是支持的语言时，退回中文', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStorage.storageKey: jsonEncode({'locale': 'ja'}),
      });

      expect((await storage.load()).locale.languageCode, 'zh');
    });

    test('语速超出 0~1 范围时，退回默认值', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStorage.storageKey: jsonEncode({'ttsSpeechRate': 99.0}),
      });

      expect(
        (await storage.load()).ttsSpeechRate,
        AppSettings.defaultSpeechRate,
      );
    });

    test('字段类型不对时，逐项退回默认值', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStorage.storageKey: jsonEncode({
          'themeMode': 123, // 应该是 String
          'signature': null, // 应该是 String
          'ttsEnabled': 'yes', // 应该是 bool
        }),
      });

      final loaded = await storage.load();

      expect(loaded.themeMode, ThemeMode.light);
      expect(loaded.signature, isEmpty);
      expect(loaded.ttsEnabled, isTrue);
    });
  });

  group('clear', () {
    test('清空后回到默认设置', () async {
      await storage.save(const AppSettings(themeMode: ThemeMode.dark));
      await storage.clear();

      expect((await storage.load()).themeMode, ThemeMode.light);
    });
  });
}
