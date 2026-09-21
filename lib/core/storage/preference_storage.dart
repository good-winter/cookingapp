// lib/core/storage/preference_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_preferences.dart';

/// 饮食偏好的本地持久化。
///
/// 只负责读写磁盘，不持有状态 —— 状态由 PreferenceNotifier 管。
class PreferenceStorage {
  /// 存储键，测试里也用它来预置/断言数据
  static const String storageKey = 'user_preferences';

  /// 读取本地偏好。
  /// 从没存过、或者存的数据坏了，都返回默认值。
  Future<UserPreferences> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(storageKey);
    if (raw == null) return UserPreferences();

    try {
      return UserPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 格式对不上（比如手改过、或字段类型变了），
      // 退回默认值，而不是让 App 启动就崩
      return UserPreferences();
    }
  }

  Future<void> save(UserPreferences value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(storageKey, jsonEncode(value.toJson()));
  }

  /// 清空本地偏好，恢复默认 —— 留给设置页的「恢复默认」用
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(storageKey);
  }
}
