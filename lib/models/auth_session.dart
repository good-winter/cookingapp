// lib/models/auth_session.dart

import 'dart:convert';

/// 本地保存的登录会话。
///
/// 只存两样：token，以及用户自己输的手机号。手机号留着是为了在设置页显示
/// 「当前账号 138****8000」—— 契约定稿的 User 模型里没有 phone 字段，
/// 而我们不该为了一个展示字段去改那份已经定稿的协作基准。
class AuthSession {
  const AuthSession({required this.token, required this.phone});

  final String token;

  /// 登录时输入的手机号。开发期走 `--dart-define=API_TOKEN` 时为**空串** ——
  /// 那种登录方式没有手机号可言，界面需要能区分这两种情况。
  final String phone;

  /// 手机号掩码，给设置页显示用。
  ///
  /// 长度不是 11 位就原样返回，不硬凑格式：开发期注入的 token 没有手机号，
  /// 硬凑会显示出一串像乱码的东西。
  String get maskedPhone {
    if (phone.length != 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(7)}';
  }

  Map<String, dynamic> toJson() => {'token': token, 'phone': phone};

  String encode() => jsonEncode(toJson());

  /// 解析本地存的会话。
  ///
  /// 任何解析不出来、或缺少 token 的情况都返回 null（= 未登录），不抛异常 ——
  /// 本地数据坏了应该表现为「需要重新登录」，而不是让 App 启动就崩。
  static AuthSession? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static AuthSession? fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String || token.isEmpty) return null;
    final phone = json['phone'];
    return AuthSession(token: token, phone: phone is String ? phone : '');
  }
}
