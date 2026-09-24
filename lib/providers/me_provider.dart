// lib/providers/me_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import 'api_providers.dart';
import 'recommend_provider.dart';

/// 当前用户与偏好（`GET /me`）。
///
/// 全 App 唯一持有「当前偏好」的地方 —— 首页的昵称、偏好弹窗的初始选中值都从
/// 这里读，不再有第二份本地状态，也就不会出现两处不一致。
class MeController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ref.read(apiClientProvider).getMe();

  /// 保存偏好：`PUT /me/preferences` 全量替换。
  ///
  /// 成功后用**服务端回显的结果**更新状态，而不是拿入参当真 —— 去重这类规整是
  /// 服务端做的，用入参会让本地显示与库里存的分叉。
  ///
  /// 随后 invalidate 推荐 provider，这一步就是契约说的「保存成功后必须重新请求
  /// 推荐，并**丢弃已持有的游标**」：游标存在推荐 provider 的 state 里，
  /// invalidate 会连它一起丢掉，下次从第一页重来。偏好一变，旧游标在服务端也已
  /// 失效（会返回 400），所以这不是可省掉的优化，而是正确性要求。
  ///
  /// 失败时异常向上抛给调用方（偏好弹窗），由界面显式报错并给重试入口 ——
  /// 契约的「中间态约定」不允许静默展示「偏好已更新、推荐还是旧的」。
  /// 注意失败时**不**invalidate 推荐：服务端没变，列表就还是对的。
  Future<void> savePreferences(UserPreferences next) async {
    final saved = await ref.read(apiClientProvider).updatePreferences(next);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(preferences: saved));
    }
    ref.invalidate(recommendProvider);
  }
}

final meProvider = AsyncNotifierProvider<MeController, UserProfile>(
  MeController.new,
);
