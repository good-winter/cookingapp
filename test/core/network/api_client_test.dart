// test/core/network/api_client_test.dart

import 'dart:typed_data';

import 'package:cooking_app/core/network/api_client.dart';
import 'package:cooking_app/core/network/api_exception.dart';
import 'package:cooking_app/models/user_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假的 dio 传输层。替换掉 adapter 而不是 adapter 之上的东西，是为了让测试
/// 真的经过拦截器与响应解析 —— 那才是 [ApiClient] 里唯一有逻辑的部分。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode = 200, this.body = '{}', this.throwConnectionError = false});

  final int statusCode;
  final String body;
  final bool throwConnectionError;

  /// 记录收到的请求，供断言请求头与查询参数。
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (throwConnectionError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'connection refused',
      );
    }
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWith(_FakeAdapter adapter, {String? debugToken}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    baseUrl: 'http://127.0.0.1:8080/api/v1',
    token: 'test-token',
    debugToken: debugToken ?? '',
  );
}

void main() {
  group('请求头注入', () {
    test('每个请求都带 Bearer token，未配调试头时不带 X-Debug-Token', () async {
      final adapter = _FakeAdapter(body: '{"id":"u_1"}');
      await _clientWith(adapter).getMe();

      final headers = adapter.requests.single.headers;
      expect(headers['Authorization'], 'Bearer test-token');
      expect(headers.containsKey('X-Debug-Token'), isFalse);
    });

    // 后端的语义是「X-Debug-Token 覆盖 Authorization」，所以两个头同时带上时
    // 以调试头为准 —— 这是设置页能免重编译切用户的前提。
    test('配了调试头时两个头都带上', () async {
      final adapter = _FakeAdapter(body: '{"id":"u_1"}');
      await _clientWith(adapter, debugToken: 'dev-token-user-2').getMe();

      final headers = adapter.requests.single.headers;
      expect(headers['Authorization'], 'Bearer test-token');
      expect(headers['X-Debug-Token'], 'dev-token-user-2');
    });
  });

  group('成功响应的解析', () {
    test('getMe 解出用户与偏好', () async {
      final adapter = _FakeAdapter(body: '''
        {"id":"u_1","nickname":"美食家","avatarText":"美","timezone":"Asia/Shanghai",
         "preferences":{"dietMode":"vegetarian","crowds":["pregnant"],"avoidFoods":["pork"]}}
      ''');
      final me = await _clientWith(adapter).getMe();

      expect(me.nickname, '美食家');
      expect(me.timezone, 'Asia/Shanghai');
      expect(me.preferences.dietMode, 'vegetarian');
      expect(me.preferences.crowds, ['pregnant']);
      expect(me.preferences.avoidFoods, ['pork']);
    });

    test('updatePreferences 发出完整的 JSON 请求体', () async {
      final adapter = _FakeAdapter(
        body: '{"dietMode":"vegetarian","crowds":[],"avoidFoods":[]}',
      );
      final saved = await _clientWith(adapter).updatePreferences(
        const UserPreferences(dietMode: 'vegetarian', crowds: ['pregnant']),
      );

      final req = adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/me/preferences');
      final body = req.data as Map<String, dynamic>;
      expect(body['dietMode'], 'vegetarian');
      expect(body['crowds'], ['pregnant']);
      expect(body['avoidFoods'], isEmpty);
      // 回显以服务端为准
      expect(saved.dietMode, 'vegetarian');
    });

    test('recommend 带上 limit 与 cursor，并解出分页结构', () async {
      final adapter = _FakeAdapter(body: '''
        {"items":[{"id":"r_01","name":"番茄炒蛋","emoji":"🍲","cookTimeMinutes":10,
                   "isVegetarian":true,"crowds":["pregnant"],"avoidTags":[],
                   "calories":180,
                   "nutrition":{"carbsPercent":50,"proteinPercent":25,"fatPercent":25}}],
         "nextCursor":"abc"}
      ''');
      final page = await _clientWith(adapter).recommend(limit: 6, cursor: 'xyz');

      final q = adapter.requests.single.queryParameters;
      expect(q['limit'], 6);
      expect(q['cursor'], 'xyz');
      expect(page.items.single.name, '番茄炒蛋');
      expect(page.items.single.cookTimeText, '10分钟');
      expect(page.nextCursor, 'abc');
      expect(page.hasMore, isTrue);
    });

    test('第一页不带 cursor 参数', () async {
      final adapter = _FakeAdapter(body: '{"items":[],"nextCursor":null}');
      final page = await _clientWith(adapter).recommend(limit: 6);

      expect(adapter.requests.single.queryParameters.containsKey('cursor'), isFalse);
      expect(page.hasMore, isFalse);
    });

    test('imageUrl 为 null 时保持 null，不变成空串', () async {
      final adapter = _FakeAdapter(body: '''
        {"items":[{"id":"r_01","name":"番茄炒蛋","emoji":"🍲","imageUrl":null,
                   "cookTimeMinutes":10,"isVegetarian":true,"crowds":[],"avoidTags":[],
                   "calories":180,"nutrition":{}}],"nextCursor":null}
      ''');
      final page = await _clientWith(adapter).recommend();

      expect(page.items.single.imageUrl, isNull);
    });
  });

  group('错误信封的解析', () {
    test('契约的错误结构解成 ApiException', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        body: '''
          {"error":{"code":"INVALID_PARAMETER",
                    "message":"游标已失效（偏好已变更），请丢弃后重新请求",
                    "details":{"limit":"0"}}}
        ''',
      );

      await expectLater(
        () => _clientWith(adapter).recommend(cursor: 'stale'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'INVALID_PARAMETER')
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.details['limit'], 'details', '0')
              .having((e) => e.isInvalidParameter, 'isInvalidParameter', isTrue),
        ),
      );
    });

    test('401 解成 UNAUTHORIZED', () async {
      final adapter = _FakeAdapter(
        statusCode: 401,
        body: '{"error":{"code":"UNAUTHORIZED","message":"访问令牌无效","details":{}}}',
      );

      await expectLater(
        () => _clientWith(adapter).getMe(),
        throwsA(isA<ApiException>()
            .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
      );
    });

    // 连不上后端时没有响应，也就没有契约里的 message —— 这类提示是前端自己写的，
    // 必须能区分「后端没启动」和「网络不好」，否则联调时看不出来该做什么。
    test('连不上后端时报 NETWORK_ERROR 且文案点明后端地址', () async {
      final adapter = _FakeAdapter(throwConnectionError: true);

      await expectLater(
        () => _clientWith(adapter).getMe(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiException.networkErrorCode)
              .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
              .having((e) => e.message, 'message', contains('127.0.0.1:8080')),
        ),
      );
    });

    // 成功响应本应是对象；拿到 HTML 之类说明中间有代理插了一脚，
    // 这时明确报错好过静默造一个空模型让界面显示空白。
    test('成功响应不是对象时报错而不是返回空模型', () async {
      final adapter = _FakeAdapter(body: '"<html>proxy error</html>"');

      await expectLater(
        () => _clientWith(adapter).getMe(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
