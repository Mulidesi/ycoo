/// Discuz! 帖子正文 → 结构化内容块。
///
/// 之前的实现按「块级标签 → 一段文字」的方式拍平，导致两类内容丢失：
///   1. 嵌在 div / p / td 里的图片（只处理顶层 img）；
///   2. 表格、列表、附件区、pre 里的结构信息被合并或吞掉。
/// 这里改成递归遍历：任何位置出现的文本和图片都会被保留，
/// 只有明确的噪声节点（script/style/隐藏提示）才丢弃。
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'parsers.dart' show absoluteUrl;

enum BlockKind {
  text,
  image,
  quote,
  code,
  divider,
  table,
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  video,
  iframe,
}

/// 一段带样式的行内文本。
class InlineRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? href;
  final int? color;
  final double? fontSize;

  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.href,
    this.color,
    this.fontSize,
  });
}

class ContentBlock {
  final BlockKind kind;
  final List<InlineRun> runs;
  final String? imageUrl;

  /// 代码块原文
  final String code;

  /// 表格数据
  final List<List<InlineRun>>? tableRows;

  /// 视频/iframe 链接
  final String? videoUrl;
  final String? iframeUrl;

  const ContentBlock._(this.kind, {
    this.runs = const [],
    this.imageUrl,
    this.code = '',
    this.tableRows,
    this.videoUrl,
    this.iframeUrl,
  });

  const ContentBlock.text(List<InlineRun> runs) : this._(BlockKind.text, runs: runs);
  const ContentBlock.quote(List<InlineRun> runs) : this._(BlockKind.quote, runs: runs);
  ContentBlock.image(String url) : this._(BlockKind.image, imageUrl: url);
  ContentBlock.codeBlock(String text) : this._(BlockKind.code, code: text);
  const ContentBlock.divider() : this._(BlockKind.divider);

  ContentBlock.table(List<List<InlineRun>> rows) : this._(BlockKind.table, tableRows: rows);

  const ContentBlock.h1(List<InlineRun> runs) : this._(BlockKind.h1, runs: runs);
  const ContentBlock.h2(List<InlineRun> runs) : this._(BlockKind.h2, runs: runs);
  const ContentBlock.h3(List<InlineRun> runs) : this._(BlockKind.h3, runs: runs);
  const ContentBlock.h4(List<InlineRun> runs) : this._(BlockKind.h4, runs: runs);
  const ContentBlock.h5(List<InlineRun> runs) : this._(BlockKind.h5, runs: runs);
  const ContentBlock.h6(List<InlineRun> runs) : this._(BlockKind.h6, runs: runs);

  ContentBlock.video(String url) : this._(BlockKind.video, videoUrl: url);
  ContentBlock.iframe(String url) : this._(BlockKind.iframe, iframeUrl: url);

  String get plainText {
    switch (kind) {
      case BlockKind.code:
        return code;
      case BlockKind.image:
        return '';
      case BlockKind.table:
        return tableRows?.map((r) => r.map((c) => c.text).join()).join('\n') ?? '';
      case BlockKind.video:
      case BlockKind.iframe:
        return videoUrl ?? iframeUrl ?? '';
      default:
        return runs.map((r) => r.text).join();
    }
  }
}

// 需要整体保留空白的标签
const _kSkipTags = {'script', 'style', 'noscript', 'template', 'link', 'meta'};

// 块级标签：前后需要断开段落
const _kBlockTags = {
  'div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li',
  'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', 'section', 'article',
  'center', 'fieldset', 'form', 'dl', 'dt', 'dd', 'figure', 'figcaption',
  'header', 'footer', 'main', 'aside', 'nav', 'address', 'details', 'summary',
  'blockquote', 'pre', 'hr', 'body',
};

// 模板自带的界面区块（引用楼层、评分、版权声明、操作按钮），不属于正文
const _kNoiseSelectors = [
  '#copyright',
  '.copyright',
  '.copyright-title',
  '.copyright-text',
  '.replyfloor_box',
  '.replyfloor_hd',
  '.replyfloor_bd',
  '.replyfloor_editor',
  '#comiis_allreplies',
  '.comiis_viewtitle',
  '#comiis_hfpx_menu',
  '#fj',
  '.comiis_dianping',
  '.cm',
  '.comiis_pingfen_va',
  '.po',
  '.pob',
  '#p_btn',
  '.comiis_p_btn',
  '#postlist',
];

