// lib/features/settings/screens/voice_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/choice_tile.dart';
import '../widgets/settings_card.dart';

/// 语音设置：播报开关 + 语速 + 试听。
///
/// 「试听」是真的调 flutter_tts（该依赖此前已声明但全项目零引用），
/// 顺便验证它在各平台能否正常工作。
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  final FlutterTts _tts = FlutterTts();

  Future<void> _speak() async {
    final l10n = context.l10n;
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (!settings.ttsEnabled) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.voiceDisabledHint)));
      return;
    }

    try {
      await _tts.setLanguage(
        settings.locale.languageCode == 'en' ? 'en-US' : 'zh-CN',
      );
      await _tts.setSpeechRate(settings.ttsSpeechRate);
      await _tts.speak(l10n.voiceSampleText);
    } catch (e) {
      // 平台不支持（无头测试环境、部分桌面端）时不要崩，给个提示就好
      debugPrint('语音播报失败: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.voiceUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // 语速档位。flutter_tts 的 speechRate 取值 0.0 ~ 1.0，0.5 为正常。
    final rateChoices = <({String label, double value})>[
      (label: l10n.voiceRateSlow, value: 0.3),
      (label: l10n.voiceRateNormal, value: 0.5),
      (label: l10n.voiceRateFast, value: 0.7),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voice)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SettingsCard(
            children: [
              SwitchListTile(
                title: Text(
                  l10n.voiceEnabled,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.voiceEnabledDesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: settings.ttsEnabled,
                onChanged: notifier.setTtsEnabled,
              ),
            ],
          ),
          SettingsGroupLabel(l10n.voiceRate),
          SettingsCard(
            children: [
              for (final choice in rateChoices)
                ChoiceTile(
                  label: choice.label,
                  // 存的是 double，用容差比较避免浮点误差导致都不选中
                  selected:
                      (settings.ttsSpeechRate - choice.value).abs() < 0.01,
                  onTap: () => notifier.setTtsSpeechRate(choice.value),
                ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _speak,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.voiceTryListen),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
