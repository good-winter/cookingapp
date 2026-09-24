// lib/core/network/cooking_api.dart

import '../../features/cooking/models/recipe_page.dart';
import '../../models/preference_options.dart';
import '../../models/user_preferences.dart';
import '../../models/user_profile.dart';

/// 契约 Phase 1 四个接口的抽象。
///
/// 抽成接口、而不是让 provider 直接依赖 dio，是为了让界面测试能注入替身 ——
/// 否则每个 widget 用例都要真的跑一遍网络栈（而测试环境里没有后端，只能超时）。
/// 测试用的替身是 test/helpers/fake_cooking_api.dart。
abstract interface class CookingApi {
  /// `GET /me` —— 当前用户 + 饮食偏好。
  Future<UserProfile> getMe();

  /// `PUT /me/preferences` —— 全量替换，返回服务端规整后的偏好。
  ///
  /// 必须用返回值更新本地状态，而不是拿入参当真：去重之类的规整是服务端做的，
  /// 用入参会让本地状态与库里存的分叉。
  Future<UserPreferences> updatePreferences(UserPreferences prefs);

  /// `GET /preferences/options` —— 选项字典（三组）。
  Future<PreferenceOptions> getOptions();

  /// `GET /recipes/recommend` —— 按服务端存的偏好算出的推荐。
  ///
  /// [cursor] 为空表示从头拉第一页。偏好变更后必须**丢弃旧游标**重新拉：
  /// 服务端会拒绝失效游标（400 INVALID_PARAMETER），因为继续用它会得到
  /// 一份「新排序 + 旧位置」拼出来的错乱序列。
  Future<RecipePage> recommend({int limit, String? cursor});
}
