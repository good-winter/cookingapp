// test/features/settings/settings_screen_test.dart
import 'dart:convert';

import 'package:cooking_app/core/storage/settings_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_test_harness.dart';

/// 进入设置 Tab
Future<void> _openSettings(WidgetTester tester) =>
    openTab(tester, Icons.settings_outlined);

void main() {
  group('设置主页', () {
    testWidgets('显示用户信息卡与五个栏目', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      // 用户信息卡：用户名 + 未设置签名时的占位提示
      expect(find.text('美食家'), findsOneWidget);
      expect(find.text('点击设置个性签名'), findsOneWidget);

      // 五个栏目
      expect(find.text('数据管理'), findsOneWidget);
      expect(find.text('语音'), findsOneWidget);
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('模式'), findsOneWidget);
      expect(find.text('付费服务'), findsOneWidget);
    });
  });

  group('模式', () {
    testWidgets('切到「晚上」后，MaterialApp 的 themeMode 真的变成 dark', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      expect(currentThemeMode(tester), ThemeMode.light);

      await tester.tap(find.text('模式'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('晚上'));
      await tester.pumpAndSettle();

      expect(currentThemeMode(tester), ThemeMode.dark);

      // 返回设置主页，栏目的状态摘要也跟着更新
      await goBack(tester);
      expect(find.text('晚上'), findsOneWidget);
    });

    testWidgets('切回「白天」', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('模式'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('晚上'));
      await tester.pumpAndSettle();
      expect(currentThemeMode(tester), ThemeMode.dark);

      await tester.tap(find.text('白天'));
      await tester.pumpAndSettle();
      expect(currentThemeMode(tester), ThemeMode.light);
    });
  });

  group('语言', () {
    testWidgets('切到 English 后全局生效：设置页与底部导航都变英文', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('语言'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(currentLocale(tester)?.languageCode, 'en');

      await goBack(tester);

      // 设置页正文已切换成英文
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);

      // 底部导航同样跟着切 —— 语言是全局生效的
      expect(find.text('Cooking'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      // 「Settings」会出现两次：底部导航 + 页面标题
      expect(find.text('Settings'), findsNWidgets(2));

      // 中文标签应当全部消失
      expect(find.text('烹饪'), findsNothing);
      expect(find.text('社区'), findsNothing);
      expect(find.text('统计'), findsNothing);
    });

    testWidgets('切到 English 后，烹饪页也变英文', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('语言'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await goBack(tester);

      // 切到烹饪页 —— 页面正文也应该是英文
      await openTab(tester, Icons.restaurant_menu);

      expect(find.text('Snap to identify ingredients'), findsOneWidget);
      expect(find.text('What are we cooking today?'), findsOneWidget);
      expect(find.text('AI 拍照识别食材'), findsNothing);
    });
  });

  group('个性签名', () {
    testWidgets('编辑后显示在卡片上，并写入本地存储', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      expect(
        await readStored(SettingsStorage.storageKey),
        isNull,
        reason: '一开始没存过任何设置',
      );

      // 点用户卡打开编辑弹窗
      await tester.tap(find.text('点击设置个性签名'));
      await tester.pumpAndSettle();
      expect(find.text('编辑个性签名'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '今天也要好好吃饭');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 卡片上显示出来了，占位提示消失
      expect(find.text('今天也要好好吃饭'), findsOneWidget);
      expect(find.text('点击设置个性签名'), findsNothing);

      // 真的落盘了
      final stored = await readStored(SettingsStorage.storageKey);
      expect(stored, isNotNull);
      expect(stored!['signature'], '今天也要好好吃饭');
    });

    testWidgets('取消编辑不改变签名', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('点击设置个性签名'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '不该被保存');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('不该被保存'), findsNothing);
      expect(find.text('点击设置个性签名'), findsOneWidget);
      expect(await readStored(SettingsStorage.storageKey), isNull);
    });
  });

  group('数据管理', () {
    testWidgets('分组结构正确，清除按钮会弹二次确认', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('数据管理'));
      await tester.pumpAndSettle();

      // 两类数据 + 用户数据下的两个子分组
      expect(find.text('App 自带的数据'), findsOneWidget);
      expect(find.text('我的数据'), findsOneWidget);
      expect(find.text('统计数据'), findsOneWidget);
      expect(find.text('社区行为'), findsOneWidget);
      expect(find.text('饮食记录'), findsOneWidget);
      expect(find.text('我的帖子'), findsOneWidget);
      expect(find.text('我的发言'), findsOneWidget);

      // 点第一个「清除」 -> 确认框
      await tester.tap(find.text('清除').first);
      await tester.pumpAndSettle();
      expect(find.text('确认清除？'), findsOneWidget);

      // 取消不掉数据
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('确认清除？'), findsNothing);
    });

    testWidgets('确认后提示已清除', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('数据管理'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('清除').first);
      await tester.pumpAndSettle();

      // 确认框里的「清除」按钮
      await tester.tap(find.text('清除').last);
      await tester.pumpAndSettle();

      expect(find.text('已清除'), findsOneWidget);
    });
  });

  group('付费服务', () {
    testWidgets('开通按钮只弹提示（本期没有支付内核）', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);

      await tester.tap(find.text('付费服务'));
      await tester.pumpAndSettle();

      expect(find.text('免费版'), findsOneWidget);
      expect(find.text('会员权益'), findsOneWidget);

      // 开通按钮在折叠区外，先滚过去
      await scrollAndTap(tester, find.text('立即开通'), find.text('会员权益'));

      expect(find.text('付费功能开发中'), findsOneWidget);
    });
  });

  group('持久化', () {
    testWidgets('重启后从本地恢复主题、语言与签名', (tester) async {
      await pumpApp(tester, stored: {
        SettingsStorage.storageKey: jsonEncode({
          'themeMode': 'dark',
          'locale': 'en',
          'signature': '好好吃饭',
          'ttsEnabled': false,
          'ttsSpeechRate': 0.7,
        }),
      });

      // 主题与语言在启动时就生效了
      expect(currentThemeMode(tester), ThemeMode.dark);
      expect(currentLocale(tester)?.languageCode, 'en');

      await _openSettings(tester);

      // 设置页是英文（用栏目名断言，避开「Settings」同时出现在底部导航的情况），
      // 签名也从本地恢复了
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('好好吃饭'), findsOneWidget);
      expect(find.text('点击设置个性签名'), findsNothing);
    });

    testWidgets('本地数据损坏时退回默认值，不影响启动', (tester) async {
      await pumpApp(tester, stored: {
        SettingsStorage.storageKey: '这不是 JSON',
      });

      expect(currentThemeMode(tester), ThemeMode.light);
      expect(currentLocale(tester)?.languageCode, 'zh');

      await _openSettings(tester);
      expect(find.text('数据管理'), findsOneWidget);
    });
  });
}
