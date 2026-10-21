/// 统一错误类型与文案。
///
/// 网络层抛出 `AppException`，UI 直接展示 `displayMessage`，
/// 避免把 `SocketException` 之类的原始文本丢给用户。
library;

/// 错误分类。
enum AppErrorKind {
  /// 网络不可达 / DNS / 连接被拒。
  network,

  /// 超时。
  timeout,

  /// 登录失效（需重新登录）。
  unauthorized,

  /// 无权限（私密版块、付费内容）。
  forbidden,

  /// 星币余额不足。
  credits,

  /// 资源不存在（帖子被删）。
  notFound,

  /// 页面解析失败（站点模板变更）。
  parse,

  /// 存储写入失败（附件下载）。
  storage,

  /// 权限未授予（存储 / 通知）。
  permission,

  /// 用户取消。
  cancelled,

  /// 服务端 5xx。
  server,

  /// 其它。
  unknown,
}

/// 应用级异常。
class AppException implements Exception {
  const AppException(
    this.kind, {
    this.message,
    this.statusCode,
    this.cause,
  });

  final AppErrorKind kind;
  final String? message;
  final int? statusCode;
  final Object? cause;

  /// 是否值得重试。
  bool get retryable =>
      kind == AppErrorKind.network ||
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.server;

  /// 面向用户的中文提示（超长截断）。
  String get displayMessage {
    final String base = switch (kind) {
      AppErrorKind.network => '网络连接失败，请检查网络后重试',
      AppErrorKind.timeout => '请求超时，请稍后重试',
      AppErrorKind.unauthorized => '登录状态已失效，请重新登录',
      AppErrorKind.forbidden => '没有访问该内容的权限',
      AppErrorKind.credits => '星币不足，无法完成该操作',
      AppErrorKind.notFound => '内容不存在或已被删除',
      AppErrorKind.parse => '页面解析失败，站点模板可能已更新',
      AppErrorKind.storage => '文件保存失败，请检查存储空间与权限',
      AppErrorKind.permission => '缺少所需权限，请在系统设置中授权',
      AppErrorKind.cancelled => '操作已取消',
      AppErrorKind.server => '站点服务异常，请稍后重试',
      AppErrorKind.unknown => '发生未知错误',
    };
    final String? detail = message;
    if (detail == null || detail.trim().isEmpty) return base;
    final String trimmed = detail.trim();
    final String clipped =
        trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed;
    return '$base（$clipped）';
  }

  // ------------------------------------------------------------ 工厂

  factory AppException.network({String? message, Object? cause}) =>
      AppException(AppErrorKind.network, message: message, cause: cause);

  factory AppException.timeout({String? message}) =>
      AppException(AppErrorKind.timeout, message: message);

  factory AppException.unauthorized({String? message}) =>
      AppException(AppErrorKind.unauthorized, message: message);

  factory AppException.forbidden({String? message}) =>
      AppException(AppErrorKind.forbidden, message: message);

  factory AppException.credits({String? message}) =>
      AppException(AppErrorKind.credits, message: message);

  factory AppException.notFound({String? message}) =>
      AppException(AppErrorKind.notFound, message: message);

  factory AppException.parse({String? message, Object? cause}) =>
      AppException(AppErrorKind.parse, message: message, cause: cause);

  factory AppException.storage({String? message, Object? cause}) =>
      AppException(AppErrorKind.storage, message: message, cause: cause);

  factory AppException.permission({String? message}) =>
      AppException(AppErrorKind.permission, message: message);

  factory AppException.server({int? statusCode, String? message}) =>
      AppException(AppErrorKind.server,
          statusCode: statusCode, message: message);

  /// 从任意错误对象归类。
  factory AppException.from(Object error, {StackTrace? stackTrace}) {
    if (error is AppException) return error;
    final String text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('网络')) {
      return AppException(AppErrorKind.network, message: text, cause: error);
    }
    if (text.contains('TimeoutException') || text.contains('timed out')) {
      return AppException(AppErrorKind.timeout, message: text, cause: error);
    }
    return AppException(AppErrorKind.unknown, message: text, cause: error);
  }

  @override
  String toString() => 'AppException($kind, $statusCode, $message)';
}
