// lib/models/auth_result.dart

import '../core/network/api_exception.dart';
import 'user_profile.dart';

/// `POST /auth/sms/send` 的响应。
class SmsSendResult {
  const SmsSendResult({
    required this.expiresInSeconds,
    required this.retryAfterSeconds,
    this.devCode,
  });

  /// 验证码有效期。
  final int expiresInSeconds;

  /// 距下次可重发的间隔，**由服务端下发**。
  ///
  /// 前端按钮的倒计时用它，而不是硬编码 60 —— 限流窗口是服务端定的，
  /// 前端自己猜一个数，两边一改就会出现「按钮亮了但点了被 429」。
  final int retryAfterSeconds;

  /// **仅开发期**服务端才回显的验证码；生产环境恒为 null。
  /// 拿到它就说明当前后端跑在 development 下。
  final String? devCode;

  static SmsSendResult fromJson(Map<String, dynamic> json) => SmsSendResult(
        expiresInSeconds: _positiveInt(json['expiresInSeconds'], 300),
        retryAfterSeconds: _positiveInt(json['retryAfterSeconds'], 60),
        devCode: json['devCode'] is String ? json['devCode'] as String : null,
      );
}

/// `POST /auth/sms/verify` 的响应。
class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
    required this.isNewUser,
  });

  final String token;

  final UserProfile user;

  /// 本次登录顺带完成了注册。界面据此说一句「欢迎新用户」，
  /// 而不必自己去猜这个号码以前来没来过。
  final bool isNewUser;

  static AuthResult fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    // 没有 token 的「成功」响应是坏的。与其让一个空 token 流到网络层
    // 变成一串 401，不如在这里就把响应判为不可用。
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        code: ApiException.networkErrorCode,
        message: '服务端未返回登录凭证',
      );
    }
    return AuthResult(
      token: token,
      user: UserProfile.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      isNewUser: json['isNewUser'] == true,
    );
  }
}

int _positiveInt(Object? value, int fallback) =>
    value is int && value > 0 ? value : fallback;
