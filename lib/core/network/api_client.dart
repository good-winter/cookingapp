// lib/core/network/api_client.dart

import 'package:dio/dio.dart';

import '../../features/cooking/models/recipe_page.dart';
import '../../models/preference_options.dart';
import '../../models/user_preferences.dart';
import '../../models/user_profile.dart';
import 'api_exception.dart';
import 'cooking_api.dart';

/// [CookingApi] 的真实实现，基于 dio。
///
/// Base URL 与 token 都从编译期常量读（`--dart-define`），token 不落盘 ——
/// 这是契约「开发期 token 注入」一节的明确要求。
///
/// 构造参数全部可注入（dio / baseUrl / token / debugToken），测试因此可以塞一个
/// 假 adapter 进来，不必真的联网。
class ApiClient implements CookingApi {
  ApiClient({Dio? dio, String? baseUrl, String? token, String? debugToken})
      : _dio = dio ?? Dio(),
        baseUrl = baseUrl ?? defaultBaseUrl,
        token = token ?? defaultToken,
        debugToken = debugToken ?? defaultDebugToken {
    _dio.options = BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
      sendTimeout: requestTimeout,
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 契约：除健康检查外所有接口都要 Bearer token。
          // 注意必须写 ${this.token}：`$this.token` 会被解析成「$this 的值」+ 字面量
          // 「.token」，发出去就是 Bearer Instance of 'ApiClient'.token，后端一律判无效。
          options.headers['Authorization'] = 'Bearer ${this.token}';
          // 开发期切用户用。后端的语义是「覆盖 Authorization」，所以两个头同时
          // 带上时以调试头为准 —— 这正是设置页能免重编译切用户的原因。
          if (this.debugToken.isNotEmpty) {
            options.headers['X-Debug-Token'] = this.debugToken;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  final String baseUrl;
  final String token;
  final String debugToken;

  /// 用 `--dart-define=API_BASE_URL=...` 覆盖。
  ///
  /// 默认指向本机 8080 —— 注意 Flutter web 与后端不同源，后端必须开 CORS，
  /// 否则浏览器会在客户端拦掉响应（且报错只提 CORS）。
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/api/v1',
  );

  /// 用 `--dart-define=API_TOKEN=dev-token-user-2` 切换测试用户。
  static const String defaultToken = String.fromEnvironment(
    'API_TOKEN',
    defaultValue: 'dev-token-user-1',
  );

  /// 用 `--dart-define=API_DEBUG_TOKEN=...` 指定运行时要切换成的用户。
  /// 留空则不带该请求头。
  static const String defaultDebugToken =
      String.fromEnvironment('API_DEBUG_TOKEN');

  /// 契约：全局 10 秒超时。
  static const Duration requestTimeout = Duration(seconds: 10);

  @override
  Future<UserProfile> getMe() async {
    return UserProfile.fromJson(_asMap(await _send(() => _dio.get<dynamic>('/me'))));
  }

  @override
  Future<UserPreferences> updatePreferences(UserPreferences prefs) async {
    final data = await _send(
      () => _dio.put<dynamic>('/me/preferences', data: prefs.toJson()),
    );
    return UserPreferences.fromJson(_asMap(data));
  }

  @override
  Future<PreferenceOptions> getOptions() async {
    return PreferenceOptions.fromJson(
      _asMap(await _send(() => _dio.get<dynamic>('/preferences/options'))),
    );
  }

  @override
  Future<RecipePage> recommend({int limit = 20, String? cursor}) async {
    final data = await _send(
      () => _dio.get<dynamic>(
        '/recipes/recommend',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      ),
    );
    return RecipePage.fromJson(_asMap(data));
  }

  /// 统一的发送口：把 dio 的异常翻译成 [ApiException]。
  ///
  /// 放在这一个地方做，界面层就永远不必 import dio，也不必认识 DioExceptionType。
  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      return res.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// 把 `{ error: { code, message, details } }` 解成 [ApiException]。
  /// 拿不到这个信封，说明请求没到达服务端（或中间有代理插了一脚）。
  static ApiException _toApiException(DioException e) {
    final response = e.response;
    final data = response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        return ApiException(
          code: error['code']?.toString() ?? ApiException.networkErrorCode,
          message: error['message']?.toString() ?? '请求失败',
          statusCode: response?.statusCode,
          details:
              (error['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
      }
    }
    return ApiException(
      code: ApiException.networkErrorCode,
      message: _transportMessage(e),
      statusCode: response?.statusCode,
    );
  }

  /// 传输层失败的文案。契约规定 message 由服务端下发，但这类失败压根没有响应，
  /// 只能前端自己写 —— 而且要把「后端没起来」和「网络不好」区分开，否则联调时
  /// 看不出来该去启动后端。
  static String _transportMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '请求超时，请检查网络后重试',
      DioExceptionType.connectionError =>
        '连不上后端服务（$defaultBaseUrl），请确认它已启动',
      _ => '网络请求失败，请稍后重试',
    };
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    // 成功响应本应是一个对象。拿到别的东西通常意味着中间有代理返回了 HTML
    // 错误页；与其静默地造一个空模型让界面显示空白，不如明确报错。
    throw const ApiException(
      code: ApiException.networkErrorCode,
      message: '服务端返回了非预期的响应格式',
    );
  }
}