class _Style {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? href;
  final int? color;
  final double? fontSize;

  const _Style({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.href,
    this.color,
    this.fontSize,
  });

  _Style copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    String? href,
    int? color,
    double? fontSize,
  }) {
    return _Style(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      href: href ?? this.href,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

const _kBase = _Style();

String _cleanText(String s) {
  return s
      .replaceAll('\u00a0', ' ')
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'[ \t\n]+'), ' ');
}

int? _parseColor(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    final n = int.tryParse(hex, radix: 16);
    return n == null ? null : (0xFF000000 | n);
  }
  const named = {
    'red': 0xFFE53935,
    'blue': 0xFF1E88E5,
    'green': 0xFF43A047,
    'orange': 0xFFFB8C00,
    'purple': 0xFF8E24AA,
    'gray': 0xFF757575,
    'grey': 0xFF757575,
    'black': 0xFF111111,
    'white': 0xFFFFFFFF,
    'darkred': 0xFFB71C1C,
    'darkblue': 0xFF0D47A1,
    'darkgreen': 0xFF1B5E20,
    'teal': 0xFF00897B,
    'brown': 0xFF6D4C41,
    'pink': 0xFFD81B60,
    'olive': 0xFF827717,
  };
  return named[v];
}

int? _colorFromStyle(String? style) {
  if (style == null) return null;
  final m = RegExp(r'(?<![-\w])color\s*:\s*([^;]+)').firstMatch(style);
  return m == null ? null : _parseColor(m.group(1));
}

double? _sizeFromStyle(String? style) {
  if (style == null) return null;
  final m = RegExp(r'font-size\s*:\s*(\d+(?:\.\d+)?)\s*px').firstMatch(style);
  if (m == null) return null;
  return double.parse(m.group(1)!).clamp(10, 30).toDouble();
}

/// 元素是否被站点用 `display:none` / `visibility:hidden` 藏起来。
///
/// Discuz 把附件的悬浮提示（`.tip`）、下拉菜单等留在正文 DOM 里靠样式隐藏，
/// 只按标签遍历会把「2 小时前 上传 / 点击文件名下载附件」这类文案当正文输出。
bool _isHidden(Element e) {
  final style = (e.attributes['style'] ?? '').replaceAll(' ', '').toLowerCase();
  if (style.contains('display:none') || style.contains('visibility:hidden')) return true;
  final cls = (e.attributes['class'] ?? '').toLowerCase();
  return cls == 'tip' || cls.startsWith('tip ') || cls.contains(' tip ');
}

/// 判断图片是否是可展示的正文图片（过滤占位图、表情、追踪像素）
String? _imageUrl(Element e) {
  final candidates = [
    e.attributes['zoomfile'],
    e.attributes['file'],
    e.attributes['data-original'],
    e.attributes['src'],
  ];
  for (final raw in candidates) {
    final src = (raw ?? '').trim();
    if (src.isEmpty || src.startsWith('data:')) continue;
    final lower = src.toLowerCase();
    // 占位图：真实地址在 file/zoomfile 里，前面已经试过
    if (lower.contains('none.gif') || lower.contains('attachimg.gif') || lower.contains('loading.gif')) {
      continue;
    }
    // 表情图片按文本处理没有意义，直接跳过（不影响正文文字）
    if (lower.contains('/static/image/smiley/') || lower.contains('/smiley/')) continue;
    // 附件文件类型小图标（json.gif / zip.gif / unknown.gif…）是 16px 行内图标，
    // 当成正文图片渲染会被拉成整屏的「问号」。附件由附件卡片负责展示。
    if (lower.contains('/static/image/filetype/')) continue;
    return absoluteUrl(src);
  }
  return null;
}

class _Builder {
  _Builder({this.keepLocked = false});

  final bool keepLocked;
  final List<ContentBlock> blocks = [];
  final List<InlineRun> _buf = [];

  void _add(InlineRun run) {
    if (run.text.isEmpty) return;
    _buf.add(run);
  }

  void _flush() {
    if (_buf.isEmpty) return;
    final runs = _linkify(_trimRuns(_buf));
    _buf.clear();
    if (runs.isNotEmpty) blocks.add(ContentBlock.text(runs));
  }

