// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/settings_storage.dart';
import '../models/app_settings.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage, AppSettings initial) : super(initial);

  final SettingsStorage _storage;

  /// 全量替换。一般不用直接调，优先用下面的具名方法。
  void update(AppSettings next) {
    state = next;
    // 故意不 await：界面立刻更新，不必等磁盘写完
    _persist(next);
  }

  void setThemeMode(ThemeMode mode) => update(state.copyWith(themeMode: mode));

  void setLocale(Locale locale) => update(state.copyWith(locale: locale));

  void setSignature(String signature) =>
      update(state.copyWith(signature: signature));

  void setTtsEnabled(bool enabled) =>
      update(state.copyWith(ttsEnabled: enabled));

  void setTtsSpeechRate(double rate) =>
      update(state.copyWith(ttsSpeechRate: rate));

  /// 恢复默认设置
  void resetToDefaults() {
    update(const AppSettings());
  }

  Future<void> _persist(AppSettings settings) async {
    try {
      await _storage.save(settings);
    } catch (e) {
      // 落盘失败不该影响 UI，记个日志就好
      debugPrint('保存本地设置失败: $e');
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  // 正式启动时由 appOverrides() 用本地数据 override；
  // 这里是兜底，保证单独引用该 provider 时也能跑。
  return SettingsNotifier(SettingsStorage(), const AppSettings());
});

/// 读取本地已保存的设置，返回注入了初始状态的 override。
///
/// 与 preferenceOverrides() 对称，由 core/bootstrap.dart 汇总。
Future<List<Override>> settingsOverrides() async {
  final storage = SettingsStorage();
  final initial = await storage.load();
  return [
    settingsProvider.overrideWith((ref) => SettingsNotifier(storage, initial)),
  ];
}
