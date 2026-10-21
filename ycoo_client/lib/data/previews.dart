/// 列表卡片的首图与摘要。
///
/// 版块列表 / 导读页的 HTML 里只有头像，没有首图和摘要；
/// 但站点开放了 Discuz 移动端接口 `api/mobile/index.php`，
/// 其中 `module=forumdisplay` 会带回 `attachmentImagePreviewList`
/// 和 `message`（正文预览），一次请求即可覆盖整页帖子，
/// 比逐帖抓详情页轻得多。
///
/// 这里只做纯解析，便于用真实 JSON 离线回归。
library;

import 'dart:convert';

import 'parsers.dart' show kBaseUrl;

class ThreadPreview {
  /// 首图地址（站内附件或外链）
  final String? image;

  /// 正文摘要（已去标签 / BBCode）
  final String? excerpt;

  /// 图片数量，用于「N 图」角标
  final int imageCount;

  /// 点赞数
  final int likes;

  const ThreadPreview({this.image, this.excerpt, this.imageCount = 0, this.likes = 0});

  bool get hasImage => image != null && image!.isNotEmpty;
  bool get hasExcerpt => excerpt != null && excerpt!.isNotEmpty;
  bool get isEmpty => !hasImage && !hasExcerpt && likes == 0;
}

/// 解析 `module=forumdisplay` 的 JSON → tid 映射。
///
/// 接口不可用（关闭、改版、返回 HTML）时返回空 Map，调用方按「无预览」降级。
Map<int, ThreadPreview> parseForumDisplayPreviews(String body) {
  final out = <int, ThreadPreview>{};
  if (body.isEmpty) return out;

  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return out;
  }
  if (decoded is! Map) return out;
  final vars = decoded['Variables'];
  if (vars is! Map) return out;
  final list = vars['forum_threadlist'];
  if (list is! List) return out;

  for (final raw in list) {
    if (raw is! Map) continue;
    final tid = _int(raw['tid']);
    if (tid == 0) continue;

    String? image;
    var count = 0;
    final previews = raw['attachmentImagePreviewList'];
    if (previews is List) {
      count = previews.length;
      for (final p in previews) {
        if (p is! Map) continue;
        final url = attachmentUrl(p['attachment']?.toString(), remote: _int(p['remote']) == 1);
        if (url != null) {
          image = url;
          break;
        }
      }
    }
    final imageNumber = _int(raw['attachmentImageNumber']);
    if (imageNumber > count) count = imageNumber;

    out[tid] = ThreadPreview(
      image: image,
      excerpt: previewText(raw['message']?.toString()),
      imageCount: count,
      likes: _int(raw['recommend_add']),
    );
  }
  return out;
}

/// 附件相对路径 → 可访问地址。
String? attachmentUrl(String? path, {bool remote = false}) {
  if (path == null) return null;
  final p = path.trim();
  if (p.isEmpty) return null;
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  if (remote) return p.startsWith('//') ? 'https:$p' : 'https://$p';
  return '$kBaseUrl/data/attachment/forum/${p.replaceFirst(RegExp(r'^/+'), '')}';
}

/// 正文预览 → 一行摘要。
String? previewText(String? html, {int maxLen = 110}) {
  if (html == null || html.isEmpty) return null;
  var t = html;
  t = t.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
  // BBCode 与附件占位
  t = t.replaceAll(RegExp(r'\[(?:attach|attachment|图片附件)[^\]]*\]', caseSensitive: false), ' ');
  t = t.replaceAll(
    RegExp(r'\[/?(?:b|i|u|s|color|size|font|align|quote|url|img|list|table|tr|td|\*|free|hide|code)[^\]]*\]',
        caseSensitive: false),
    ' ',
  );
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'&#\d+;'), ' ');
  // 「本帖最后由 xxx 于 ... 编辑」这类页脚
  t = t.replaceAll(RegExp(r'本帖最后由[\s\S]{0,60}?编辑'), ' ');
  // URL 紧贴中文时补一个空格，避免摘要读起来黏连
  t = t.replaceAllMapped(
    RegExp(r'(https?://[^\s\u4e00-\u9fa5]+)([\u4e00-\u9fa5])'),
    (m) => '${m[1]} ${m[2]}',
  );
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  if (t.length <= maxLen) return t;
  return '${t.substring(0, maxLen)}…';
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}
