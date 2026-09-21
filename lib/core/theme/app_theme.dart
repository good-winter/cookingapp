// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFFF7A00); // 暖橙色
  static const Color bgColor = Color(0xFFF8F9FA);
  static const Color darkBgColor = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);

  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: bgColor,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
    ),
  );

  /// 深色主题。
  ///
  /// ⚠️ `fromSeed` 必须显式传 `brightness` —— 不传的话派生出来的一整套
  /// Material 3 颜色（surface / onSurface 等）仍然全是浅色，
  /// 深色模式下会出现「深底 + 浅色控件」的错乱。
  static final ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBgColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      backgroundColor: darkSurfaceColor,
      elevation: 8,
    ),
  );

  /// 卡片背景：浅色下是纯白，深色下是抬升一层的表面色。
  ///
  /// 各个页面原先直接写 `Colors.white`，深色模式下会变成一块块白板。
  /// 统一走这里，改一处即可。
  static Color cardColor(BuildContext context) {
    // 浅色下保持纯白（和现有设计一致，零视觉变化），深色下换成抬升的表面色
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurfaceColor
        : Colors.white;
  }

  /// 卡片阴影。深色下阴影几乎不可见，用更淡的值避免脏边。
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// 品牌浅橙底（头像底、选中态、AI 卡片底）。
  ///
  /// 原先各处写的是 `Color(0xFFFFF0E5)`，深色下会变成一块刺眼的亮橙。
  /// 深色下改用低透明度的品牌色叠加，视觉上保持同一套语言。
  static Color softPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? primaryColor.withValues(alpha: 0.18)
        : const Color(0xFFFFF0E5);
  }
}
