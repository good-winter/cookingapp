// lib/features/cooking/widgets/preference_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../../models/preference_options.dart';
import '../../../models/user_preferences.dart';
import '../../../providers/me_provider.dart';
import '../../../providers/preference_options_provider.dart';

class PreferenceModal extends ConsumerStatefulWidget {
  const PreferenceModal({super.key});

  @override
  ConsumerState<PreferenceModal> createState() => _PreferenceModalState();
}

class _PreferenceModalState extends ConsumerState<PreferenceModal> {
  late String _tempDietMode;
  late List<String> _tempCrowds;
  late List<String> _tempAvoids;

  /// 提交中：禁用按钮，避免连点发出两个 PUT。
  bool _saving = false;

  /// 保存失败的提示。契约的「中间态约定」要求显式报错 + 重试入口，
  /// 所以失败时**不关闭弹窗**，把话说明白留在这里让用户重试。
  String? _error;

  @override
  void initState() {
    super.initState();
    // 初始选中值来自服务端返回的当前偏好（GET /me）
    final current = ref.read(meProvider).valueOrNull?.preferences ??
        const UserPreferences();
    _tempDietMode = current.dietMode;
    _tempCrowds = List.of(current.crowds);
    _tempAvoids = List.of(current.avoidFoods);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // PUT 全量替换。成功后 MeController 会用服务端回显更新偏好，
      // 并让推荐重新拉取（丢弃旧游标）—— 所以这里不需要再做别的。
      await ref.read(meProvider.notifier).savePreferences(
            UserPreferences(
              dietMode: _tempDietMode,
              crowds: _tempCrowds,
              avoidFoods: _tempAvoids,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : '保存失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 选项字典来自服务端（GET /preferences/options），不再是本地常量
    final options = ref.watch(preferenceOptionsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.prefsTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _saving ? null : () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (options) {
              AsyncData(:final value) => _buildSections(value, l10n),
              AsyncError(:final error) => _buildOptionsError(
                  error is ApiException ? error.message : '选项加载失败',
                  () => ref.invalidate(preferenceOptionsProvider),
                ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error,
                  fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.prefsSave,
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSections(PreferenceOptions options, AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(l10n.prefsSectionDiet),
          Wrap(
            spacing: 8,
            children: options.dietModes.map((option) {
              return ChoiceChip(
                // 本地 l10n 优先（跟随语言切换），没这份文案才用服务端下发的 label
                label: Text(l10n.dietModeOption(option.code, option.label)),
                selected: _tempDietMode == option.code,
                onSelected: (selected) {
                  if (selected) setState(() => _tempDietMode = option.code);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(l10n.prefsSectionCrowd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.crowds.map((option) {
              return FilterChip(
                label: Text(l10n.crowdOption(option.code, option.label)),
                selected: _tempCrowds.contains(option.code),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _tempCrowds.add(option.code);
                    } else {
                      _tempCrowds.remove(option.code);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(l10n.prefsSectionAvoid),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.avoidFoods.map((option) {
              return FilterChip(
                label: Text(l10n.avoidFoodOption(option.code, option.label)),
                selected: _tempAvoids.contains(option.code),
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _tempAvoids.add(option.code);
                    } else {
                      _tempAvoids.remove(option.code);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 选项字典拉不到时的样子 —— 没有字典这三组 chip 一个都渲染不出来，
  /// 所以必须给重试入口，而不是留一片空白。
  Widget _buildOptionsError(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
