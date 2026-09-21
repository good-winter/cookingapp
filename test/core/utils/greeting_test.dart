import 'package:cooking_app/core/utils/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayPartForHour', () {
    test('5:00 - 11:59 是早上', () {
      expect(dayPartForHour(5), DayPart.morning); // 下边界
      expect(dayPartForHour(8), DayPart.morning);
      expect(dayPartForHour(11), DayPart.morning); // 上边界
    });

    test('12:00 - 17:59 是中午', () {
      expect(dayPartForHour(12), DayPart.noon); // 下边界
      expect(dayPartForHour(15), DayPart.noon);
      expect(dayPartForHour(17), DayPart.noon); // 上边界
    });

    test('18:00 - 次日 4:59 是晚上', () {
      expect(dayPartForHour(18), DayPart.evening); // 下边界
      expect(dayPartForHour(23), DayPart.evening);
      expect(dayPartForHour(0), DayPart.evening); // 跨天，凌晨也算晚上
      expect(dayPartForHour(4), DayPart.evening); // 上边界
    });
  });
}
