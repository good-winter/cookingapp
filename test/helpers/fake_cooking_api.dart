// test/helpers/fake_cooking_api.dart

import 'package:cooking_app/core/network/api_exception.dart';
import 'package:cooking_app/core/network/cooking_api.dart';
import 'package:cooking_app/features/cooking/models/recipe.dart';
import 'package:cooking_app/features/cooking/models/recipe_page.dart';
import 'package:cooking_app/models/preference_options.dart';
import 'package:cooking_app/models/user_preferences.dart';
import 'package:cooking_app/models/user_profile.dart';

/// 测试用的 [CookingApi] 替身。
///
/// 它**不是**「返回一堆死数据」的桩：按契约真的实现了服务端那套语义 ——
/// 偏好过滤、人群命中数降序、游标分页、以及「偏好变更后旧游标失效」。
///
/// 这样做的价值在于：widget 测试断言的仍然是「改偏好 → 推荐变了」这条真实链路，
/// 而不是「界面把我喂的数组原样渲染了」这种同义反复。代价是它需要与后端行为
/// 保持同步 —— 所以逻辑刻意写得很短，只覆盖被测到的那几条规则。
class FakeCookingApi implements CookingApi {
  FakeCookingApi({
    List<Recipe>? recipes,
    UserProfile? profile,
    PreferenceOptions? options,
  })  : recipes = recipes ?? defaultRecipes,
        profile = profile ?? defaultProfile,
        options = options ?? defaultOptions;

  /// 「服务端菜谱库」。刻意只放 4 条：横向 ListView 是懒加载的，
  /// 测试视口（800×600）里只放得下约 5 张 150 宽的卡片 —— 条数多了
  /// 后面的卡片压根不会被构建，断言会莫名其妙地 findsNothing。
  /// 分页相关的用例放在 test/providers 里用更多数据测。
  final List<Recipe> recipes;

  UserProfile profile;
  final PreferenceOptions options;

  // 调用计数：用来断言「保存后确实重新拉了推荐」这类行为，
  // 而不只是断言最终画面 —— 否则接线错了也可能碰巧显示对。
  int getMeCalls = 0;
  int updatePreferencesCalls = 0;
  int recommendCalls = 0;

  /// 设成非 null 时，下一次 recommend 会抛出它。用来测错误态与重试。
  ApiException? failNextRecommend;

  /// 设成非 null 时，下一次 updatePreferences 会抛出它。
  /// 用来测契约的「中间态约定」：保存失败必须显式报错并留在弹窗里重试。
  ApiException? failNextUpdate;

  /// 最近一次 PUT 收到的偏好，方便断言「提交的确实是选中的值」。
  UserPreferences? lastSubmitted;

  /// 每次 recommend 收到的游标。
  ///
  /// 有了它才能断言「保存偏好后确实**丢弃**了游标」—— 只断言列表变短是不够的，
  /// 那看不出请求到底带没带游标。
  final List<String?> receivedCursors = [];

  @override
  Future<UserProfile> getMe() async {
    getMeCalls++;
    return profile;
  }

  @override
  Future<UserPreferences> updatePreferences(UserPreferences prefs) async {
    updatePreferencesCalls++;
    lastSubmitted = prefs;
    if (failNextUpdate != null) {
      final e = failNextUpdate!;
      failNextUpdate = null;
      throw e;
    }
    // 仿照后端的两条规整：去重，且回显**服务端规整后**的值。
    // 前端若拿入参当真，这里就会暴露出来。
    final saved = UserPreferences(
      dietMode: prefs.dietMode,
      crowds: _dedupe(prefs.crowds),
      avoidFoods: _dedupe(prefs.avoidFoods),
    );
    profile = profile.copyWith(preferences: saved);
    return saved;
  }

  @override
  Future<PreferenceOptions> getOptions() async => options;

