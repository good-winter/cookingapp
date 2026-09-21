// lib/features/settings/widgets/choice_tile.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 单选行（语言、模式共用）。
///
/// 没有用 `RadioListTile`：它的 `groupValue` / `onChanged` 在新版 Flutter 里
/// 已经进入废弃流程，改由 `RadioGroup` 承担。自己画一行反而稳定，
/// 也能和设置页其它栏目保持同一套视觉。
class ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? AppTheme.primaryColor : null,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: AppTheme.primaryColor, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
