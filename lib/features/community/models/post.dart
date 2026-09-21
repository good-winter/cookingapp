// lib/features/community/models/post.dart
class Post {
  final String id;
  final String userName;
  final String userAvatar; // 用文字代替头像
  final String userTag; // 比如 "孕妇"、"健身"
  final String time;
  final String content;
  final String imageEmoji; // 用 Emoji 模拟菜品图
  final List<String> hashtags;
  int likes;
  int comments;
  bool isLiked;
  bool isFollowed;

  Post({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.userTag,
    required this.time,
    required this.content,
    required this.imageEmoji,
    required this.hashtags,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
    this.isFollowed = false,
  });
}