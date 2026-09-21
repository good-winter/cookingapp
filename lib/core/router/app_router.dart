// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入四个核心页面
import '../../features/cooking/screens/cooking_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/statistics/screens/statistics_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../l10n/l10n.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/cooking', // 默认进入烹饪页
    routes: [
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