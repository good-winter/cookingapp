// lib/features/settings/screens/appearance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/choice_tile.dart';
import '../widgets/settings_card.dart';

/// 模式：白天 / 晚上。
///
/// 需求明确不要「跟随系统」，所以只有两个选项，不提供 system。
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(settingsProvider).themeMode;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearance)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SettingsCard(
            children: [
              ChoiceTile(
                label: l10n.appearanceDay,
                selected: mode == ThemeMode.light,
                onTap: () => notifier.setThemeMode(ThemeMode.light),
              ),
              ChoiceTile(
                label: l10n.appearanceNight,
                selected: mode == ThemeMode.dark,
                onTap: () => notifier.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
