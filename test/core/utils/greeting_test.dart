import 'package:cooking_app/core/utils/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('greetingForHour', () {
    test('5:00 - 11:59 返回「早上好」', () {
      expect(greetingForHour(5), '早上好'); // 下边界
      expect(greetingForHour(8), '早上好');
      expect(greetingForHour(11), '早上好'); // 上边界
    });

    test('12:00 - 17:59 返回「中午好」', () {
      expect(greetingForHour(12), '中午好'); // 下边界
      expect(greetingForHour(15), '中午好');
      expect(greetingForHour(17), '中午好'); // 上边界
    });

    test('18:00 - 次日 4:59 返回「晚上好」', () {
      expect(greetingForHour(18), '晚上好'); // 下边界
      expect(greetingForHour(23), '晚上好');
      expect(greetingForHour(0), '晚上好'); // 跨天，凌晨也算晚上
      expect(greetingForHour(4), '晚上好'); // 上边界
    });
  });
}
