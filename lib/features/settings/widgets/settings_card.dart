// lib/features/settings/widgets/settings_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 设置页通用的卡片容器。
///
/// 所有颜色走 [AppTheme] 的主题派生方法，深色模式下自动跟随。
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(context),
      ),
      // 透明的 Material 是必须的：里面的 ListTile 把水波纹画在最近的 Material 上，
      // 如果最近的是外层 Scaffold，就会被这层背景色盖住 —— Flutter 会直接断言失败。
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(children: children),
        ),
      ),
    );
  }
}

/// 卡片外面的分组标题（「App 自带的数据」「我的数据」）。
class SettingsGroupLabel extends StatelessWidget {
  final String text;

  const SettingsGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 卡片内部的小分组标题（「统计数据」「社区行为」）。
class SettingsSubLabel extends StatelessWidget {
  final String text;

  const SettingsSubLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