  /// 纯文本里的裸链接（网盘地址、短链）转成可点击 run。
  ///
  /// Discuz 只在部分场景把 URL 包成 `<a>`，很多帖子正文里的下载地址是纯文本，
  /// 之前渲染出来只是一串不可点的字。这里在成段文本落地前做一次识别。
  static final RegExp _urlRe = RegExp(
    r'''(?:https?://|www\.)[^\s<>"“”‘’\u3000，。；：！？、（）【】《》]+''',
    caseSensitive: false,
  );

  static final RegExp _trailingPunct = RegExp(r'''[.,;:!?)\]}>'"]+$''');

  static InlineRun _copy(InlineRun r, String text, {String? href, bool? underline}) => InlineRun(
        text,
        bold: r.bold,
        italic: r.italic,
        underline: underline ?? r.underline,
        strike: r.strike,
        href: href ?? r.href,
        color: r.color,
        fontSize: r.fontSize,
      );

  static List<InlineRun> _linkify(List<InlineRun> runs) {
    final out = <InlineRun>[];
    for (final r in runs) {
      // 已有 href 的（<a> 里）不动
      if (r.href != null || r.text.length < 6) {
        out.add(r);
        continue;
      }
      final text = r.text;
      var last = 0;
      for (final m in _urlRe.allMatches(text)) {
        if (m.start > last) out.add(_copy(r, text.substring(last, m.start)));
        final raw = m.group(0)!;
        var url = raw.replaceFirst(_trailingPunct, '');
        // 去掉尾部成对的右括号（如维基链接）
        while (url.endsWith(')') && ')'.allMatches(url).length > '('.allMatches(url).length) {
          url = url.substring(0, url.length - 1);
        }
        if (url.length <= 5) {
          out.add(_copy(r, raw));
          last = m.end;
          continue;
        }
        final href = url.toLowerCase().startsWith('www.') ? 'https://$url' : url;
        out.add(_copy(r, url, href: href, underline: true));
        final tail = raw.substring(url.length);
        if (tail.isNotEmpty) out.add(_copy(r, tail));
        last = m.end;
      }
      if (last == 0) {
        out.add(r);
        continue;
      }
      if (last < text.length) out.add(_copy(r, text.substring(last)));
    }
    return out;
  }

  static List<InlineRun> _trimRuns(List<InlineRun> runs) {
    final out = <InlineRun>[];
    for (var i = 0; i < runs.length; i++) {
      var text = runs[i].text;
      if (i == 0) text = text.replaceFirst(RegExp(r'^\s+'), '');
      if (i == runs.length - 1) text = text.replaceFirst(RegExp(r'\s+$'), '');
      if (text.isEmpty) continue;
      final r = runs[i];
      out.add(InlineRun(
        text,
        bold: r.bold,
        italic: r.italic,
        underline: r.underline,
        strike: r.strike,
        href: r.href,
        color: r.color,
        fontSize: r.fontSize,
      ));
    }
    return out;
  }

  void walkAll(Iterable<Node> nodes, [_Style style = _kBase]) {
    for (final n in nodes) {
      walk(n, style);
    }
  }

