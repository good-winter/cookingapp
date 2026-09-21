// test/widget_test.dart
import 'dart:convert';

import 'package:cooking_app/core/storage/preference_storage.dart';
import 'package:cooking_app/core/utils/greeting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_test_harness.dart';

void main() {
  group('启动与导航', () {
    testWidgets('默认进入烹饪页，并显示问候语和核心功能区', (tester) async {
      await pumpApp(tester);

      // 问候语随当前时间变化，所以用同一个纯函数算出期望值
      final greeting = greetingForHour(DateTime.now().hour);
      expect(find.text('美食家, $greeting'), findsOneWidget);
      expect(find.text('今天想做点什么？'), findsOneWidget);

      // 核心的 AI 拍照识别入口
      expect(find.text('AI 拍照识别食材'), findsOneWidget);
    });

    testWidgets('底部导航可以在四个 Tab 之间切换', (tester) async {
      await pumpApp(tester);

      await openTab(tester, Icons.people_outline);
      expect(find.text('美食家A'), findsOneWidget); // 社区帖子
      expect(find.text('推荐'), findsOneWidget); // 社区 TabBar

      await openTab(tester, Icons.bar_chart);
      expect(find.text('📈 近两周热量趋势'), findsOneWidget);

      await openTab(tester, Icons.settings_outlined);
      // 设置页的栏目之一（「设置」二字会同时命中底部导航，所以不能用它断言）
      expect(find.text('数据管理'), findsOneWidget);

      // 切回烹饪页
      await openTab(tester, Icons.restaurant_menu);
      expect(find.text('AI 拍照识别食材'), findsOneWidget);
    });
  });

  group('饮食偏好 -> 菜谱推荐', () {
    testWidgets('切换到素食主义后，含肉的菜谱被过滤掉', (tester) async {
      await pumpApp(tester);

      // 过滤前：红烧肉在推荐列表里
      expect(find.text('红烧肉'), findsOneWidget);

      // 打开偏好弹窗
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(find.text('设置我的饮食偏好'), findsOneWidget);

      // 选「素食主义」并保存
      await tapInModal(tester, find.text('素食主义'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      // 右上角入口 chip 已更新
      expect(find.text('素食主义'), findsOneWidget);

      // 免肉的（番茄炒蛋、白灼西兰花）留下，含肉的（红烧肉）被过滤
      expect(find.text('红烧肉'), findsNothing);
      expect(find.text('番茄炒蛋'), findsOneWidget);
      expect(find.text('白灼西兰花'), findsOneWidget);
    });

    testWidgets('勾选忌口「海鲜」后，清蒸鲈鱼被过滤掉', (tester) async {
      await pumpApp(tester);

      expect(find.text('清蒸鲈鱼'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // 第 3 栏「我不吃 (忌口/过敏)」里选海鲜
      await tapInModal(tester, find.text('海鲜'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      expect(find.text('清蒸鲈鱼'), findsNothing);
      expect(find.text('红烧肉'), findsOneWidget); // 忌海鲜不影响猪肉
    });
  });

  group('偏好持久化', () {
    testWidgets('保存偏好后，确实写进了本地存储', (tester) async {
      await pumpApp(tester);
      expect(
        await readStored(PreferenceStorage.storageKey),
        isNull,
        reason: '一开始没存过任何偏好',
      );

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tapInModal(tester, find.text('素食主义'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      final stored = await readStored(PreferenceStorage.storageKey);
      expect(stored, isNotNull);
      expect(stored!['dietMode'], '素食主义');
    });

    testWidgets('重启后读取本地偏好，过滤立即生效', (tester) async {
      await pumpApp(tester, stored: {
        PreferenceStorage.storageKey: jsonEncode({
          'dietMode': '素食主义',
          'crowds': ['孕妇'],
          'avoidFoods': ['海鲜'],
        }),
      });

      // 右上角 chip 显示的是存过的模式，而不是默认的「正常人」
      expect(find.text('素食主义'), findsOneWidget);
      // 素食过滤生效
      expect(find.text('红烧肉'), findsNothing);
      // 忌口过滤生效
      expect(find.text('清蒸鲈鱼'), findsNothing);
      // 合法的留下
      expect(find.text('番茄炒蛋'), findsOneWidget);
      expect(find.text('白灼西兰花'), findsOneWidget);
    });
  });
}
