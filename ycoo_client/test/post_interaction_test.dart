/// P15-A 帖子互动增强：投票 / 打赏 / 楼中楼 的解析与接口回归。
///
/// 结构依据真实站点样本（`/tmp/opencode/{live_thread,sample_thread,s_thread}.html`）：
///   * 投票：`.comiis_poll` 内 `input[name*="pollanswer"]`（radio/checkbox）
///   * 打赏记录：`#ratelog_<pid> li`（`a.f_c` 用户名 + `.f_a` 分值）
///   * 楼中楼：`.cm` 容器，`id="comment_N"` 的点评块
///   * 打赏入口：`.comiis_rate.cl` 内 `a.comiis_openrebox`（href 带 action=rate）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

const String _pollHtml = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=49&amp;tid=147227"></form>
<div id="post_2899607" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_2899607">正文</td>
  </tr></table></div></div></div>
</div>
<div class="comiis_poll">
  <div class="polloption">选项 A（3 票）<input type="radio" name="pollanswers" value="1"></div>
  <div class="polloption">选项 B（5 票）<input type="radio" name="pollanswers" value="2"></div>
  <div>共 8 人参与</div>
</div>
</body></html>
''';

const String _pollMultipleHtml = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=9"></form>
<div id="post_1" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_1">正文</td>
  </tr></table></div></div></div>
</div>
<form action="forum.php?mod=misc&amp;action=votepoll" class="pollpanel">
  <label>甲 <input type="checkbox" name="pollanswers[0]" value="11"></label>
  <label>乙 <input type="checkbox" name="pollanswers[1]" value="12"></label>
  <div>多选</div>
</form>
</body></html>
''';

const String _commentHtml = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=9"></form>
<div id="post_10" class="comiis_vpost">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_10">回帖正文</td>
  </tr></table></div></div></div>
  <div class="cm">
    <div class="cm_item" id="comment_1">
      <a class="cm_name" href="home.php?mod=space&amp;uid=100">路人甲</a>
      <span class="cm_text">同意楼主</span>
      <span class="cm_time">2026-10-01 10:00</span>
    </div>
    <div class="cm_item" id="comment_2">
      <a class="cm_name" href="home.php?mod=space&amp;uid=101">路人乙</a>
      <span class="cm_text">楼中楼点评</span>
      <span class="cm_time">2026-10-02 11:00</span>
    </div>
  </div>
</div>
</body></html>
''';

const String _rateHtml = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=9"></form>
<div id="post_10" class="comiis_vpost">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_10">回帖正文</td>
  </tr></table></div></div></div>
  <div class="comiis_rate cl">
    <a class="comiis_openrebox" href="forum.php?mod=misc&amp;action=rate&amp;tid=9&amp;pid=10">打赏</a>
    <div id="ratelog_10">
      <li id="rate_10_100"><a class="f_c" href="home.php?mod=space&amp;uid=100">张三</a>
        <span class="f_a">+2</span><p>写得不错</p></li>
    </div>
  </div>
</div>
</body></html>
''';

