/// 自动化领域模型：自动回复预设与执行日志。
library;

/// 一条自动回复预设。
class Preset {
  const Preset({required this.text});

  /// 预设正文。支持占位符 `{author}` / `{title}`。
  final String text;

  static const int maxCount = 5;
  static const int maxLength = 200;

  bool get isValid => text.trim().isNotEmpty && text.trim().length <= maxLength;

  Map<String, dynamic> toJson() => <String, dynamic>{'text': text};

  factory Preset.fromJson(Map<String, dynamic> j) =>
      Preset(text: (j['text'] as String?) ?? '');
}

/// 自动回复执行记录。
class AutoReplyLog {
  const AutoReplyLog({
    required this.tid,
    required this.siteId,
    required this.sentText,
    required this.success,
    required this.at,
    this.error,
  });

  final int tid;
  final String siteId;
  final String sentText;
  final bool success;
  final DateTime at;
  final String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tid': tid,
        'siteId': siteId,
        'sentText': sentText,
        'success': success,
        'at': at.toIso8601String(),
        'error': error,
      };

  factory AutoReplyLog.fromJson(Map<String, dynamic> j) => AutoReplyLog(
        tid: (j['tid'] as num?)?.toInt() ?? 0,
        siteId: (j['siteId'] as String?) ?? '',
        sentText: (j['sentText'] as String?) ?? '',
        success: j['success'] as bool? ?? false,
        at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
        error: j['error'] as String?,
      );
}

/// 签到执行记录。
class CheckinLog {
  const CheckinLog({
    required this.at,
    required this.success,
    this.message,
  });

  final DateTime at;
  final bool success;
  final String? message;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'at': at.toIso8601String(),
        'success': success,
        'message': message,
      };

  factory CheckinLog.fromJson(Map<String, dynamic> j) => CheckinLog(
        at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
        success: j['success'] as bool? ?? false,
        message: j['message'] as String?,
      );
}
