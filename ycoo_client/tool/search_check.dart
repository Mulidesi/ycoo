// ignore_for_file: avoid_print
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

Future<void> main() async {
  final client = DiscuzClient();
  final api = ForumApi(client);

  // Test 1: Offline parser with real HTML sample
  print('== 1. Offline parser test ==');
  const sample = '<html><body>'
      '<dl class="result-list">'
      '<dt><a href="https://ycoo.net/forum.php?mod=viewthread&tid=61974&highlight=%E7%95%AA%E8%8C%84&page=1&extra=#pid1176508" target="_blank">'
      '<h4>91 <em>番茄</em>更新 <small>[81%]</small></h4></a></dt>'
      '<dd><p>snippet...</p>'
      '<p class="field-info text-error">'
      '<span><strong>发帖时间:</strong>2025-8-29</span>-'
      '<span><strong>作者:</strong><a href="https://ycoo.net/home.php?mod=space&uid=28149&do=profile" target="_blank">妍希</a></span>-'
      '<span><a href="https://ycoo.net/forum.php?mod=forumdisplay&fid=2">书源发布</a></span>'
      '</p></dd>'
      '</dl>'
      '<ul class="pagination"><li><a href="/plugin.php?id=twpx_xunsearch&q=test&p=11">11</a></li></ul>'
      '<p>大约有<b>2,310</b>项符合查询结果</p>'
      '</body></html>';
  final parsed = parseXunsearchResults(sample);
  print('items: ${parsed.items.length}');
  for (final item in parsed.items) {
    print('  tid=${item.tid} title="${item.title}" author="${item.author}" fid=${item.fid} type="${item.typeName}" time="${item.timeText}"');
  }
  print('totalPages: ${parsed.totalPages}');
  assert(parsed.items.length == 1);
  assert(parsed.items[0].tid == 61974);
  assert(parsed.items[0].title == '番茄更新');
  assert(parsed.items[0].author == '妍希');
  assert(parsed.items[0].authorId == 28149);
  assert(parsed.items[0].fid == 2);
  assert(parsed.items[0].typeName == '书源发布');
  assert(parsed.items[0].timeText == '2025-8-29');
  assert(parsed.totalPages >= 231);
  print('OFFLINE_PARSER_OK');

  // Test 2: Live search
  print('\n== 2. Live search test ==');
  try {
    final items = await api.search('番茄');
    print('Found ${items.length} results');
    for (final item in items.take(5)) {
      print('  [${item.tid}] ${item.title} | ${item.author} | ${item.typeName}');
    }
    if (items.isEmpty) {
      print('ERROR: No results returned');
    } else {
      print('LIVE_SEARCH_OK');
    }
  } catch (e) {
    print('ERROR: $e');
  }

  client.close();
}
