// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/auth_storage.dart';
import '../models/auth_result.dart';
import '../models/auth_session.dart';
import 'api_providers.dart';
import 'me_provider.dart';
import 'recommend_provider.dart';

/// 登录态。
///
/// 刻意保持**同步可读**（[isAuthenticated] 是普通 getter，不是 Future）：
/// go_router 的 redirect 必须当场判定该不该跳登录页，拿不到 Future。
/// 会话本身在 bootstrap 阶段就读完了，所以这里没有异步的必要。
class AuthState {
  const AuthState({this.session});

  final AuthSession? session;

  bool get isAuthenticated => session != null;

  /// 当前账号手机号；开发期走 API_TOKEN 时为空串。
  String get phone => session?.phone ?? '';

  /// 手机号掩码（`138****8000`），给设置页显示当前账号用；
  /// 开发期走 API_TOKEN 时为空串 —— 那种登录方式没有手机号可言。
  String get maskedPhone => session?.maskedPhone ?? '';
}

class AuthNotifier extends Notifier<AuthState> {
  AuthNotifier(this._storage, this._initial);

  final AuthStorage _storage;
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  /// 发送验证码。不改变登录态，只把服务端给的限流窗口回传给界面。
  Future<SmsSendResult> sendSmsCode(String phone) =>
      ref.read(apiClientProvider).sendSmsCode(phone);

  /// 校验验证码并登录。成功后就地完成四件事：落盘、装给网络层、更新状态、
  /// 丢弃上一个账号的数据。
  Future<AuthResult> signInWithSmsCode({
    required String phone,
    required String code,
  }) async {
    final api = ref.read(apiClientProvider);
    final result = await api.verifySmsCode(phone: phone, code: code);

    final session = AuthSession(token: result.token, phone: phone);
    await _storage.save(session);
    api.setToken(result.token);
    state = AuthState(session: session);
    _resetUserScopedState();

    return result;
  }

  /// 退出登录。
  ///
  /// 不等落盘完成再改状态：把用户送回登录页这件事比磁盘写更要紧，
  /// 而且写失败也只影响「下次启动要不要重新登录」。
  Future<void> signOut() async {
    ref.read(apiClientProvider).setToken(null);
    state = const AuthState();
    _resetUserScopedState();
    await _clearStored();
  }

  /// 收到 401 时由 [ApiClient] 的拦截器回调。
  ///
  /// token 可能在服务端被清掉（换库、清数据），此后每次请求都是 401。
  /// 这时唯一有意义的动作就是丢掉本地会话、把用户送回登录页；
  /// 继续拿着一个已知无效的 token 重试只会让界面反复报「未认证」。
  void handleUnauthorized() {
    // 已经在未登录态就别再动一次：401 可能来自多个并发请求，
    // 每个都触发一遍 invalidate 会造成无谓的重复拉取。
    if (!state.isAuthenticated) return;

    ref.read(apiClientProvider).setToken(null);
    state = const AuthState();
    _resetUserScopedState();
    // 故意不 await —— 见 signOut 的说明。
    _clearStored();
  }

  /// 换了人，跟用户绑定的数据必须全部重拉。
  ///
  /// 不做的后果是拿新 token 显示上一个账号的昵称与推荐，且不会报任何错。
  void _resetUserScopedState() {
    ref.invalidate(meProvider);
    ref.invalidate(recommendProvider);
  }

  Future<void> _clearStored() async {
    try {
      await _storage.clear();
    } catch (_) {
      // 落盘失败不该挡住登出：内存里的会话已经清掉了，界面已经回到登录页。
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  // 正式启动时由 appOverrides() 注入已读出的会话；
  // 这里是兜底，保证单独引用该 provider 时也能跑（与 settingsProvider 同款）。
  return AuthNotifier(AuthStorage(), const AuthState());
});
