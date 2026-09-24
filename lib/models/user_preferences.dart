// lib/models/user_preferences.dart

/// 用户的饮食偏好。
///
/// 三个字段的值一律是契约定义的**英文码**（`normal` / `pregnant` / `pork` …），
/// 不再是中文常量。显示文案由 l10n 的 enum_labels 表翻译，与这里存的值解耦 ——
/// 这正是契约要求「英文码 + 前端 label 映射表」的目的：切换语言不用改数据。
class UserPreferences {
  const UserPreferences({
    this.dietMode = 'normal',
    this.crowds = const [],
    this.avoidFoods = const [],
  });

  final String dietMode;
  final List<String> crowds;
  final List<String> avoidFoods;

  UserPreferences copyWith({
    String? dietMode,
    List<String>? crowds,
    List<String>? avoidFoods,
  }) {
    return UserPreferences(
      dietMode: dietMode ?? this.dietMode,
      crowds: crowds ?? this.crowds,
      avoidFoods: avoidFoods ?? this.avoidFoods,
    );
  }

  /// PUT /me/preferences 的请求体。
  Map<String, dynamic> toJson() => {
        'dietMode': dietMode,
        'crowds': crowds,
        'avoidFoods': avoidFoods,
      };

  /// 从服务端响应解析。
  ///
  /// 刻意**不做**取值白名单校验。合法取值由服务端的字典决定
  /// （GET /preferences/options），前端再硬编码一份副本只会在后端新增选项时
  /// 把新值判成非法、静默退回默认 —— 那恰恰是「新增选项无需发版」要避免的事。
  /// 所以这里只做类型防护，脏数据才退回默认值。
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final mode = json['dietMode'];
    return UserPreferences(
      dietMode: mode is String && mode.isNotEmpty ? mode : 'normal',
      crowds: _stringList(json['crowds']),
      avoidFoods: _stringList(json['avoidFoods']),
    );
  }

  /// 只保留合法的字符串元素，脏数据直接丢掉
  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }
}
