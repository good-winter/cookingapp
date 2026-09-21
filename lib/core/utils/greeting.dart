// lib/core/utils/greeting.dart

/// 根据小时数（0-23）返回问候语。
///
/// 抽成纯函数是为了方便单元测试 —— UI 层只需要把 `DateTime.now().hour`
/// 传进来即可，不需要为了测试去 mock 系统时间。
///
/// 边界划分：[5, 12) 早上 / [12, 18) 中午 / 其余（含凌晨 0-4 点）晚上。
String greetingForHour(int hour) {
  if (hour >= 5 && hour < 12) return '早上好';
  if (hour >= 12 && hour < 18) return '中午好';
  return '晚上好';
}
