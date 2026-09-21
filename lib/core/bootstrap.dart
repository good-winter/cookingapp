// lib/core/bootstrap.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preference_provider.dart';
import '../providers/settings_provider.dart';

/// 汇总启动时需要的所有 provider 注入。
///
/// main() 和测试都走这个函数，保证两条路径的接线完全一致 ——
/// 测试里跑的接线就是线上跑的接线。
///
/// 新增需要从本地读初始值的 provider 时，在这里加一行即可。
Future<List<Override>> appOverrides() async => [
      ...await preferenceOverrides(),
      ...await settingsOverrides(),
    ];
