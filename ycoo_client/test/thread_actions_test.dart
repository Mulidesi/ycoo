/// 点赞（站点「支持」）与收藏：解析 + 接口响应回归。
///
/// 真实页面结构（tid 147227）：
///   <a href="forum.php?mod=misc&amp;action=recommend&amp;do=add&amp;tid=…&amp;hash=…&amp;handlekey=recommend">顶一下</a>
///   <span id="recommendv_add">5</span>
///   <a href="home.php?mod=spacecp&amp;ac=favorite&amp;type=thread&amp;id=…&amp;formhash=…">收藏</a>
///
/// 接口响应（inajax XML）：
///   点赞成功：errorhandle_recommend('评价指数 5 +1', {'recommendv':'+1','recommendc':'5'})
///   点赞重复：errorhandle_('评价指数 6您已评价过本主题', …)
///   收藏成功：succeedhandle_('https://…', '信息收藏成功 ', {'id':'147227','favid':'64802'})
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

const String _threadHtml = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=49&amp;tid=147227"></form>
<div id="post_2899607" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_2899607">正文</td>
  </tr></table></div></div></div>
</div>
<div class="recommend">
  <a href="forum.php?mod=misc&amp;action=recommend&amp;do=add&amp;tid=147227&amp;hash=b2f4bfe0&amp;handlekey=recommend"
     title="顶一下">支持</a>
  <span id="recommendv_add">5</span>
  <a href="forum.php?mod=misc&amp;action=recommend&amp;do=subtract&amp;tid=147227&amp;hash=b2f4bfe0">反对</a>
  <a href="home.php?mod=spacecp&amp;ac=favorite&amp;type=thread&amp;id=147227&amp;formhash=b2f4bfe0"
     title="收藏本帖">收藏</a>
</div>
</body></html>
''';

http.Response _xml(String body) => http.Response(
      '<?xml version="1.0" encoding="utf-8"?>\n<root><![CDATA[$body]]></root>',
      200,
      headers: {'content-type': 'text/xml; charset=utf-8'},
    );

ForumApi _api(http.Response Function(http.Request) handler) =>
    ForumApi(DiscuzClient(client: MockClient((r) async => handler(r))));

void main() {
  group('解析点赞 / 收藏入口', () {
    test('提取 add 链接、支持人数与收藏链接并绝对化', () {
      final d = parseThread(_threadHtml, tid: 147227, page: 1);
      expect(d.supportUrl, contains('action=recommend'));
      expect(d.supportUrl, contains('do=add'));
      expect(d.supportUrl, contains('hash=b2f4bfe0'));
      expect(d.supportUrl, startsWith('https://ycoo.net/'));
      expect(d.supportCount, 5);
      expect(d.favoriteUrl, contains('ac=favorite'));
      expect(d.favoriteUrl, contains('formhash=b2f4bfe0'));
      expect(d.favoriteUrl, startsWith('https://ycoo.net/'));
    });

    test('无入口时字段为 null，不误判', () {
      final d = parseThread(
        '<html><body><form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=9"></form></body></html>',
        tid: 9,
        page: 1,
      );
      expect(d.supportUrl, isNull);
      expect(d.supportCount, isNull);
      expect(d.favoriteUrl, isNull);
    });
  });

  group('supportThread', () {
    test('recommentc 响应视为成功', () async {
      final api = _api((req) => _xml(
            "<script>errorhandle_recommend('评价指数 6 +1', "
            "{'recommendv':'+1','recommentc':'6'});</script>",
          ));
      final r = await api.supportThread(
        'https://ycoo.net/forum.php?mod=misc&action=recommend&do=add&tid=1&hash=h',
      );
      expect(r.success, isTrue);
      expect(r.message, '已支持');
    });

    test('重复点赞提示已支持过', () async {
      final api = _api((req) => _xml(
            "<script>errorhandle_('评价指数 6您已评价过本主题', "
            "{'recommentc':'6'});</script>",
          ));
      final r = await api.supportThread(
        'https://ycoo.net/forum.php?mod=misc&action=recommend&do=add&tid=1&hash=h',
      );
      expect(r.success, isTrue);
      expect(r.message, contains('已支持'));
    });

    test('alert_error 透传站点文案', () async {
      final api = _api((req) => _xml(
            '<div class="alert_error">抱歉，您的请求来路不正确或表单验证串不符，无法提交</div>',
          ));
      final r = await api.supportThread(
        'https://ycoo.net/forum.php?mod=misc&action=recommend&do=add&tid=1&hash=h',
      );
      expect(r.success, isFalse);
      expect(r.message, contains('来路不正确'));
    });

    test('请求自动补 inajax=1', () async {
      Uri? seen;
      final api = _api((req) {
        seen = req.url;
        return _xml("<script>errorhandle_('x');</script>");
      });
      await api.supportThread('https://ycoo.net/forum.php?mod=misc&action=recommend&do=visit&tid=1');
      expect(seen!.queryParameters['inajax'], '1');
    });
  });

  group('favoriteThread', () {
    test('收藏成功响应', () async {
      final api = _api((req) => _xml(
            "<script>succeedhandle_('https://ycoo.net/thread-1-1-1.html', "
            "'信息收藏成功 ', {'id':'1','favid':'64802'});</script>",
          ));
      final r = await api.favoriteThread(
        'https://ycoo.net/home.php?mod=spacecp&ac=favorite&type=thread&id=1&formhash=h',
      );
      expect(r.success, isTrue);
      expect(r.message, '收藏成功');
    });

    test('已收藏视为成功', () async {
      final api = _api((req) => _xml('您已经收藏过本帖'));
      final r = await api.favoriteThread(
        'https://ycoo.net/home.php?mod=spacecp&ac=favorite&type=thread&id=1&formhash=h',
      );
      expect(r.success, isTrue);
      expect(r.message, contains('已收藏'));
    });

    test('失败透传文案', () async {
      final api = _api((req) => _xml('<div class="alert_error">抱歉，您没有权限收藏</div>'));
      final r = await api.favoriteThread(
        'https://ycoo.net/home.php?mod=spacecp&ac=favorite&type=thread&id=1&formhash=h',
      );
      expect(r.success, isFalse);
      expect(r.message, contains('没有权限'));
    });
  });
}
