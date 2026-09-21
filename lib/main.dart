// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/l10n.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  // 读 SharedPreferences 前必须先初始化绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 启动时把本地保存的饮食偏好与 App 设置读出来，注入 ProviderScope
  final overrides = await appOverrides();

  // 必须包裹 ProviderScope 才能使用 Riverpod
  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取路由实例
    final router = ref.watch(routerProvider);
    // 主题模式 / 语言由本地设置决定
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      // 用 onGenerateTitle 而不是 title：title 在 Localizations 之上，
      // 拿不到当前语言。这样系统任务切换器里的应用名也会跟随语言。
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      // 语言由用户在设置页手选，**不跟随系统**。这也让 widget test 的结果确定 ——
      // 测试环境默认 locale 是 en_US，若跟随系统会让设置页渲染成英文。
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false, // 去掉右上角的Debug标签
    );
  }
}
