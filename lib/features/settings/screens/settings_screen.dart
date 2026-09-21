// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_tile.dart';
import '../widgets/user_profile_card.dart';
import 'appearance_screen.dart';
import 'data_management_screen.dart';
import 'language_screen.dart';
import 'premium_screen.dart';
import 'voice_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // 👤 预留后端对接：接入 GET /me 之后改为从接口读
  static const String _nickname = '美食家';
  static const String _avatarText = '美';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 头像 + 用户名 + 个性签名，同一个矩形内
          UserProfileCard(
            nickname: _nickname,
            avatarText: _avatarText,
            signature: settings.signature,
            signaturePlaceholder: l10n.signaturePlaceholder,
            onTap: () => _editSignature(context, ref, settings.signature),
          ),
          const SizedBox(height: 20),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.folder_outlined,
                title: l10n.dataManagement,
                onTap: () => _open(context, const DataManagementScreen()),
              ),
              SettingsTile(
                icon: Icons.volume_up_outlined,
                title: l10n.voice,
                onTap: () => _open(context, const VoiceScreen()),
              ),
              SettingsTile(
                icon: Icons.language_outlined,
                title: l10n.language,
                trailingText: settings.locale.languageCode == 'en'
                    ? l10n.languageEn
                    : l10n.languageZh,
                onTap: () => _open(context, const LanguageScreen()),
              ),
              SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: l10n.appearance,
                trailingText: settings.themeMode == ThemeMode.dark
                    ? l10n.appearanceNight
                    : l10n.appearanceDay,
                onTap: () => _open(context, const AppearanceScreen()),
              ),
              SettingsTile(
                icon: Icons.workspace_premium_outlined,
                title: l10n.premium,
                onTap: () => _open(context, const PremiumScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 子页面沿用项目已有做法（community_screen 打开发帖页也是这么做的）：
  /// `Navigator.push` 全屏推入，不注册 go_router 路由 —— 设置子页因此没有底部 Tab。
  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _editSignature(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SignatureDialog(initial: current),
    );

    if (result != null) {
      ref.read(settingsProvider.notifier).setSignature(result);
    }
  }
}

/// 个性签名编辑弹窗。
///
/// 单独做成 StatefulWidget 是为了让 TextEditingController 由 State 持有并
/// 在 dispose() 里释放 —— 在 showDialog 外面 dispose 有可能早于退场动画。
class _SignatureDialog extends StatefulWidget {
  final String initial;

  const _SignatureDialog({required this.initial});

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.signatureEditTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(
          hintText: l10n.signatureEditHint,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
