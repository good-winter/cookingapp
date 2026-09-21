// lib/features/cooking/widgets/preference_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_preferences.dart';
import '../../../providers/preference_provider.dart';

class PreferenceModal extends ConsumerStatefulWidget {
  const PreferenceModal({super.key});

  @override
  ConsumerState<PreferenceModal> createState() => _PreferenceModalState();
}

class _PreferenceModalState extends ConsumerState<PreferenceModal> {
  late String _tempDietMode;
  late List<String> _tempCrowds;
  late List<String> _tempAvoids;

  @override
  void initState() {
    super.initState();
    // 初始化时，读取当前的全局偏好
    final currentPrefs = ref.read(preferenceProvider);
    _tempDietMode = currentPrefs.dietMode;
    _tempCrowds = List.from(currentPrefs.crowds);
    _tempAvoids = List.from(currentPrefs.avoidFoods);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(l10n.prefsSectionDiet),
                  Wrap(
                    spacing: 8,
                    children: dietModeOptions.map((mode) {
                      return ChoiceChip(
                        // 只换显示文案；selected 比较用的仍是中文字面值
                        label: Text(l10n.dietMode(mode)),
                        selected: _tempDietMode == mode,
                        onSelected: (selected) {
                          if (selected) setState(() => _tempDietMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(l10n.prefsSectionCrowd),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: crowdOptions.map((crowd) {
                      final isSelected = _tempCrowds.contains(crowd);
                      return FilterChip(
                        label: Text(l10n.crowd(crowd)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _tempCrowds.add(crowd);
                            } else {
                              _tempCrowds.remove(crowd);
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
                    children: avoidOptions.map((avoid) {
                      final isSelected = _tempAvoids.contains(avoid);
                      return FilterChip(
                        label: Text(l10n.avoidFood(avoid)),
                        selected: isSelected,
                        selectedColor: Colors.red.shade100,
                        checkmarkColor: Colors.red,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _tempAvoids.add(avoid);
                            } else {
                              _tempAvoids.remove(avoid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 提交更新到 Riverpod
                ref.read(preferenceProvider.notifier).updatePreferences(
                  UserPreferences(
                    dietMode: _tempDietMode,
                    crowds: _tempCrowds,
                    avoidFoods: _tempAvoids,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(l10n.prefsSave,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          )
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