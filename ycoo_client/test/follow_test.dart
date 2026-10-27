/// P13：用户组等级 / 关注（关注、取关、关注列表、回帖列表）解析与接口回归。
///
/// 真实页面结构（PC 模板，本站 App 拿到的就是这一份）：
///   等级  <a href="home.php?mod=spacecp&amp;ac=usergroup&amp;gid=34" class="km_lvs">Lv.7</a>
///   关注  <a id="followmod_47753"
///            href="home.php?mod=spacecp&amp;ac=follow&amp;op=add&amp;hash=cb349e37&amp;fuid=47753">关注</a>
///   已关注 同一节点 op=del（不带 hash）
///   转播  op=relay，必须排除
///   回帖  <a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=21927&amp;pid=96680">…</a>
///   关注列表 <li><a href="home.php?mod=space&amp;uid=10001">路人甲</a></li>
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

String _threadHtml({bool following = false}) {
  final followHref = following
      ? 'home.php?mod=spacecp&amp;ac=follow&amp;op=del&amp;fuid=47753'
      : 'home.php?mod=spacecp&amp;ac=follow&amp;op=add&amp;hash=cb349e37&amp;fuid=47753';
  return '''
<!DOCTYPE html><html><body>
<input type="hidden" name="formhash" value="cb349e37" />
<div id="post_2899607" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_2899607">正文</td>
  </tr></table></div></div></div>
  <div class="authi">
    <a class="km_name" href="home.php?mod=space&amp;uid=47753">张三</a>
    <a href="home.php?mod=spacecp&amp;ac=usergroup&amp;gid=34" class="km_lvs">Lv.7</a>
    <em id="authorposton2899607">发表于 2026-1-1 10:00</em>
  </div>
</div>
<div class="postactions">
  <a id="followmod_47753" href="$followHref">${following ? '已关注' : '关注'}</a>
  <a id="followmod_47753_relay" href="home.php?mod=spacecp&amp;ac=follow&amp;op=relay&amp;fuid=47753">转播</a>
</div>
</body></html>
''';
}

const String _replyListHtml = '''
<html><body>
<div class="bm_c"><ul class="xl xl2 cl">
  <li>
    <a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=21927&amp;pid=96680">这个版本用着很稳</a>
    <span class="xg1">2026-1-1 12:00</span>
  </li>
  <li>
    <a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=21928&amp;pid=96681">签到功能什么时候支持</a>
    <span class="xg1">2026-1-2 09:30</span>
  </li>
</ul></div>
</body></html>
''';

