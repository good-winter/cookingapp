// lib/models/user_preferences.dart
class UserPreferences {
  final String dietMode; // 正常人 / 素食主义
  final List<String> crowds; // ['孕妇', '健身人群']
  final List<String> avoidFoods; // ['猪肉', '香菜']

  const UserPreferences({
    this.dietMode = '正常人',
    this.crowds = const [],
    this.avoidFoods = const [],
  });

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

  /// 序列化，用于本地持久化 —— 见 core/storage/preference_storage.dart
  Map<String, dynamic> toJson() => {
        'dietMode': dietMode,
        'crowds': crowds,
        'avoidFoods': avoidFoods,
      };

  /// 从本地存储还原。
  /// 字段缺失或类型不对时退回默认值，避免旧数据让 App 启动即崩。
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final mode = json['dietMode'];
    return UserPreferences(
      // 不认识的模式（比如旧版本存的值）一律退回默认
      dietMode:
          mode is String && dietModeOptions.contains(mode) ? mode : '正常人',
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

// 预设选项
const List<String> dietModeOptions = ['正常人', '素食主义'];
const List<String> crowdOptions = ['孕妇', '学生', '健身人群', '老人', '运动员'];
const List<String> avoidOptions = ['猪肉', '牛肉', '海鲜', '香菜', '辛辣'];
