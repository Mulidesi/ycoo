// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ycoo_client/data/content.dart';
import 'package:ycoo_client/data/previews.dart';
import 'package:ycoo_client/core/discuz_client.dart';

Future<void> main(List<String> args) async {
  final dir = args.isEmpty ? '../recon' : args[0];

  // 1) 离线：解析 forumdisplay JSON
  final jsonFile = File('$dir/mapi_list.json');
  if (jsonFile.existsSync()) {
    final map = parseForumDisplayPreviews(jsonFile.readAsStringSync());
    print('== 列表预览（离线）: ${map.length} 条');
    var withImage = 0;
    for (final p in map.values) {
      if (p.hasImage) withImage++;
    }
    print('   有首图 $withImage 条');
    final sample = map.entries.where((e) => e.value.hasImage).take(3);
    for (final e in sample) {
      print('   ${e.key} img=${e.value.image}');
      print('         count=${e.value.imageCount} likes=${e.value.likes}');
      print('         excerpt=${e.value.excerpt}');
    }
    final noImg = map.entries.where((e) => !e.value.hasImage).take(2);
    for (final e in noImg) {
      print('   ${e.key} 无图 excerpt=${e.value.excerpt}');
    }
  }

  // 2) 离线：裸链接识别
  print('\n== 裸链接识别');
  var checked = 0;
  for (final f in Directory(dir).listSync().whereType<File>()) {
    if (!f.path.endsWith('.html')) continue;
    final html = f.readAsStringSync();
    final i = html.indexOf('id="postmessage_');
    if (i < 0) continue;
    final j = html.indexOf('</td>', i);
    if (j < 0) continue;
    final body = html.substring(html.indexOf('>', i) + 1, j);
    final blocks = parsePostContent(body);
    final links = <String>[];
    for (final b in blocks) {
      for (final r in b.runs) {
        if (r.href != null) links.add('${r.text} -> ${r.href}');
      }
    }
    checked++;
    if (links.isEmpty) continue;
    print('   ${f.uri.pathSegments.last}: ${links.length} 个链接');
    for (final l in links.take(4)) {
      print('      $l');
    }
  }
  print('   检查 $checked 个页面');

  // 3) 在线：真实接口
  if (args.contains('--live')) {
    print('\n== 在线：fid=39 第 1 页预览');
    final c = DiscuzClient();
    final r = await c.get('api/mobile/index.php?version=4&module=forumdisplay&fid=39&page=1');
    print('   HTTP ${r.statusCode} bytes=${r.body.length}');
    final live = parseForumDisplayPreviews(r.body);
    print('   解析 ${live.length} 条，有首图 ${live.values.where((e) => e.hasImage).length} 条');
    for (final e in live.entries.take(4)) {
      print('   ${e.key} img=${e.value.image}');
      print('        ${e.value.excerpt}');
    }
    c.close();
  }
}
