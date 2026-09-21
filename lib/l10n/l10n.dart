// lib/l10n/l10n.dart
import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// 让调用点写成 `context.l10n.settingsTitle`。
///
/// 生成的 `AppLocalizations.of()` 返回可空类型，但 `MaterialApp` 已经注册了
/// delegate，实际永远是拿得到的 —— 用扩展把 `!` 收在一处，避免满屏感叹号。
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
