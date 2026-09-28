// lib/core/storage/auth_storage.dart

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/auth_session.dart';

/// 登录会话的持久化。
///
/// 与 [SettingsStorage] 同一套路：只管读写磁盘、不持有状态（状态在
/// AuthNotifier 里），解析失败一律退回 null 而不是抛异常。
///
/// **与契约里「开发期 token 不落盘」的关系**：那条约束针对的是
/// `--dart-define=API_TOKEN` 注入的测试 token，目的是不让测试凭据进版本库、
/// 进磁盘。用户自己登录换来的 token 必须落盘，否则每次冷启动都要重新收验证码，
/// 登录页就白做了。所以本文件只保存后者，前者由 bootstrap 直接注入内存。
class AuthStorage {
  /// 存储键，测试里也用它来预置/断言数据
  static const String storageKey = 'auth_session';

  /// 读取已保存的会话。没存过、或存的东西坏了，都返回 null（= 未登录）。
  Future<AuthSession?> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(storageKey);
    if (raw == null) return null;
    return AuthSession.decode(raw);
  }

  Future<void> save(AuthSession session) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(storageKey, session.encode());
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(storageKey);
  }
}
