// lib/core/bootstrap.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../providers/api_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'network/api_client.dart';
import 'network/cooking_api.dart';
import 'storage/auth_storage.dart';

/// 推出启动时的登录态。
///
/// 优先级：
/// 1. 本地存有会话（用户上次登录过）→ 用它。**必须先查它**，否则带
///    `API_TOKEN` 启动时会盖掉用户真实登录的账号。
/// 2. 否则编译期 `API_TOKEN` 非空 → 视为已登录，且**不落盘** ——
///    契约「开发期 token 注入」要求测试 token 不进磁盘。
/// 3. 都没有 → 未登录，进登录页。
Future<AuthSession?> resolveInitialSession() async {
  final stored = await AuthStorage().load();
  if (stored != null) return stored;

  final devToken = ApiClient.defaultToken;
  if (devToken.isNotEmpty) {
    return AuthSession(token: devToken, phone: '');
  }
  return null;
}

/// 汇总启动时需要的所有 provider 注入。
///
/// main() 和测试都走这个函数，保证两条路径的接线完全一致 ——
/// 测试里跑的接线就是线上跑的接线。
///
/// [api] 只由测试传入，用来注入替身，使界面测试完全不碰真实网络。
/// 界面一旦依赖网络，回归网就必须有一个统一的口子把它换掉：否则 18 个经过
/// pumpApp 的 widget 用例会同时失败，红成一片就失去了定位能力。
///
/// [session] 是解析好的初始会话。生产的 main() 传 `await resolveInitialSession()`；
/// 测试显式传自己想要的登录态，不走存储 —— 这样「未登录」在测试里是确定的，
/// 不会因为开发机恰好设了 API_TOKEN 而变成已登录。
Future<List<Override>> appOverrides({CookingApi? api, AuthSession? session}) async => [
      if (api != null)
        apiClientProvider.overrideWithValue(api)
      else
        // 生产路径：真 ApiClient 也要装上初始 token，否则冷启动的第一次请求
        // 会不带 Authorization 而拿到 401。
        apiClientProvider.overrideWithValue(ApiClient(token: session?.token)),
      authProvider.overrideWith(
        () => AuthNotifier(AuthStorage(), AuthState(session: session)),
      ),
      ...await settingsOverrides(),
    ];
