// lib/providers/api_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/cooking_api.dart';
import 'auth_provider.dart';

/// 网络层的注入点 —— 全 App 唯一创建 [ApiClient] 的地方。
///
/// 测试通过 override 这个 provider 塞进替身（见 test/helpers/fake_cooking_api.dart），
/// 从而完全不碰真实网络。这也是那 18 个经过 pumpApp 的 widget 用例能继续跑的前提：
/// 界面一旦依赖网络，回归网就必须有一个统一的口子换掉它，否则会一次性全红。
final apiClientProvider = Provider<CookingApi>((ref) {
  return ApiClient(
    // 401 的收口点。用 ref.read 而非 ref.watch：这个回调只在请求出错时才跑，
    // 不在 provider 构建期 —— 否则它与 authProvider 会互相依赖成环
    // （authProvider 的方法里要读本 provider）。
    onUnauthorized: () => ref.read(authProvider.notifier).handleUnauthorized(),
  );
});
