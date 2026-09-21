// lib/features/settings/screens/premium_screen.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../widgets/settings_card.dart';

/// 付费服务。
///
/// ⚠️ 本期**只做图形界面**，没有任何支付内核：价格是写死的占位数字，
/// 「立即开通」只弹一个提示。接入真实支付前，这里的所有数字都不代表承诺。
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    // 占位价格。真接入支付前不要当作有效定价 —— 货币符号也还没做本地化。
    final plans = <({String label, String price})>[
      (label: l10n.premiumPlanMonthly, price: '¥18'),
      (label: l10n.premiumPlanYearly, price: '¥128'),
      (label: l10n.premiumPlanLifetime, price: '¥298'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premium)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 会员状态卡
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.premiumCurrentPlan,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.premiumFreePlan,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SettingsGroupLabel(l10n.premiumBenefits),
          SettingsCard(
            children: [
              _BenefitRow(l10n.premiumBenefitRecognition),
              _BenefitRow(l10n.premiumBenefitNutrition),
              _BenefitRow(l10n.premiumBenefitHistory),
              _BenefitRow(l10n.premiumBenefitAdFree),
            ],
          ),

          SettingsGroupLabel(l10n.premiumChoosePlan),
          SettingsCard(
            children: [
              for (final plan in plans)
                ListTile(
                  title: Text(plan.label, style: const TextStyle(fontSize: 15)),
                  trailing: Text(
                    plan.price,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.premiumComingSoon)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n.premiumSubscribe,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;

  const _BenefitRow(this.text);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.check_circle,
        color: AppTheme.primaryColor,
        size: 20,
      ),
      title: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
