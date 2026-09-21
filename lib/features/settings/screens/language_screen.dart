// lib/features/settings/screens/language_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/app_settings.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/choice_tile.dart';
import '../widgets/settings_card.dart';

/// 语言：简体中文 / English。
///
/// ⚠️ 目前只有设置页走 i18n，其余页面仍是硬编码中文（刻意的：那三页即将被
/// dio 接口迁移重写）。等迁移完成后再逐步把其余文案搬进 arb。
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(settingsProvider).locale;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.language)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SettingsCard(
            children: [
              for (final locale in AppSettings.supportedLocales)
                ChoiceTile(
                  // 语言名用自己的语言书写，不随界面语言变化 —— 这是通行做法，
                  // 否则用户切到看不懂的语言后就找不回来了
                  label: locale.languageCode == 'en'
                      ? l10n.languageEn
                      : l10n.languageZh,
                  selected: current.languageCode == locale.languageCode,
                  onTap: () => notifier.setLocale(locale),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
