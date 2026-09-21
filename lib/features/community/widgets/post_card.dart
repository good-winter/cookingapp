// lib/features/community/widgets/post_card.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onFollow;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 头部：头像、昵称、标签、关注按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softPrimary(context),
                  child: Text(
                    post.userAvatar,
                    style: const TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          // 用户身份标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              // 半透明绿在深浅两种底色下都成立，
                              // 写死的浅绿 (#E8F8F0) 在深色模式会变成一块亮斑
                              color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              post.userTag,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF2ECC71)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.time,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 关注按钮
                TextButton(
                  onPressed: onFollow,
                  style: TextButton.styleFrom(
                    foregroundColor: post.isFollowed
                        ? scheme.onSurfaceVariant
                        : const Color(0xFFFF7A00),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: Text(post.isFollowed ? '已关注' : '+ 关注'),
                ),
              ],
            ),
          ),

          // 2. 正文文本
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              post.content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),

          // 3. 菜品图片（模拟）
          Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(post.imageEmoji, style: const TextStyle(fontSize: 80)),
            ),
          ),
          const SizedBox(height: 12),

          // 4. 话题标签
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              children: post.hashtags.map((tag) => Text(
                '#$tag',
                style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 13),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // 5. 底部互动栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionItem(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked ? Colors.red : scheme.onSurfaceVariant,
                  count: post.likes,
                  onTap: onLike,
                ),
                _buildActionItem(icon: Icons.chat_bubble_outline, color: scheme.onSurfaceVariant, count: post.comments),
                _buildActionItem(icon: Icons.star_border, color: scheme.onSurfaceVariant, count: 0),
                _buildActionItem(icon: Icons.share_outlined, color: scheme.onSurfaceVariant, count: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required int count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}