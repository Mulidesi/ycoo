/// 回帖链路加固回归：503 表单校验失败重试、灌水控制等待重试、
/// 服务端 posttime 透传、网络异常包装。
///
/// 依据 2026-10 实机探测（ycoo.net，Discuz! X3.5）：
///   * formhash 校验失败 → HTTP 503 + 「System Error / 非法字符」页；
///   * 灌水控制（floodctrl=5）→ HTTP 200 + errorhandle_fastpost 文案；
///   * 回帖表单隐藏字段 posttime 是站点时间戳。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';

const String _threadPage = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=9&amp;extra=page%3D1&amp;replysubmit=yes&amp;infloat=yes&amp;handlekey=fastpost">
<input type="hidden" name="formhash" value="abc12345">
<input type="hidden" name="posttime" value="1790000000">
</form>
</body></html>
''';

const String _threadPageFresh = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=9&amp;extra=page%3D1&amp;replysubmit=yes&amp;infloat=yes&amp;handlekey=fastpost">
<input type="hidden" name="formhash" value="def67890">
<input type="hidden" name="posttime" value="1790000001">
</form>
</body></html>
''';

String _okXml() =>
    '<?xml version="1.0" encoding="utf-8"?>\n<root><![CDATA['
    "<script type=\"text/javascript\" reload=\"1\">if(typeof succeedhandle_fastpost"
    "=='function') {succeedhandle_fastpost('forum.php?mob=1&mod=viewthread&tid=9',"
    " '回复发布成功', {'tid':9});}</script>]]></root>";

String _errXml(String msg) =>
    '<?xml version="1.0" encoding="utf-8"?>\n<root><![CDATA[$msg]]></root>';

String _sysError503() => '<!DOCTYPE html><html><head>'
    '<title>ycoo.net - System Error</title></head><body>'
    '<h1>Discuz! System Error</h1>'
    '<li>您当前的访问请求当中含有非法字符，已经被系统拒绝</li>'
    '</body></html>';

http.Response _resp(String body, {int status = 200}) => http.Response(
      body,
      status,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );

void main() {
  test('回帖透传表单里的服务端 posttime', () async {
    final posts = <Map<String, String>>[];
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        if (r.method == 'GET') return _resp(_threadPage);
        posts.add(Uri.splitQueryString(r.body));
        return _resp(_okXml());
      }),
    ));
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isTrue);
    expect(posts.single['posttime'], '1790000000');
    expect(posts.single['formhash'], 'abc12345');
    expect(posts.single.containsKey('subject'), isFalse);
  });

  test('503 表单校验失败：换新令牌重试后成功', () async {
    var gets = 0;
    final posts = <Map<String, String>>[];
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        if (r.method == 'GET') {
          gets++;
          return _resp(gets == 1 ? _threadPage : _threadPageFresh);
        }
        posts.add(Uri.splitQueryString(r.body));
        return _resp(posts.length == 1 ? _sysError503() : _okXml(),
            status: posts.length == 1 ? 503 : 200);
      }),
    ));
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isTrue);
    expect(posts.length, 2);
    expect(posts[0]['formhash'], 'abc12345');
    expect(posts[1]['formhash'], 'def67890');
  });

  test('200 来路不正确持续失败：给出明确失败文案', () async {
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        if (r.method == 'GET') return _resp(_threadPage);
        return _resp(_errXml('来路不正确或表单验证串不符，请刷新重试'));
      }),
    ));
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isFalse);
    expect(res.message, '回复状态已过期，请下拉刷新页面后重试');
  });

  test('503 非法字符持续失败：提示修改内容', () async {
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        if (r.method == 'GET') return _resp(_threadPage);
        return _resp(_sysError503(), status: 503);
      }),
    ));
    final res = await api.reply(tid: 9, fid: 2, message: 'hello%');
    expect(res.success, isFalse);
    expect(res.message, '站点拒绝了这个回复内容，请修改后重试');
  });

  test('灌水控制：等待后重试一次成功', () async {
    var posts = 0;
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        if (r.method == 'GET') return _resp(_threadPage);
        posts++;
        return _resp(posts == 1 ? _errXml('抱歉，您两次发表间隔少于 5 秒，请稍候再发表') : _okXml());
      }),
    ));
    api.floodWait = const Duration(milliseconds: 5);
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isTrue);
    expect(posts, 2);
  });

  test('灌水控制重试仍失败：给出友好文案', () async {
    var posts = 0;
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        if (r.method == 'GET') return _resp(_threadPage);
        posts++;
        return _resp(_errXml('抱歉，您两次发表间隔少于 5 秒，请稍候再发表'));
      }),
    ));
    api.floodWait = const Duration(milliseconds: 5);
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isFalse);
    expect(res.message, '发帖太快了，站点要求间隔几秒，请稍候再试');
    expect(posts, 2);
  });

  test('网络异常：包装为可读失败结果', () async {
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async {
        throw const SocketException('connection refused');
      }),
    ));
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isFalse);
    expect(res.message, isNotEmpty);
  });

  test('登录页响应：提示重新登录', () async {
    final api = ForumApi(DiscuzClient(
      client: MockClient((r) async => _resp(
            '<form action="member.php?mod=logging&amp;action=login&amp;'
            'loginsubmit=yes"><input name="formhash" value="abc12345"></form>',
          )),
    ));
    final res = await api.reply(tid: 9, fid: 2, message: 'hello');
    expect(res.success, isFalse);
    expect(res.message, '登录状态已失效，请重新登录');
  });
}
