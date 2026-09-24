// lib/models/user_profile.dart

import 'user_preferences.dart';

/// `GET /me` 的响应：当前用户 + 其饮食偏好。
///
/// 契约把偏好放在 /me 下返回，是为了让首页只需 2 次请求
/// （`/me` + `/recipes/recommend`），而不是 3 次。
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    required this.avatarText,
    required this.timezone,
    required this.preferences,
  });

  final String id;
  final String nickname;

  /// 头像用文字代替图片，如「美」。
  final String avatarText;

  /// IANA 时区标识，如 `Asia/Shanghai`。
  /// 统计接口按它切分自然日，本期界面还用不到，先原样带着。
  final String timezone;

  final UserPreferences preferences;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarText: json['avatarText'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Shanghai',
      preferences: UserPreferences.fromJson(
        (json['preferences'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  UserProfile copyWith({UserPreferences? preferences}) {
    return UserProfile(
      id: id,
      nickname: nickname,
      avatarText: avatarText,
      timezone: timezone,
      preferences: preferences ?? this.preferences,
    );
  }
}