  @override
  Future<RecipePage> recommend({int limit = 20, String? cursor}) async {
    recommendCalls++;
    receivedCursors.add(cursor);
    if (failNextRecommend != null) {
      final e = failNextRecommend!;
      failNextRecommend = null;
      throw e;
    }

    final prefs = profile.preferences;
    final ranked = recipes.where((r) => _keep(r, prefs)).toList()
      ..sort((a, b) {
        // 契约的排序键：(匹配人群数 DESC, id ASC)
        final byScore = _score(b, prefs).compareTo(_score(a, prefs));
        return byScore != 0 ? byScore : a.id.compareTo(b.id);
      });

    // 游标用偏移量，对调用方同样是不透明的
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
    if (start >= ranked.length) return const RecipePage(items: [], nextCursor: null);
    final end = (start + limit).clamp(0, ranked.length);

    return RecipePage(
      items: ranked.sublist(start, end),
      nextCursor: end < ranked.length ? '$end' : null,
    );
  }

  bool _keep(Recipe r, UserPreferences prefs) {
    if (prefs.dietMode == 'vegetarian' && !r.isVegetarian) return false;
    for (final avoid in prefs.avoidFoods) {
      if (r.avoidTags.contains(avoid)) return false;
    }
    return true;
  }

  int _score(Recipe r, UserPreferences prefs) =>
      prefs.crowds.where(r.crowds.contains).length;

  static List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    return [
      for (final v in values)
        if (seen.add(v)) v,
    ];
  }

  // --- 默认数据：对齐 0002_seed.sql 的取值 ---

  static const UserProfile defaultProfile = UserProfile(
    id: 'u_1',
    nickname: '美食家',
    avatarText: '美',
    timezone: 'Asia/Shanghai',
    preferences: UserPreferences(),
  );

  static const PreferenceOptions defaultOptions = PreferenceOptions(
    dietModes: [
      PreferenceOption(code: 'normal', label: '正常人'),
      PreferenceOption(code: 'vegetarian', label: '素食主义'),
    ],
    crowds: [
      PreferenceOption(code: 'pregnant', label: '孕妇'),
      PreferenceOption(code: 'student', label: '学生'),
      PreferenceOption(code: 'fitness', label: '健身人群'),
      PreferenceOption(code: 'elderly', label: '老人'),
      PreferenceOption(code: 'athlete', label: '运动员'),
    ],
    avoidFoods: [
      PreferenceOption(code: 'pork', label: '猪肉'),
      PreferenceOption(code: 'beef', label: '牛肉'),
      PreferenceOption(code: 'seafood', label: '海鲜'),
      PreferenceOption(code: 'cilantro', label: '香菜'),
      PreferenceOption(code: 'spicy', label: '辛辣'),
    ],
  );

  /// 4 条，覆盖「素食/荤菜」与「忌口」两组判定所需的组合。
  static const List<Recipe> defaultRecipes = [
    Recipe(
      id: 'r_01',
      name: '番茄炒蛋',
      emoji: '🍲',
      cookTimeMinutes: 10,
      isVegetarian: true,
      crowds: ['pregnant', 'student'],
      calories: 180,
      nutrition: Nutrition(carbsPercent: 50, proteinPercent: 25, fatPercent: 25),
    ),
    Recipe(
      id: 'r_02',
      name: '红烧肉',
      emoji: '🥩',
      cookTimeMinutes: 45,
      isVegetarian: false,
      avoidTags: ['pork'],
      calories: 450,
      nutrition: Nutrition(carbsPercent: 20, proteinPercent: 20, fatPercent: 60),
    ),
    Recipe(
      id: 'r_04',
      name: '清蒸鲈鱼',
      emoji: '🐟',
      cookTimeMinutes: 20,
      isVegetarian: false,
      avoidTags: ['seafood'],
      calories: 200,
      nutrition: Nutrition(carbsPercent: 10, proteinPercent: 60, fatPercent: 30),
    ),
    Recipe(
      id: 'r_06',
      name: '白灼西兰花',
      emoji: '🥦',
      cookTimeMinutes: 8,
      isVegetarian: true,
      crowds: ['fitness', 'elderly'],
      calories: 80,
      nutrition: Nutrition(carbsPercent: 60, proteinPercent: 30, fatPercent: 10),
    ),
  ];
}
