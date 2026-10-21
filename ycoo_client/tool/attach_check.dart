// ignore_for_file: avoid_print

/// 离线断言附件解析与正文清洗（对齐论坛移动端排版）。
///
/// 用法：dart run tool/attach_check.dart [样本目录，默认 ../recon]
///
/// 覆盖两个真实坑：
///  1. `#postmessage` 里的 `<ignore_js_op>` 文件附件（filetype 16px 小图标）——
///     整块当正文渲染会把图标拉成整屏问号，还会漏出 `display:none` 的 tip 文案。
///     期望：抽成附件卡片、正文里彻底消失。
///  2. `div.pattl` 里的图片附件（img[zoomfile]）—— 期望仍并入正文渲染，不被误删。
library;

import 'dart:io';

import 'package:ycoo_client/data/parsers.dart';
import 'package:ycoo_client/models/models.dart';

var _failed = 0;

void _expect(String label, bool ok, [String detail = '']) {
  print('${ok ? "  ok  " : "  FAIL"}  $label${detail.isEmpty ? "" : "  -> $detail"}');
  if (!ok) _failed++;
}

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');

  ThreadDetail? load(String name) {
    final f = File('${dir.path}/$name');
    if (!f.existsSync()) return null;
    return parseThread(f.readAsStringSync(), tid: 1, page: 1);
  }

  // ---- 样本 1：正文内联文件附件（json），历史上图标被放大 + tip 文案泄漏 ----
  print('[t152780_login.html] 正文内联文件附件');
  final t1 = load('t152780_login.html');
  if (t1 == null) {
    print('  skip  样本不存在');
  } else {
    final p = t1.posts.first;
    _expect('附件卡片数量 = 2', p.attachments.length == 2, '${p.attachments.length}');
    _expect(
      '附件名取自 <a> 文本',
      p.attachments.every((a) => a.name.toLowerCase().endsWith('.json')),
      p.attachments.map((a) => a.name).join(' | '),
    );
    _expect(
      '附件大小解析为 "13.83 KB" 形式',
      p.attachments.every((a) => a.sizeText != null && RegExp(r'^[\d.]+\s*[KMG]B$').hasMatch(a.sizeText!)),
      p.attachments.map((a) => a.sizeText).join(' | '),
    );
    _expect('正文不含 ignore_js_op', !p.contentHtml.contains('ignore_js_op'));
    _expect('正文不含 filetype 图标', !p.contentHtml.contains('/static/image/filetype/'));
    _expect('正文不含 tip 提示块', !p.contentHtml.contains('class="tip'));
    _expect('正文不含 "点击文件名下载附件"', !p.contentHtml.contains('点击文件名下载附件'));
    _expect('正文不含 "上传" 残留', !p.contentHtml.contains('上传'));
  }

  // ---- 样本 2：pattl 里的图片附件必须保留在正文 ----
  print('[t_152545.html] 图片附件仍并入正文');
  final t2 = load('t_152545.html');
  if (t2 == null) {
    print('  skip  样本不存在');
  } else {
    final p = t2.posts.first;
    _expect('正文保留 zoomfile 图片', p.contentHtml.contains('zoomfile'));
    _expect('正文不含 filetype 图标', !p.contentHtml.contains('/static/image/filetype/'));
    _expect('正文不含 tip 提示块', !p.contentHtml.contains('class="tip'));
  }

  // ---- 样本 3：单附件回归 ----
  print('[t153650_after.html] 单附件');
  final t3 = load('t153650_after.html');
  if (t3 == null) {
    print('  skip  样本不存在');
  } else {
    final p = t3.posts.first;
    _expect('附件卡片数量 = 1', p.attachments.length == 1, '${p.attachments.length}');
    _expect(
      '大小取自 <p> 文本（无 <em> 的模板）',
      p.attachments.every((a) => a.sizeText == '5.92 KB'),
      p.attachments.map((a) => a.sizeText).join(' | '),
    );
    _expect('正文不含 filetype 图标', !p.contentHtml.contains('/static/image/filetype/'));
  }

  // ---- 全样本回归：所有 recon 页面都不得把附件块残留进正文 ----
  print('[全样本] 附件残留扫描');
  var files = 0, posts = 0, atts = 0, leaked = 0, broken = 0;
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.html')) continue;
    files++;
    try {
      final d = parseThread(f.readAsStringSync(), tid: 1, page: 1);
      posts += d.posts.length;
      for (final p in d.posts) {
        atts += p.attachments.length;
        final dirty = p.contentHtml.contains('ignore_js_op') ||
            p.contentHtml.contains('/static/image/filetype/') ||
            p.contentHtml.contains('点击文件名下载附件');
        if (dirty) {
          leaked++;
          print('  LEAK  ${f.path} pid=${p.pid}');
        }
      }
    } catch (e) {
      broken++;
      print('  ERR   ${f.path} -> $e');
    }
  }
  _expect('$files 个样本全部解析成功', broken == 0, 'error=$broken');
  _expect('正文无附件残留', leaked == 0, 'leak=$leaked');
  print('  统计: files=$files posts=$posts attachments=$atts');

  print(_failed == 0 ? '\nALL PASS' : '\n$_failed FAILED');
  if (_failed != 0) exitCode = 1;
}
