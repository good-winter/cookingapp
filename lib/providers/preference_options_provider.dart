// lib/providers/preference_options_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/preference_options.dart';
import 'api_providers.dart';

/// 选项字典（`GET /preferences/options`）。
///
/// 用 FutureProvider 正好对上契约的缓存要求：「每次启动拉取一次，内存缓存，
/// 不落盘」。它天然就是进程内缓存一次、App 重启即重新拉取 —— 而落盘缓存会让
/// 新增选项在客户端长期不出现，把「新增选项无需发版」这个卖点抵消掉。
final preferenceOptionsProvider = FutureProvider<PreferenceOptions>(
  (ref) => ref.read(apiClientProvider).getOptions(),
);
