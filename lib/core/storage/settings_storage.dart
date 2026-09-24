// lib/core/storage/settings_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_settings.dart';

/// App 本地设置的持久化。
///
/// 只负责读写磁盘，不持有状态 —— 状态由 SettingsNotifier 管。
/// 两者关注点不同（饮食偏好 vs App 设置），所以分开存，互不影响。
class SettingsStorage {
  /// 存储键，测试里也用它来预置/断言数据
  static const String storageKey = 'app_settings';

  /// 读取本地设置。
  /// 从没存过、或者存的数据坏了，都返回默认值。
  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(storageKey);
    if (raw == null) return const AppSettings();

    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 格式对不上就退回默认值，而不是让 App 启动就崩
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(storageKey, jsonEncode(value.toJson()));
  }

  /// 清空本地设置，恢复默认 —— 给设置页的「恢复默认设置」用
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(storageKey);
  }
}