  void walk(Node node, _Style style) {
    if (node is Text) {
      final t = _cleanText(node.text);
      if (t.trim().isEmpty) {
        // 纯空白只在行内已有内容时保留一个空格，避免中文被粘连
        if (_buf.isNotEmpty && t.isNotEmpty) _add(InlineRun(' ', href: style.href));
        return;
      }
      _add(InlineRun(
        t,
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        strike: style.strike,
        href: style.href,
        color: style.color,
        fontSize: style.fontSize,
      ));
      return;
    }
    if (node is! Element) return;

    final tag = node.localName ?? '';
    final cls = node.attributes['class'] ?? '';
    final id = node.attributes['id'] ?? '';
    if (_kSkipTags.contains(tag)) return;
    // 站点用 display:none 藏起来的辅助节点（附件悬浮提示 .tip、下拉菜单等），
    // 之前会把「2 小时前 上传 / 点击文件名下载附件」这类文案当正文吐出来。
    if (_isHidden(node)) return;
    // 隐藏提示由上层决定是否单独展示：楼主楼用横幅，回复楼直接写在正文里
    if (!keepLocked && (cls.contains('locked') || cls.contains('attach_nopermission'))) {
      return;
    }
    if (cls.contains('attach_nopermission') || cls.contains('pstatus')) return;
    // 模板自带的版权声明、帖子操作按钮区，不属于正文
    if (id == 'copyright' || cls.contains('copyright') || id == 'p_btn' || cls.contains('comiis_p_btn')) {
      return;
    }

    switch (tag) {
      case 'br':
        _add(InlineRun('\n', href: style.href));
        return;
      case 'img':
        _flush();
        final url = _imageUrl(node);
        if (url != null) blocks.add(ContentBlock.image(url));
        return;
      case 'hr':
        _flush();
        blocks.add(const ContentBlock.divider());
        return;
      case 'blockquote':
        _flush();
        final quote = _collectInline(node, style);
        if (quote.isNotEmpty) blocks.add(ContentBlock.quote(quote));
        return;
      case 'pre':
        _flush();
        final code = node.text.replaceAll('\u00a0', ' ').trimRight();
        if (code.trim().isNotEmpty) blocks.add(ContentBlock.codeBlock(code));
        return;
      case 'table':
        _flush();
        final tableRows = _collectTable(node, style);
        if (tableRows.isNotEmpty) blocks.add(ContentBlock.table(tableRows));
        return;
      case 'video':
        _flush();
        final videoUrl = node.attributes['src'] ?? node.attributes['data-src'] ?? '';
        if (videoUrl.isNotEmpty) blocks.add(ContentBlock.video(absoluteUrl(videoUrl)));
        return;
      case 'iframe':
        _flush();
        final iframeUrl = node.attributes['src'] ?? '';
        if (iframeUrl.isNotEmpty) blocks.add(ContentBlock.iframe(absoluteUrl(iframeUrl)));
        return;
      case 'h1':
        _flush();
        final h1 = _collectInline(node, style.copyWith(bold: true, fontSize: 24));
        if (h1.isNotEmpty) blocks.add(ContentBlock.h1(h1));
        return;
      case 'h2':
        _flush();
        final h2 = _collectInline(node, style.copyWith(bold: true, fontSize: 22));
        if (h2.isNotEmpty) blocks.add(ContentBlock.h2(h2));
        return;
      case 'h3':
        _flush();
        final h3 = _collectInline(node, style.copyWith(bold: true, fontSize: 20));
        if (h3.isNotEmpty) blocks.add(ContentBlock.h3(h3));
        return;
      case 'h4':
        _flush();
        final h4 = _collectInline(node, style.copyWith(bold: true, fontSize: 18));
        if (h4.isNotEmpty) blocks.add(ContentBlock.h4(h4));
        return;
      case 'h5':
        _flush();
        final h5 = _collectInline(node, style.copyWith(bold: true, fontSize: 16));
        if (h5.isNotEmpty) blocks.add(ContentBlock.h5(h5));
        return;
      case 'h6':
        _flush();
        final h6 = _collectInline(node, style.copyWith(bold: true, fontSize: 14));
        if (h6.isNotEmpty) blocks.add(ContentBlock.h6(h6));
        return;
      case 'a':
        final href = node.attributes['href'] ?? '';
        final usable = href.isEmpty || href.startsWith('#') || href.toLowerCase().startsWith('javascript');
        walkAll(node.nodes, style.copyWith(href: usable ? null : absoluteUrl(href)));
        return;
      case 'strong':
      case 'b':
        walkAll(node.nodes, style.copyWith(bold: true));
        return;
      case 'em':
      case 'i':
        walkAll(node.nodes, style.copyWith(italic: true));
        return;
      case 'u':
      case 'ins':
        walkAll(node.nodes, style.copyWith(underline: true));
        return;
      case 's':
      case 'del':
      case 'strike':
        walkAll(node.nodes, style.copyWith(strike: true));
        return;
      case 'font':
        walkAll(
          node.nodes,
          style.copyWith(color: _parseColor(node.attributes['color'])),
        );
        return;
      case 'sub':
      case 'sup':
      case 'mark':
      case 'small':
      case 'big':
      case 'span':
      case 'label':
      case 'abbr':
      case 'time':
        walkAll(
          node.nodes,
          style.copyWith(
            color: _colorFromStyle(node.attributes['style']),
            fontSize: _sizeFromStyle(node.attributes['style']),
          ),
        );
        return;
      case 'li':
        _flush();
        _add(InlineRun('• ', bold: style.bold, href: style.href));
        walkAll(node.nodes, style);
        _flush();
        return;
    }

    if (_kBlockTags.contains(tag)) {
      _flush();
      walkAll(node.nodes, style.copyWith(
        color: _colorFromStyle(node.attributes['style']),
        fontSize: _sizeFromStyle(node.attributes['style']),
      ));
      _flush();
      return;
    }

    // 其余未知标签：递归下去，绝不丢内容
    walkAll(node.nodes, style);
  }

