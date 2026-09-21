// lib/core/utils/greeting.dart

/// 一天中的时段，用来决定问候语。
enum DayPart { morning, noon, evening }

/// 根据小时数（0-23）判断时段。
///
/// 返回枚举而不是中文字符串，有两个原因：
///  1. 文案要跟随界面语言变化（映射在 lib/l10n/enum_labels.dart），
///     而判断逻辑与语言无关 —— 两者不该耦合在一起。
///  2. 纯函数便于单测，不需要为了测试去 mock 系统时间或语言环境。
///
/// 边界划分：[5, 12) 早上 / [12, 18) 中午 / 其余（含凌晨 0-4 点）晚上。
DayPart dayPartForHour(int hour) {
  if (hour >= 5 && hour < 12) return DayPart.morning;
  if (hour >= 12 && hour < 18) return DayPart.noon;
  return DayPart.evening;
}
