// lib/providers/preference_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/preference_storage.dart';
import '../models/user_preferences.dart';

class PreferenceNotifier extends StateNotifier<UserPreferences> {
  PreferenceNotifier(this._storage, UserPreferences initial) : super(initial);

  final PreferenceStorage _storage;

  void updatePreferences(UserPreferences newPrefs) {
    state = newPrefs;
    // 故意不 await：界面立刻更新，不必等磁盘写完
    _persist(newPrefs);
  }

  Future<void> _persist(UserPreferences prefs) async {
    try {
      await _storage.save(prefs);
    } catch (e) {
      // 落盘失败不该影响 UI，记个日志就好
      debugPrint('保存饮食偏好失败: $e');
    }
  }
}

final preferenceProvider =
    StateNotifierProvider<PreferenceNotifier, UserPreferences>((ref) {
  // 正式启动时由 main() 用本地数据 override（见下面的 preferenceOverrides）；
  // 这里是兜底，保证单独引用该 provider 时也能跑。
  return PreferenceNotifier(PreferenceStorage(), const UserPreferences());
});

/// 读取本地已保存的偏好，返回注入了初始状态的 override。
///
/// main() 和测试都走这个函数，保证两条路径的接线完全一致 ——
/// 测试里跑的接线就是线上跑的接线。
Future<List<Override>> preferenceOverrides() async {
  final storage = PreferenceStorage();
  final initial = await storage.load();
  return [
    preferenceProvider.overrideWith((ref) => PreferenceNotifier(storage, initial)),
  ];
}