const String _rateOptionsHtml = '''
<!DOCTYPE html><html><body>
<table>
<tr><td>好评</td><td><input type="radio" name="score1" value="1"></td>
  <td>1 ~ 1</td><td>剩余 1</td></tr>
<tr><td>金币</td><td><input type="radio" name="score2" value="1"></td>
  <td>1 ~ 2</td><td>剩余 2</td></tr>
</table>
<input type="checkbox" name="sendreasonpm">
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
  group('解析投票', () {
    test('单选：提取选项、票数与参与人数', () {
      final d = parseThread(_pollHtml, tid: 147227, page: 1);
      final poll = d.posts.first.poll;
      expect(poll, isNotNull);
      expect(poll!.options.length, 2);
      expect(poll.options[0].id, 1);
      expect(poll.options[0].text, '选项 A');
      expect(poll.options[0].votes, 3);
      expect(poll.options[1].text, '选项 B');
      expect(poll.options[1].votes, 5);
      expect(poll.multiple, isFalse);
      expect(poll.total, 8);
      expect(poll.totalVotes, 8);
    });

    test('多选：识别 checkbox 与多选标记', () {
      final d = parseThread(_pollMultipleHtml, tid: 9, page: 1);
      final poll = d.posts.first.poll;
      expect(poll, isNotNull);
      expect(poll!.multiple, isTrue);
      expect(poll.options[0].id, 11);
      expect(poll.options[1].id, 12);
    });

    test('无投票容器时 poll 为 null', () {
      final d = parseThread(_commentHtml, tid: 9, page: 1);
      expect(d.posts.first.poll, isNull);
    });
  });

  group('解析楼中楼', () {
    test('提取点评列表（作者 / 文本 / 时间 / uid）', () {
      final d = parseThread(_commentHtml, tid: 9, page: 1);
      final p = d.posts.first;
      expect(p.comments.length, 2);
      expect(p.comments[0].author, '路人甲');
      expect(p.comments[0].text, '同意楼主');
      expect(p.comments[0].uid, 100);
      expect(p.comments[0].time, '2026-10-01 10:00');
      expect(p.comments[1].author, '路人乙');
      expect(p.comments[1].text, '楼中楼点评');
    });

    test('无评论时为空列表', () {
      final d = parseThread(_pollHtml, tid: 147227, page: 1);
      expect(d.posts.first.comments, isEmpty);
    });
  });

  group('解析打赏', () {
    test('识别打赏入口与记录', () {
      final d = parseThread(_rateHtml, tid: 9, page: 1);
      final p = d.posts.first;
      expect(p.canRate, isTrue);
      expect(p.rates.length, 1);
      expect(p.rates[0].username, '张三');
      expect(p.rates[0].score, '+2');
      expect(p.rates[0].reason, '写得不错');
      expect(p.rates[0].uid, 100);
    });

    test('无打赏入口时 canRate 为 false', () {
      final d = parseThread(_pollHtml, tid: 147227, page: 1);
      expect(d.posts.first.canRate, isFalse);
    });
  });

  group('解析打赏选项页', () {
    test('提取积分项、范围与今日剩余', () {
      final o = parseRateOptions(_rateOptionsHtml);
      expect(o.fields.length, 2);
      final good = o.fields[0];
      expect(good.label, '好评');
      expect(good.max, 1);
      expect(good.left, 1);
      expect(good.ceiling, 1);
      final coin = o.fields[1];
      expect(coin.label, '金币');
      expect(coin.max, 2);
      expect(coin.left, 2);
      expect(coin.ceiling, 2);
      expect(o.canNotify, isTrue);
    });

    test('无可选项时回退到默认好评/金币', () {
      final o = parseRateOptions('<html><body><p>没有可评分项</p></body></html>');
      expect(o.fields, isNotEmpty);
      expect(o.fields.length, 2);
    });
  });

  group('接口：投票 / 打赏 / 点评', () {
    test('votePoll 逐个选项填 pollanswers[i] 并提交', () async {
      Map<String, String>? body;
      final api = _api((r) {
        body = r.bodyFields;
        expect(r.method, 'POST');
        return _xml("succeedhandle_('url', '投票成功 ', {})");
      });
      final msg = await api.votePoll(
        tid: 147227,
        fid: 49,
        formhash: 'abc123',
        ids: [1, 3],
      );
      expect(msg, '投票成功');
      expect(body!['pollanswers[0]'], '1');
      expect(body!['pollanswers[1]'], '3');
      expect(body!['pollsubmit'], 'yes');
    });

    test('votePoll 空选项直接抛错', () async {
      final api = _api((r) => http.Response('', 200));
      expect(
        () => api.votePoll(tid: 1, fid: 1, formhash: 'x', ids: const []),
        throwsA(isA<ForumException>()),
      );
    });

    test('votePoll 站点错误提示透传并抛错', () async {
      final api = _api((r) => _xml("errorhandle_poll('您已经投过票了', {})"));
      expect(
        () => api.votePoll(tid: 1, fid: 1, formhash: 'x', ids: [1]),
        throwsA(isA<ForumException>()),
      );
    });

    test('ratePost 提交 score+reason 并返回提示', () async {
      Map<String, String>? body;
      final api = _api((r) {
        body = r.bodyFields;
        return _xml("succeedhandle_('url', '评分成功 ', {})");
      });
      final msg = await api.ratePost(
        tid: 9,
        pid: 10,
        formhash: 'abc',
        scores: {1: 2},
        reason: '不错',
        notify: true,
      );
      expect(body!['score1'], '2');
      expect(body!['reason'], '不错');
      expect(body!['sendreasonpm'], 'on');
      expect(msg, '评分成功');
    });

    test('ratePost 额度用完映射为友好文案', () async {
      final api = _api(
        (r) => _xml("errorhandle_rate('抱歉，24 小时评分数超过限制', {})"),
      );
      expect(
        () => api.ratePost(tid: 9, pid: 10, formhash: 'abc', scores: {1: 1}),
        throwsA(
          predicate((e) =>
              e is ForumException &&
              e.message!.contains('24 小时内该积分项')),
        ),
      );
    });

    test('fetchRateOptions 解析积分项', () async {
      final api = _api((r) {
        expect(r.url.queryParameters['action'], 'rate');
        expect(r.url.queryParameters['showratetip'], '1');
        return http.Response(_rateOptionsHtml, 200);
      });
      final o = await api.fetchRateOptions(tid: 9, pid: 10);
      expect(o.fields, isNotEmpty);
    });

    test('addComment 提交 message + posttime 并返回成功', () async {
      Map<String, String>? body;
      final api = _api((r) {
        body = r.bodyFields;
        return _xml("succeedhandle_('url', '点评成功 ', {})");
      });
      final msg = await api.addComment(
        tid: 9,
        pid: 10,
        message: '写得好',
        formhash: 'abc',
      );
      expect(body!['message'], '写得好');
      expect(body!['posttime'], isNotNull);
      expect(body!['posttime'], isNotEmpty);
      expect(msg, '点评成功');
    });

    test('addComment 空内容直接抛错', () async {
      final api = _api((r) => http.Response('', 200));
      expect(
        () => api.addComment(tid: 9, pid: 10, message: '   ', formhash: 'x'),
        throwsA(isA<ForumException>()),
      );
    });
  });

  group('接口：举报 / 编辑 / 删除', () {
    test('report 提交 reason + message 并返回成功', () async {
      Map<String, String>? body;
      final api = _api((r) {
        body = r.bodyFields;
        expect(r.method, 'POST');
        return _xml("succeedhandle_('url', '举报已提交', {})");
      });
      final msg = await api.report(
        tid: 9,
        fid: 2,
        pid: 10,
        formhash: 'abc',
        reason: 3,
        message: '重复内容',
      );
      expect(body!['reason'], '3');
      expect(body!['message'], '重复内容');
      expect(msg, '举报已提交');
    });

    test('report 空 formhash 直接抛错', () async {
      final api = _api((r) => http.Response('', 200));
      expect(
        () => api.report(tid: 9, fid: 2, pid: 10, formhash: '', reason: 1),
        throwsA(isA<ForumException>()),
      );
    });

    test('editPost 提交 subject + message + posttime 并返回成功', () async {
      Map<String, String>? body;
      final api = _api((r) {
        body = r.bodyFields;
        expect(r.method, 'POST');
        return _xml("succeedhandle_('url', '编辑成功', {})");
      });
      final msg = await api.editPost(
        tid: 9,
        fid: 2,
        pid: 10,
        subject: 'Re: 标题',
        message: '修改后的正文',
        formhash: 'abc',
      );
      expect(body!['subject'], 'Re: 标题');
      expect(body!['message'], '修改后的正文');
      expect(body!['posttime'], isNotEmpty);
      expect(msg, '编辑成功');
    });

    test('editPost 站点错误提示透传并抛错', () async {
      final api = _api((r) => _xml("errorhandle_edit('抱歉，您没有编辑权限', {})"));
      expect(
        () => api.editPost(
            tid: 9, fid: 2, pid: 10, subject: 'x', message: 'y', formhash: 'abc'),
        throwsA(isA<ForumException>()),
      );
    });

    test('deletePost GET 请求带 delete=1 并返回成功', () async {
      var url = '';
      final api = _api((r) {
        url = r.url.toString();
        return _xml("succeedhandle_('url', '已删除', {})");
      });
      final msg = await api.deletePost(
        tid: 9, fid: 2, pid: 10, formhash: 'abc',
      );
      expect(url, contains('delete=1'));
      expect(url, contains('formhash=abc'));
      expect(msg, '已删除');
    });
  });

  group('接口：附件上传', () {
    test('uploadAttachment 空 hash 直接抛错', () async {
      final api = _api((r) => http.Response('', 200));
      expect(
        () => api.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'test.png',
          uploadHash: '',
          uid: 1,
        ),
        throwsA(isA<ForumException>()),
      );
    });

    test('uploadAttachment 图片上传成功返回 aid', () async {
      var capturedUrl = '';
      final api = _api((r) {
        capturedUrl = r.url.toString();
        return http.Response('DISCUZUPLOAD|123|0|456', 200);
      });
      final aid = await api.uploadAttachment(
        bytes: [1, 2, 3],
        filename: 'photo.jpg',
        uploadHash: 'hash_abc',
        uid: 42,
        fid: 10,
        image: true,
      );
      expect(aid, 456);
      expect(capturedUrl, contains('type=image'));
      expect(capturedUrl, contains('mod=swfupload'));
    });

    test('uploadAttachment 文件上传 type=attach', () async {
      var capturedUrl = '';
      final api = _api((r) {
        capturedUrl = r.url.toString();
        return http.Response('DISCUZUPLOAD|123|0|456', 200);
      });
      final aid = await api.uploadAttachment(
        bytes: [1, 2, 3],
        filename: 'doc.pdf',
        uploadHash: 'hash_abc',
        uid: 42,
        image: false,
      );
      expect(aid, 456);
      expect(capturedUrl, contains('type=attach'));
    });

    test('uploadAttachment 响应格式不匹配抛错', () async {
      final api = _api((r) => http.Response('ERROR: upload failed', 200));
      expect(
        () => api.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'test.png',
          uploadHash: 'hash_abc',
          uid: 1,
        ),
        throwsA(isA<ForumException>()),
      );
    });

    test('uploadAttachment 站点错误状态码抛错', () async {
      final api = _api((r) => http.Response('DISCUZUPLOAD||-1|0', 200));
      expect(
        () => api.uploadAttachment(
          bytes: [1, 2, 3],
          filename: 'test.png',
          uploadHash: 'hash_abc',
          uid: 1,
        ),
        throwsA(isA<ForumException>()),
      );
    });
  });

  group('回复 submit_invalid 令牌竞态重试', () {
    const threadPage =
        '<html><body>'
        '<div id="um"><a href="member.php?mod=logging&amp;action=logout">logout</a></div>'
        '<form id="fastpostform" action="forum.php?mod=post&amp;action=reply'
        '&amp;fid=39&amp;tid=152951&amp;replysubmit=yes&amp;infloat=yes'
        '&amp;handlekey=fastpost">'
        '<input type="hidden" name="formhash" value="hash_abc">'
        '</form>'
        '</body></html>';

    test('首次提交返回来路不正确时自动重试并成功', () async {
      var posts = 0;
      String lastBody = '';
      final api = _api((r) {
        if (r.method == 'GET') {
          return http.Response(threadPage, 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        posts++;
        lastBody = r.body;
        if (posts == 1) {
          return _xml("showmessage('submit_invalid', '', {})");
        }
        return _xml("succeedhandle_fastpost('url', '回复成功', {})");
      });
      final res = await api.reply(tid: 152951, fid: 39, message: '内容');
      expect(res.success, isTrue);
      expect(posts, 2);
      // 重试时用新页面的 formhash（不再复用传入的旧值）
      expect(lastBody, contains('formhash'));
    });

    test('连续两次来路不正确给出明确文案', () async {
      final api = _api((r) {
        if (r.method == 'GET') return http.Response(threadPage, 200);
        return _xml("showmessage('submit_invalid', '', {})");
      });
      final res = await api.reply(tid: 152951, fid: 39, message: '内容');
      expect(res.success, isFalse);
      expect(res.message, contains('刷新'));
    });

    test('成功路径不重试', () async {
      var posts = 0;
      final api = _api((r) {
        if (r.method == 'GET') return http.Response(threadPage, 200);
        posts++;
        return _xml("succeedhandle_fastpost('url', '回复成功', {})");
      });
      final res = await api.reply(tid: 152951, fid: 39, message: '内容');
      expect(res.success, isTrue);
      expect(posts, 1);
    });
  });
}
