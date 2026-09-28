// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入四个核心页面
import '../../features/auth/screens/login_screen.dart';
import '../../features/cooking/screens/cooking_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/statistics/screens/statistics_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';

/// 登录页路径。守卫与登出后跳转都引用它，避免这个字符串散落各处。
const String loginRoutePath = '/login';

final routerProvider = Provider<GoRouter>((ref) {
  // go_router 的 refreshListenable 要一个 Listenable，而登录态来自 Riverpod，
  // 中间用这个自增计数器搭桥。
  //
  // 不能改成在 Provider 里 ref.watch(authProvider)：那样每次登录/登出都会重建
  // GoRouter，导航栈连同各页面的状态会整个丢掉。
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    // 首个页面按登录态直接定下来。启动时的会话在 runApp 之前就读完了
    // （见 bootstrap.resolveInitialSession），所以这里同步判定是准确的，
    // 不会出现先渲染主界面再被 redirect 踢走那种闪烁。
    initialLocation:
        ref.read(authProvider).isAuthenticated ? '/cooking' : loginRoutePath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final atLogin = state.matchedLocation == loginRoutePath;

      if (!loggedIn) return atLogin ? null : loginRoutePath;
      // 已登录还停在登录页（登录成功、或冷启动带着会话），送回主界面。
      return atLogin ? '/cooking' : null;
    },
    routes: [
      // 登录页注册在 ShellRoute **之外**：它不该有底部导航栏。
      GoRoute(
        path: loginRoutePath,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/cooking',
            builder: (context, state) => const CookingScreen(),
          ),
          GoRoute(
            path: '/community',
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// 底部导航栏骨架
class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // 根据当前路由判断选中的Tab
    final location = GoRouterState.of(context).uri.toString();
    int currentIndex = 0;
    if (location.startsWith('/community')) currentIndex = 1;
    if (location.startsWith('/statistics')) currentIndex = 2;
    if (location.startsWith('/settings')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0: context.go('/cooking'); break;
            case 1: context.go('/community'); break;
            case 2: context.go('/statistics'); break;
            case 3: context.go('/settings'); break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.restaurant_menu),
            label: l10n.navCooking,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            label: l10n.navCommunity,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: l10n.navStatistics,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: l10n.settingsTitle,
          ),
        ],
      ),
    );
  }
}