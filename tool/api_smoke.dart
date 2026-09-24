// tool/api_smoke.dart
//
// 联调自检：用**真实的** ApiClient 打**真实的**后端，验证网络层这一层真的能通。
//
// 这是个命令行脚本，输出到 stdout 就是它的用途，所以豁免 avoid_print。
//
// 为什么需要它：`flutter test` 走的是假 adapter，测的是解析与接线；而 dio -> Go 的
// 序列化细节（中文、emoji、查询参数、请求头）只有真打一次才知道。测试环境还会拦掉
// 真实 HTTP，所以这件事只能靠一个独立脚本做。
//
// 用法：
//   cd server && go run ./cmd/api          # 先起后端
//   dart run tool/api_smoke.dart           # 另开终端
//
// 它会临时改 u_1 的偏好，跑完恢复原状。
// ignore_for_file: avoid_print

import 'package:cooking_app/core/network/api_client.dart';
import 'package:cooking_app/core/network/api_exception.dart';
import 'package:cooking_app/models/user_preferences.dart';

final _api = ApiClient();
var _failures = 0;

void check(String label, bool ok, String detail) {
  print('${ok ? '  OK  ' : ' FAIL '} $label${detail.isEmpty ? '' : ' — $detail'}');
  if (!ok) _failures++;
}

Future<void> main() async {
  print('目标: ${ApiClient.defaultBaseUrl}   token: ${ApiClient.defaultToken}\n');

  // --- 1. GET /me ---
  final me = await _api.getMe();
  check('GET /me 解析出昵称', me.nickname.isNotEmpty, me.nickname);
  check('GET /me 时区非空', me.timezone.isNotEmpty, me.timezone);
  print('       原偏好: ${me.preferences.toJson()}\n');

  // --- 2. GET /preferences/options ---
  final options = await _api.getOptions();
  check('options 三组字典都非空',
      options.dietModes.isNotEmpty &&
          options.crowds.isNotEmpty &&
          options.avoidFoods.isNotEmpty,
      'dietModes=${options.dietModes.length} crowds=${options.crowds.length} '
          'avoidFoods=${options.avoidFoods.length}');
  final labels = options.crowds.map((o) => o.label).join('/');
  check('中文字典值未乱码', !labels.contains('�'), labels);
  print('');

  // --- 3. 第一页 + 游标 ---
  final page1 = await _api.recommend(limit: 6);
  check('recommend 第一页 6 条', page1.items.length == 6,
      '${page1.items.map((r) => r.id).toList()}');
  check('第一页带 nextCursor', page1.hasMore, '${page1.nextCursor}');
  final first = page1.items.first;
  check('菜谱中文字段未乱码', !first.name.contains('�'), first.name);
  check('emoji 未乱码', first.emoji.runes.length <= 2, first.emoji);
  check('cookTimeText 由数字格式化', first.cookTimeText.endsWith('分钟'),
      first.cookTimeText);
  print('');

  // --- 4. 用游标翻第二页 ---
  final page2 = await _api.recommend(limit: 6, cursor: page1.nextCursor);
  final ids1 = page1.items.map((r) => r.id).toSet();
  final ids2 = page2.items.map((r) => r.id).toSet();
  check('第二页与第一页不重叠', ids1.intersection(ids2).isEmpty,
      'page2=${page2.items.map((r) => r.id).toList()}');
  print('');

  // --- 5. 保存偏好 -> 推荐随之变化（本条要验的是契约的 save 语义）---
  final before = await _api.recommend(limit: 50);
  final saved = await _api.updatePreferences(
    const UserPreferences(dietMode: 'vegetarian', crowds: [], avoidFoods: []),
  );
  check('PUT 回显 dietMode', saved.dietMode == 'vegetarian', saved.dietMode);
  final afterVeg = await _api.recommend(limit: 50);
  check('素食模式仅返回素食菜谱',
      afterVeg.items.every((r) => r.isVegetarian),
      '${before.items.length} -> ${afterVeg.items.length} 条');
  print('');

  // --- 6. 重复值应被服务端去重（不是我这边去重）---
  final dup = await _api.updatePreferences(const UserPreferences(
    dietMode: 'normal',
    crowds: ['fitness', 'fitness', 'pregnant'],
    avoidFoods: ['pork', 'pork'],
  ));
  check('重复 crowds 被去重', dup.crowds.length == 2, '${dup.crowds}');
  check('重复 avoidFoods 被去重', dup.avoidFoods.length == 1, '${dup.avoidFoods}');
  print('');

  // --- 7. 过期游标必须被服务端拒绝，且错误信封能被解析 ---
  final p = await _api.recommend(limit: 3);
  final staleCursor = p.nextCursor!;
  await _api.updatePreferences(
    const UserPreferences(dietMode: 'normal', crowds: ['elderly'], avoidFoods: []),
  );
  try {
    await _api.recommend(limit: 3, cursor: staleCursor);
    check('过期游标被拒绝', false, '居然返回成功了');
  } on ApiException catch (e) {
    check('过期游标被拒绝且解析出错误码',
        e.isInvalidParameter && e.statusCode == 400,
        'code=${e.code} status=${e.statusCode} msg=${e.message}');
  }
  print('');

  // --- 8. 恢复现场 ---
  await _api.updatePreferences(me.preferences);
  final restored = await _api.getMe();
  check('偏好已恢复原状',
      restored.preferences.toJson().toString() ==
          me.preferences.toJson().toString(),
      '${restored.preferences.toJson()}');

  print('\n${_failures == 0 ? '全部通过' : '$_failures 项失败'}');
}
