// lib/features/settings/widgets/settings_tile.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 设置页里的一行栏目。
///
/// 左侧图标统一用品牌橙，右侧是可选的状态文字 + 箭头。
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// 右侧的状态摘要，比如当前语言、当前模式
  final String? trailingText;

  /// 为 null 时不可点击（用于付费服务这类纯展示项）
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}
