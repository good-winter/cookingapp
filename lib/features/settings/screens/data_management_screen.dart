// lib/features/settings/screens/data_management_screen.dart
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../widgets/settings_card.dart';

/// 数据管理。
///
/// 分两类：App 自带的数据 / 用户使用过程中产生的数据（后者再分统计与社区）。
class DataManagementScreen extends StatelessWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataManagement)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SettingsGroupLabel(l10n.dataBuiltIn),
          SettingsCard(
            children: [
              _ClearTile(
                title: l10n.dataRecipeCache,
                subtitle: l10n.dataRecipeCacheDesc,
              ),
              _ClearTile(
                title: l10n.dataMediaCache,
                subtitle: l10n.dataMediaCacheDesc,
              ),
            ],
          ),
          SettingsGroupLabel(l10n.dataMine),
          SettingsCard(
            children: [
              SettingsSubLabel(l10n.dataStats),
              _ClearTile(title: l10n.dataMealRecords),
              SettingsSubLabel(l10n.dataCommunity),
              _ClearTile(title: l10n.dataMyPosts),
              _ClearTile(title: l10n.dataMyComments),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一行可清除的数据项。
///
/// ⚠️ 本期是**纯图形界面**：统计数据、帖子、发言目前都还是页面里的假数据常量
/// （`statistics_screen.dart` / `community_screen.dart` 里写死的 List），
/// 不在任何可清除的存储里，所以点击只会弹确认框和「已清除」提示，
/// **不会真的删除任何数据**。
///
/// 接入后端后这里要改成调用删除接口 —— 注意接口契约
/// （docs/API_CONTRACT.md）目前**还没有** DELETE /stats/records、
/// DELETE /posts/{id} 这类端点，需要先和后端补齐。
class _ClearTile extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _ClearTile({required this.title, this.subtitle});

  Future<void> _confirmAndClear(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dataClearConfirmTitle),
        content: Text(l10n.dataClearConfirmMessage(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.actionClear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dataCleared)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      trailing: TextButton(
        onPressed: () => _confirmAndClear(context),
        child: Text(context.l10n.actionClear),
      ),
    );
  }
}