const String _followListHtml = '''
<html><body>
<ul class="buddy cl">
  <li class="bbda cl">
    <a href="home.php?mod=space&amp;uid=10001"><img src="./data/avatar/000/10/00/1_avatar_middle.jpg" /></a>
    <h4><a href="home.php?mod=space&amp;uid=10001">路人甲</a></h4>
    <p>随便看看</p>
  </li>
  <li class="bbda cl">
    <a href="home.php?mod=space&amp;uid=10002"><img src="./data/avatar/000/10/00/2_avatar_middle.jpg" /></a>
    <h4><a href="home.php?mod=space&amp;uid=10002">路人乙</a></h4>
  </li>
</ul>
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
  group('帖子等级', () {
    test('解析 a.km_lvs 为用户等级', () {
      final d = parseThread(_threadHtml(), tid: 147227);
      expect(d.posts, hasLength(1));
      expect(d.posts.first.level, 'Lv.7');
    });

    test('无徽章时 level 为 null', () {
      final d = parseThread(
        '<html><body><div id="post_1"><div id="postmessage_1">正文</div>'
        '<a class="km_name" href="home.php?mod=space&uid=1">甲</a></div></body></html>',
        tid: 1,
      );
      expect(d.posts.first.level, isNull);
    });
  });

  group('关注入口解析', () {
    test('op=add → 未关注，带 formhash', () {
      final d = parseThread(_threadHtml(), tid: 147227);
      expect(d.followUrl, contains('op=add'));
      expect(d.following, isFalse);
      expect(d.followHash, 'cb349e37');
    });

    test('op=del → 已关注', () {
      final d = parseThread(_threadHtml(following: true), tid: 147227);
      expect(d.followUrl, contains('op=del'));
      expect(d.following, isTrue);
    });

    test('转播链接不算关注入口', () {
      final link = parseFollowLink(
        '<html><body><a id="followmod_1" '
        'href="home.php?mod=spacecp&ac=follow&op=relay&fuid=1">转播</a></body></html>',
        uid: 1,
      );
      expect(link, isNull);
    });

    test('没有 followmod id 时按 ac=follow&fuid 兜底', () {
      final link = parseFollowLink(
        '<html><body>'
        '<input type="hidden" name="formhash" value="abcdef12" />'
        '<a href="home.php?mod=spacecp&ac=follow&op=add&hash=abcdef12&fuid=9">关注TA</a>'
        '</body></html>',
        uid: 9,
      );
      expect(link, isNotNull);
      expect(link!.following, isFalse);
      expect(link.hash, 'abcdef12');
      // uid 不匹配时不误取别人的关注入口
      expect(
        parseFollowLink(
          '<html><body><a href="home.php?mod=spacecp&ac=follow&op=add&hash=abcdef12&fuid=8">关注</a></body></html>',
          uid: 9,
        ),
        isNull,
      );
    });

    test('空间页按 uid 精确匹配', () {
      final link = parseFollowLink(
        '<html><body>'
        '<input type="hidden" name="formhash" value="abcdef12" />'
        '<a id="followmod_1" href="home.php?mod=spacecp&ac=follow&op=add&hash=abcdef12&fuid=1">关注</a>'
        '</body></html>',
        uid: 1,
      );
      expect(link, isNotNull);
      expect(link!.following, isFalse);
      expect(link.hash, 'abcdef12');
      expect(parseFollowLink('<html><body></body></html>', uid: 1), isNull);
    });
  });

  group('关注 / 粉丝列表', () {
    test('解析 uid、昵称、头像与附加文案', () {
      final page = parseFollowList(_followListHtml);
      expect(page.items, hasLength(2));
      expect(page.items.first.uid, 10001);
      expect(page.items.first.username, '路人甲');
      expect(page.items.first.avatar, contains('avatar_middle.jpg'));
      expect(page.items.first.note, '随便看看');
      expect(page.items[1].note, isNull);
    });

    test('自己的回帖列表映射回主题', () {
      final page = parseUserReplyList(_replyListHtml);
      expect(page.items, hasLength(2));
      expect(page.items.first.tid, 21927);
      expect(page.items.first.title, '这个版本用着很稳');
      expect(page.items.first.timeText, '2026-1-1 12:00');
      expect(page.items.first.url, contains('mod=viewthread&tid=21927'));
    });
  });

  group('帖子接口', () {
    test('thread() 保留等级与关注入口（1.1.4 曾在此丢字段）', () async {
      final api = _api((req) {
        expect(req.url.toString(), contains('thread-147227-1-1.html'));
        return http.Response(
          _threadHtml(),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final d = await api.thread(147227);
      expect(d.posts.first.level, 'Lv.7');
      expect(d.followUrl, contains('op=add'));
      expect(d.followUrl, contains('fuid=47753'));
      expect(d.followHash, 'cb349e37');
      expect(d.following, isFalse);
    });
  });

  group('关注接口', () {
    test('关注带 hash 与 fuid，成功透传站点文案', () async {
      http.Request? seen;
      final api = _api((req) {
        seen = req;
        return _xml(
          "<script>succeedhandle_('home.php?mod=space&uid=47753', '关注成功', {});</script>",
        );
      });
      final res = await api.setFollow(uid: 47753, follow: true, hash: 'cb349e37');
      expect(res.success, isTrue);
      expect(res.message, '关注成功');
      expect(seen!.url.queryParameters['ac'], 'follow');
      expect(seen!.url.queryParameters['op'], 'add');
      expect(seen!.url.queryParameters['hash'], 'cb349e37');
      expect(seen!.url.queryParameters['fuid'], '47753');
    });

    test('取关不带 hash', () async {
      http.Request? seen;
      final api = _api((req) {
        seen = req;
        return _xml("<script>succeedhandle_('', '已取消关注', {});</script>");
      });
      final res = await api.setFollow(uid: 47753, follow: false, hash: 'cb349e37');
      expect(res.success, isTrue);
      expect(seen!.url.queryParameters['op'], 'del');
      expect(seen!.url.queryParameters.containsKey('hash'), isFalse);
    });

    test('失败文案透传', () async {
      final api = _api((_) => _xml("<script>errorhandle_('来路不正确');</script>"));
      final res = await api.setFollow(uid: 47753, follow: true, hash: 'cb349e37');
      expect(res.success, isFalse);
      expect(res.message, '来路不正确');
    });

    test('followStatus 读取空间页状态', () async {
      final api = _api((req) {
        expect(req.url.queryParameters['uid'], '47753');
        return http.Response(
          '<html><body><a id="followmod_47753" '
          'href="home.php?mod=spacecp&ac=follow&op=del&fuid=47753">已关注</a></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final link = await api.followStatus(47753);
      expect(link, isNotNull);
      expect(link!.following, isTrue);
    });

    test('回帖 / 关注列表请求路径', () async {
      final paths = <String>[];
      final api = _api((req) {
        paths.add(req.url.toString());
        if (req.url.queryParameters['do'] == 'reply') {
          return http.Response(
            _replyListHtml,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response(
            _followListHtml,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
      });
      final replies = await api.userReplies(uid: 31981);
      expect(replies.items.first.tid, 21927);
      final follows = await api.followList(uid: 31981);
      expect(follows.items, hasLength(2));
      final fans = await api.followList(uid: 31981, followers: true);
      expect(fans.items, hasLength(2));
      expect(paths[0], contains('do=reply'));
      expect(paths[1], contains('do=follow'));
      expect(paths[2], contains('do=follower'));
    });
  });
}
