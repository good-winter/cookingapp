// lib/core/network/api_exception.dart

/// 后端契约定义的错误信封：`{ "error": { "code", "message", "details" } }`
/// （docs/API_CONTRACT.md「错误格式」一节）。
///
/// 单独建一个类型、而不是让界面层去解 `DioException`，是为了让「按错误码分支」
/// 这件事有唯一的落点 —— 例如拿到 `INVALID_PARAMETER` 时该丢弃游标重拉、
/// 拿到 `UNAUTHORIZED` 时该提示重新登录。否则这类判断会散落成各处的字符串匹配。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  /// 契约里的机器可读枚举，如 `INVALID_PARAMETER` / `UNAUTHORIZED`。
  final String code;

  /// 契约规定 `message` 就是「可直接展示给用户的中文文案」，界面可直接用。
  final String message;

  final int? statusCode;

  /// 契约里的补充信息，无内容时是空对象。
  final Map<String, dynamic> details;

  /// 「请求压根没到达服务端」时用的兜底码（连不上、超时、DNS 失败）。
  ///
  /// 刻意**不放进**契约的 `error.code` 集合：那集合描述的是服务端的判断结果，
  /// 而这是传输层失败。两者要分开，界面才能给出不同的提示 ——
  /// 「服务端说你参数不对」和「你连不上服务端」该让用户做的事完全不同。
  static const String networkErrorCode = 'NETWORK_ERROR';

  /// 契约接口 2/4：偏好变更后携带过期游标会返回它，前端应丢弃游标从头请求。
  static const String invalidParameterCode = 'INVALID_PARAMETER';

  static const String unauthorizedCode = 'UNAUTHORIZED';

  /// 参数不合法。用在游标上时，正确反应是丢弃游标重新拉第一页。
  bool get isInvalidParameter => code == invalidParameterCode;

  bool get isUnauthorized => code == unauthorizedCode;

  /// 传输层失败（没拿到服务端的响应）。
  bool get isNetworkError => code == networkErrorCode;

  @override
  String toString() => 'ApiException($code, $message)';
}