  /// 收集一个节点下的所有行内内容（用于引用块）
  List<InlineRun> _collectInline(Node node, _Style style) {
    final sub = _Builder(keepLocked: keepLocked);
    sub.walkAll(node.nodes, style);
    sub._flush();
    final out = <InlineRun>[];
    for (final b in sub.blocks) {
      if (b.kind == BlockKind.text || b.kind == BlockKind.quote) {
        out.addAll(b.runs);
        out.add(const InlineRun('\n'));
      } else if (b.kind == BlockKind.code) {
        out.add(InlineRun(b.code));
        out.add(const InlineRun('\n'));
      }
    }
    // 去掉尾部多余换行
    while (out.isNotEmpty && out.last.text.trim().isEmpty) {
      out.removeLast();
    }
    return _trimRuns(out);
  }

  /// 收集表格行（用于 table 块）
  List<List<InlineRun>> _collectTable(Element node, _Style style) {
    final rows = <List<InlineRun>>[];
    for (final tr in node.querySelectorAll('tr')) {
      final cells = <InlineRun>[];
      for (final td in tr.querySelectorAll('td, th')) {
        final sub = _Builder(keepLocked: keepLocked);
        sub.walkAll(td.nodes, style);
        sub._flush();
        final cellRuns = <InlineRun>[];
        for (final b in sub.blocks) {
          if (b.kind == BlockKind.text || b.kind == BlockKind.quote) {
            cellRuns.addAll(b.runs);
          } else if (b.kind == BlockKind.code) {
            cellRuns.add(InlineRun(b.code));
          }
        }
        if (cellRuns.isNotEmpty) {
          cells.add(InlineRun(cellRuns.map((r) => r.text).join()));
        } else {
          cells.add(const InlineRun(''));
        }
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }
}

/// 把帖子正文 HTML 解析成内容块（纯函数，方便离线回归）。
///
/// [showLockedHint] 为 true 时保留「回复可见 / 购买可见 / 作者被屏蔽」提示，
/// 楼主楼通常由页面横幅统一提示，传 false 避免重复。
List<ContentBlock> parsePostContent(String html, {bool showLockedHint = false}) {
  if (html.trim().isEmpty) return const [];
  final frag = html_parser.parseFragment(html);
  frag.querySelectorAll('script, style, noscript').forEach((e) => e.remove());
  for (final sel in _kNoiseSelectors) {
    frag.querySelectorAll(sel).forEach((e) => e.remove());
  }

  final b = _Builder(keepLocked: showLockedHint);
  b.walkAll(frag.nodes);
  b._flush();

  // 压缩连续换行，避免大量空行
  final out = <ContentBlock>[];
  for (final blk in b.blocks) {
    if (blk.kind == BlockKind.text) {
      final runs = <InlineRun>[];
      for (final r in blk.runs) {
        final t = r.text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
        runs.add(InlineRun(
          t,
          bold: r.bold,
          italic: r.italic,
          underline: r.underline,
          strike: r.strike,
          href: r.href,
          color: r.color,
          fontSize: r.fontSize,
        ));
      }
      if (runs.any((r) => r.text.trim().isNotEmpty)) out.add(ContentBlock.text(runs));
    } else {
      out.add(blk);
    }
  }
  return out;
}

/// 正文纯文本（用于复制、摘要、内容完整性校验）
String contentPlainText(List<ContentBlock> blocks, {bool keepNewlines = true}) {
  final sb = StringBuffer();
  for (final b in blocks) {
    if (b.kind == BlockKind.image) {
      if (keepNewlines) sb.write('\n');
      continue;
    }
    sb.write(b.plainText);
    if (keepNewlines) sb.write('\n');
  }
  return sb.toString();
}
