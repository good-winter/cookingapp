// test/widget_test.dart
import 'dart:convert';

import 'package:cooking_app/core/network/api_exception.dart';
import 'package:cooking_app/core/utils/greeting.dart';
import 'package:cooking_app/l10n/generated/app_localizations_zh.dart';
import 'package:cooking_app/models/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_test_harness.dart';
import 'helpers/fake_cooking_api.dart';

void main() {
  group('启动与导航', () {
    testWidgets('默认进入烹饪页，并显示问候语和核心功能区', (tester) async {
      await pumpApp(tester, api: FakeCookingApi());

      // 问候语随当前时间变化：先用同一个纯函数算出时段，再取对应语言的文案。
      // 测试默认语言是中文，所以用 zh 的文案表算期望值。
      final zh = AppLocalizationsZh();
      final greeting = switch (dayPartForHour(DateTime.now().hour)) {
        DayPart.morning => zh.greetingMorning,
        DayPart.noon => zh.greetingNoon,
        DayPart.evening => zh.greetingEvening,
      };
      // 昵称现在来自 GET /me，不再是写死的字符串
      expect(find.text('美食家, $greeting'), findsOneWidget);
      expect(find.text('今天想做点什么？'), findsOneWidget);

      // 核心的 AI 拍照识别入口
      expect(find.text('AI 拍照识别食材'), findsOneWidget);
    });

    testWidgets('底部导航可以在四个 Tab 之间切换', (tester) async {
      await pumpApp(tester, api: FakeCookingApi());

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
    testWidgets('切换到素食主义后，荤菜从推荐里消失', (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api);

      // 过滤前：红烧肉在推荐列表里
      expect(find.text('红烧肉'), findsOneWidget);
      expect(api.recommendCalls, 1, reason: '首屏应拉一次推荐');

      // 打开偏好弹窗
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(find.text('设置我的饮食偏好'), findsOneWidget);

      // 选「素食主义」并保存
      await tapInModal(tester, find.text('素食主义'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      // 契约要求的两段式流程：PUT 成功后必须重新拉推荐、并丢弃旧游标。
      // 光断言画面不够 —— 接线错了也可能碰巧显示对，所以这里数调用次数。
      expect(api.updatePreferencesCalls, 1);
      expect(api.recommendCalls, 2, reason: '保存成功后应重新拉推荐');

      // 右上角入口 chip 已更新
      expect(find.text('素食主义'), findsOneWidget);

      // 免肉的留下，含肉的消失
      expect(find.text('红烧肉'), findsNothing);
      expect(find.text('番茄炒蛋'), findsOneWidget);
      expect(find.text('白灼西兰花'), findsOneWidget);
    });

    testWidgets('勾选忌口「海鲜」后，清蒸鲈鱼从推荐里消失', (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api);

      expect(find.text('清蒸鲈鱼'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // 第 3 栏「我不吃 (忌口/过敏)」里选海鲜
      await tapInModal(tester, find.text('海鲜'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      expect(find.text('清蒸鲈鱼'), findsNothing);
      expect(find.text('红烧肉'), findsOneWidget); // 忌海鲜不影响猪肉

      // 提交给服务端的是英文码，不是界面上的中文
      expect(api.lastSubmitted!.avoidFoods, contains('seafood'));
    });

    // 契约的「中间态约定」：保存失败必须显式报错并给重试入口，
    // 不得静默展示「偏好已更新、推荐还是旧的」这种不一致状态。
    testWidgets('保存失败时弹窗不关闭、显示错误，且可重试成功', (tester) async {
      final api = FakeCookingApi()
        ..failNextUpdate = const ApiException(
          code: 'INTERNAL_ERROR',
          message: '服务器内部错误',
        );
      await pumpApp(tester, api: api);

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tapInModal(tester, find.text('素食主义'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      // 弹窗仍在，错误文案可见 —— 用户能看懂发生了什么并再试一次
      expect(find.text('设置我的饮食偏好'), findsOneWidget);
      expect(find.text('服务器内部错误'), findsOneWidget);
      // 失败时不该去重拉推荐：服务端并没变
      expect(api.recommendCalls, 1);

      // 直接再点一次即重试
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      expect(find.text('设置我的饮食偏好'), findsNothing);
      expect(api.updatePreferencesCalls, 2);
      expect(find.text('红烧肉'), findsNothing);
    });
  });

  group('偏好改由服务端存储', () {
    testWidgets('保存偏好不再写本地存储，而是 PUT 给服务端', (tester) async {
      final api = FakeCookingApi();
      await pumpApp(tester, api: api);

      expect(await readStored('user_preferences'), isNull,
          reason: '偏好已迁到服务端，本地不应再存');

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tapInModal(tester, find.text('素食主义'));
      await tester.tap(find.text('保存并更新推荐'));
      await tester.pumpAndSettle();

      expect(await readStored('user_preferences'), isNull,
          reason: '保存后本地仍不该落盘');
      expect(api.lastSubmitted!.dietMode, 'vegetarian');
    });

    testWidgets('本地残留的旧偏好不影响显示，以服务端为准', (tester) async {
      final api = FakeCookingApi(
        profile: FakeCookingApi.defaultProfile.copyWith(
          preferences: const UserPreferences(dietMode: 'vegetarian'),
        ),
      );

      // 故意塞一份与「服务端」不一致的旧本地数据
      await pumpApp(tester, api: api, stored: {
        'user_preferences': jsonEncode({
          'dietMode': 'normal',
          'crowds': <String>[],
          'avoidFoods': <String>[],
        }),
      });

      // 显示的是服务端返回的素食模式，而不是本地那份 normal
      expect(find.text('素食主义'), findsOneWidget);
      expect(find.text('红烧肉'), findsNothing);
      expect(find.text('番茄炒蛋'), findsOneWidget);
    });
  });

  group('推荐加载失败', () {
    testWidgets('显示错误与重试入口，重试后恢复正常', (tester) async {
      final api = FakeCookingApi()
        ..failNextRecommend = const ApiException(
          code: 'INTERNAL_ERROR',
          message: '服务器内部错误',
        );
      await pumpApp(tester, api: api);

      // 契约的中间态要求：显式报错 + 重试入口，而不是留一片空白
      expect(find.text('服务器内部错误'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(find.text('番茄炒蛋'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
    });
  });
}
