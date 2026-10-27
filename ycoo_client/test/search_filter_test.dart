/// P14：搜索筛选（Issue #1）回归测试。
///
/// 覆盖：ForumApi.search 筛选参数拼装、twpx_xunsearch 结果解析、频率限制报错。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';
import 'dart:convert';

http.Response _xsHtml(String body) =>
    http.Response.bytes(utf8.encode(body), 200);

const String _xunSearchHtml = '''
<html><body>
<dl class="result-list">
  <dt><a href="forum.php?mod=viewthread&amp;tid=123"><h4>91 <em>番茄</em>更新 <small>[81%]</small></h4></a></dt>
  <dd>
    <p>摘要正文</p>
    <p class="field-info">
      <span>发帖时间:2025-8-29</span>
      <span>作者:<a href="home.php?mod=space&amp;uid=47753">妍希</a></span>
      <span><a href="forum.php?mod=forumdisplay&amp;fid=2">书源发布</a></span>
    </p>
  </dd>
  <dt><a href="forum.php?mod=viewthread&amp;tid=456"><h4>2 <em>更新</em>公告</h4></a></dt>
  <dd>
    <p>摘要正文</p>
    <p class="field-info">
      <span>发帖时间:2025-8-30</span>
      <span>作者:<a href="home.php?mod=space&amp;uid=10001">路人甲</a></span>
      <span><a href="forum.php?mod=forumdisplay&amp;fid=3">网络资源</a></span>
    </p>
  </dd>
</dl>
</body></html>
''';

ForumApi _api(http.Response Function(http.Request) handler) =>
    ForumApi(DiscuzClient(client: MockClient((r) async => handler(r))));

void main() {
  group('搜索 URL 拼装', () {
    test('默认参数：全文 / 相关性 / 所有版块 / 同义词开 / 模糊关', () async {
      var lastUrl = '';
      final api = _api((r) {
        lastUrl = r.url.toString();
        return _xsHtml(_xunSearchHtml);
      });
      final items = await api.search('番茄');
      expect(items, hasLength(2));
      expect(lastUrl, contains('plugin.php?id=twpx_xunsearch'));
      expect(lastUrl, contains('q=%E7%95%AA%E8%8C%84'));
      expect(lastUrl, contains('f=_all'));
      expect(lastUrl, contains('s=relevance'));
      expect(lastUrl, contains('fid=0'));
      expect(lastUrl, contains('m='));
      expect(lastUrl, contains('syn=yes'));
    });

    test('筛选参数透传：标题范围 / 时间倒序 / 指定版块', () async {
      var lastUrl = '';
      final api = _api((r) {
        lastUrl = r.url.toString();
        return _xsHtml(_xunSearchHtml);
      });
      await api.search(
        '番茄',
        searchField: 'subject',
        sortBy: 'dateline_DESC',
        fid: 2,
        fuzzy: true,
        synonym: false,
      );
      expect(lastUrl, contains('f=subject'));
      expect(lastUrl, contains('s=dateline_DESC'));
      expect(lastUrl, contains('fid=2'));
      expect(lastUrl, contains('m=yes'));
      expect(lastUrl, contains('syn='));
      expect(lastUrl.contains('syn=yes'), isFalse);
    });

    test('referer 指向论坛首页', () async {
      http.Request? lastReq;
      final api = _api((r) {
        lastReq = r;
        return _xsHtml(_xunSearchHtml);
      });
      await api.search('番茄');
      expect(lastReq!.headers['referer'], contains('ycoo.net'));
    });
  });

  group('搜索结果解析', () {
    test('标题去掉序号与匹配度、作者/版块/时间解析正确', () {
      final items = parseXunsearchResults(_xunSearchHtml).items;
      expect(items, hasLength(2));
      expect(items[0].title, '番茄更新');
      expect(items[0].author, '妍希');
      expect(items[0].authorId, 47753);
      expect(items[0].fid, 2);
      expect(items[0].typeName, '书源发布');
      expect(items[0].timeText, '2025-8-29');
      expect(items[1].title, '更新公告');
      expect(items[1].author, '路人甲');
    });

    test('无匹配度标记时只去序号', () {
      const html = '''
      <html><body><dl class="result-list">
        <dt><a href="forum.php?mod=viewthread&amp;tid=7"><h4>1 <em>某</em>标题</h4></a></dt>
        <dd><p>摘要</p><p class="field-info"><span>发帖时间:2025-1-1</span></p></dd>
      </dl></body></html>
      ''';
      expect(parseXunsearchResults(html).items.single.title, '某标题');
    });
  });

  group('频率限制', () {
    test('返回“两次搜索”提示时抛 ForumException', () async {
      final api = _api(
        (_) => _xsHtml('<html><body>两次搜索时间间隔过短，请稍后再试</body></html>'),
      );
      await expectLater(api.search('番茄'), throwsA(isA<ForumException>()));
    });
  });
}
