// lib/core/bootstrap.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_providers.dart';
import '../providers/settings_provider.dart';
import 'network/cooking_api.dart';

/// 汇总启动时需要的所有 provider 注入。
///
/// main() 和测试都走这个函数，保证两条路径的接线完全一致 ——
/// 测试里跑的接线就是线上跑的接线。
///
/// [api] 只由测试传入，用来注入替身，使界面测试完全不碰真实网络。
/// 界面一旦依赖网络，回归网就必须有一个统一的口子把它换掉：否则 18 个经过
/// pumpApp 的 widget 用例会同时失败，红成一片就失去了定位能力。
Future<List<Override>> appOverrides({CookingApi? api}) async => [
      if (api != null) apiClientProvider.overrideWithValue(api),
      ...await settingsOverrides(),
    ];
