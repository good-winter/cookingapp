// lib/models/app_settings.dart
import 'package:flutter/material.dart';

/// App 自身的本地设置。
///
/// 与 `UserPreferences`（饮食偏好）的区别很重要：
/// 那份按接口契约属于**服务端**数据（见 docs/API_CONTRACT.md 决策 #2），
/// 这里全部是**只存在本机**的 App 设置，生命周期完全不同，不要混在一起。
class AppSettings {
  /// 白天 / 晚上。需求明确不要「跟随系统」，所以只有 light / dark 两种。
  final ThemeMode themeMode;

  /// 界面语言，只支持简体中文与英语
  final Locale locale;

  /// 个性签名，显示在设置页的用户信息卡里。空串表示还没设置。
  final String signature;

  /// 语音播报开关
  final bool ttsEnabled;

  /// 语速，对应 flutter_tts 的 speech rate（0.0 ~ 1.0，0.5 为正常语速）
  final double ttsSpeechRate;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('zh'),
    this.signature = '',
    this.ttsEnabled = true,
    this.ttsSpeechRate = defaultSpeechRate,
  });

  static const double defaultSpeechRate = 0.5;

  /// 支持的语言。加语言时改这里 + lib/l10n 下加 arb 文件。
  static const List<Locale> supportedLocales = [Locale('zh'), Locale('en')];

  static const double _minSpeechRate = 0.0;
  static const double _maxSpeechRate = 1.0;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? signature,
    bool? ttsEnabled,
    double? ttsSpeechRate,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      signature: signature ?? this.signature,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
    );
  }

  /// 序列化，用于本地持久化 —— 见 core/storage/settings_storage.dart
  Map<String, dynamic> toJson() => {
        'themeMode': themeMode == ThemeMode.dark ? 'dark' : 'light',
        'locale': locale.languageCode,
        'signature': signature,
        'ttsEnabled': ttsEnabled,
        'ttsSpeechRate': ttsSpeechRate,
      };

  /// 从本地存储还原。
  /// 字段缺失或类型不对时退回默认值，避免旧数据让 App 启动即崩。
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: json['themeMode'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      locale: _locale(json['locale']),
      signature: json['signature'] is String ? json['signature'] as String : '',
      ttsEnabled: json['ttsEnabled'] is bool ? json['ttsEnabled'] as bool : true,
      ttsSpeechRate: _speechRate(json['ttsSpeechRate']),
    );
  }

  /// 不认识的语言码一律退回中文
  static Locale _locale(Object? value) {
    if (value is String) {
      for (final locale in supportedLocales) {
        if (locale.languageCode == value) return locale;
      }
    }
    return supportedLocales.first;
  }

  /// 语速钳制在合法区间，防止脏数据把 TTS 设成负数或超速
  static double _speechRate(Object? value) {
    if (value is num) {
      final rate = value.toDouble();
      if (rate >= _minSpeechRate && rate <= _maxSpeechRate) return rate;
    }
    return defaultSpeechRate;
  }
}
