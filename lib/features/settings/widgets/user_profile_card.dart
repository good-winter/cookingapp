// lib/features/settings/widgets/user_profile_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 设置页顶部的用户信息卡。
///
/// 头像、用户名、个性签名**都在同一个圆角矩形里**（不是三块）。
/// 整卡可点，点击编辑个性签名。
class UserProfileCard extends StatelessWidget {
  final String nickname;
  final String avatarText;

  /// 个性签名。空串表示还没设置，此时显示 [signaturePlaceholder] 作为提示。
  final String signature;
  final String signaturePlaceholder;

  final VoidCallback onTap;

  const UserProfileCard({
    super.key,
    required this.nickname,
    required this.avatarText,
    required this.signature,
    required this.signaturePlaceholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSignature = signature.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.softPrimary(context),
                  child: Text(
                    avatarText,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasSignature ? signature : signaturePlaceholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          // 未设置时用更淡的颜色，读起来像占位提示而不是真签名
                          color: hasSignature
                              ? scheme.onSurfaceVariant
                              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontStyle:
                              hasSignature ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
