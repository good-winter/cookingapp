// test/helpers/app_test_harness.dart
import 'dart:convert';

import 'package:cooking_app/core/bootstrap.dart';
import 'package:cooking_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 启动 App —— 和执行 `main()` 完全相同的接线方式。
///
/// [stored] 用来预置「本地已保存的数据」，模拟用户上次退出时的状态。
/// 键用 `PreferenceStorage.storageKey` / `SettingsStorage.storageKey`。
///
/// 因为 main() 和这里都走 `appOverrides()`，测试跑的接线就是线上跑的接线。
Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);

  // 必须包 ProviderScope，否则 MyApp 里的 ref.watch 会抛
  // "No ProviderScope found"
  await tester.pumpWidget(
    ProviderScope(overrides: await appOverrides(), child: const MyApp()),
  );
  await tester.pumpAndSettle();
}

/// 切到底部导航的某个 Tab
Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

/// 在可滚动弹窗里点某个选项 —— 先滚到可见位置再点，
/// 避免元素在折叠区外时 tap 打不中。
Future<void> tapInModal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// 读出本地真实存的内容，用来断言「确实写进磁盘了」
Future<Map<String, dynamic>?> readStored(String key) async {
  final sp = await SharedPreferences.getInstance();
  final raw = sp.getString(key);
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

/// 返回上一页。
///
/// 不用 `tester.pageBack()` —— 它按英文 tooltip "Back" 找返回按钮，
/// 而本 App 的 locale 是中文（tooltip 是「返回」），会找不到。
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// 在懒加载列表里滚到目标元素并点击。
///
/// 元素在折叠区外时 ListView 根本不会构建它，`find` 会返回 0 个 ——
/// 这时不能直接 tap，得先滚过去。
Future<void> scrollAndTap(
  WidgetTester tester,
  Finder target,
  Finder scrollAnchor,
) async {
  await tester.dragUntilVisible(
    target,
    scrollAnchor,
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 读出当前生效的主题模式（从 MaterialApp 上取，验证的是真正渲染用的值）
ThemeMode currentThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

/// 读出当前生效的语言
Locale? currentLocale(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).locale;
