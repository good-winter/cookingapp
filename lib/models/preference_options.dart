// lib/models/preference_options.dart

/// 字典里的一项。契约里形如 `{ "code": "pregnant", "label": "孕妇" }`。
class PreferenceOption {
  const PreferenceOption({required this.code, required this.label});

  /// 英文码。提交给服务端，也是本地比较用的值。
  final String code;

  /// 服务端下发的展示文案。
  ///
  /// 界面**优先**用本地 l10n 映射（要跟随语言切换），映射不到时才回退到它 ——
  /// 这样后端加了新选项，前端即使在 l10n 里还没加对应文案，也能显示中文而不是
  /// 露出英文码。
  final String label;

  factory PreferenceOption.fromJson(Map<String, dynamic> json) {
    return PreferenceOption(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

/// `GET /preferences/options` 的响应：三组字典。
///
/// 契约要求「每次启动拉取一次，内存缓存，不落盘」。落盘缓存会让新增选项在
/// 客户端长期不出现，把「新增选项无需发版」这个卖点抵消掉 —— 所以这里由
/// Riverpod 的 provider 在内存里缓存，不做任何持久化。
class PreferenceOptions {
  const PreferenceOptions({
    this.dietModes = const [],
    this.crowds = const [],
    this.avoidFoods = const [],
  });

  final List<PreferenceOption> dietModes;
  final List<PreferenceOption> crowds;
  final List<PreferenceOption> avoidFoods;

  factory PreferenceOptions.fromJson(Map<String, dynamic> json) {
    return PreferenceOptions(
      dietModes: _options(json['dietModes']),
      crowds: _options(json['crowds']),
      avoidFoods: _options(json['avoidFoods']),
    );
  }

  static List<PreferenceOption> _options(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => PreferenceOption.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
