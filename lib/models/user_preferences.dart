// lib/models/user_preferences.dart
class UserPreferences {
  final String dietMode; // 正常人 / 素食主义
  final List<String> crowds; // ['孕妇', '健身人群']
  final List<String> avoidFoods; // ['猪肉', '香菜']

  UserPreferences({
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
}

// 预设选项
const List<String> crowdOptions = ['孕妇', '学生', '健身人群', '老人', '运动员'];
const List<String> avoidOptions = ['猪肉', '牛肉', '海鲜', '香菜', '辛辣'];