import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/core/utils/link_resolver.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/common.dart';
import 'package:ycoo_client/ui/widgets/thread_tile.dart';

const _selfSample = '''
{"Version":"4","Charset":"UTF-8","Variables":{
 "member_uid":"31981","member_username":"木里得斯",
 "member_avatar":"./data/avatar/000/31/98/1_avatar_middle.jpg",
 "groupid":"7",
 "group":{"grouptitle":"大会员","stars":"5"},
 "extcredits":{"2":{"title":"经验"},"3":{"title":"贡献"},"4":{"title":"星币"}},
 "space":{
   "uid":"31981","username":"木里得斯","credits":"9207",
   "extcredits2":"8456","extcredits3":"1506","extcredits4":"2026",
   "friends":"1","posts":"714","threads":"39",
   "views":"3012","follower":"188","following":"20"
 }}}
''';

const _otherSample = '''
{"Version":"4","Charset":"UTF-8","Variables":{
 "member_uid":"31981","member_username":"木里得斯",
 "member_avatar":"./data/avatar/000/31/98/1_avatar_middle.jpg",
 "group":{"grouptitle":"大会员","stars":"5"},
 "extcredits":{"2":{"title":"经验"},"3":{"title":"贡献"},"4":{"title":"星币"}},
 "space":{
   "uid":"10001","username":"路人甲","credits":"120",
   "extcredits2":"10","extcredits3":"2","extcredits4":"8",
   "friends":"0","posts":"12","threads":"3",
   "views":"40","follower":"4","following":"1"
 }}}
''';

const _otherHtml = '''
<html><head><title>路人甲的个人资料</title></head><body>
<img class="user_avatar" src="./data/avatar/000/10/00/1_avatar_middle.jpg" />
<p>用户组: 注册会员</p>
<p>等级: 中级会员</p>
</body></html>
''';

const _kmlistHtml = '''
<html><body>
<ul>
<li id="normalthread_153502" class="kmlist">
  <a class="kmtit" href="thread-153502-1-1.html"><span class="km_subject">主题甲</span></a>
  <a href="space-uid-10001.html">路人甲</a>
  <span class="kmpl">3</span>
  <span class="kmck">21</span>
  <span class="kmtime">发表于 昨天 21:20</span>
</li>
</ul>
<div>共 2 页</div>
</body></html>
''';

const _spaceXlHtml = '''
<html><body>
<div class="xl">
  <li><a href="thread-111-1-1.html" title="空间主题一">空间主题一</a><em class="xg1">2026-10-1</em></li>
  <li><a href="thread-222-1-1.html">空间主题二</a></li>
</div>
</body></html>
''';

void main() {
  group('UserProfile.replies', () {
    test('posts - threads', () {
      const p = UserProfile(uid: 1, username: 'a', posts: 714, threads: 39);
      expect(p.replies, 675);
    });
    test('缺字段为 null', () {
      const p = UserProfile(uid: 1, username: 'a', posts: 10);
      expect(p.replies, isNull);
    });
    test('负差按 0', () {
      const p = UserProfile(uid: 1, username: 'a', posts: 1, threads: 5);
      expect(p.replies, 0);
    });
  });

  group('parseProfileApi 查看用户', () {
    test('查看自己时取 grouptitle 与等级', () {
      final p = parseProfileApi(_selfSample)!;
      expect(p.group, '大会员');
      expect(p.level, 'Lv.5');
      expect(p.avatar, contains('/data/avatar/'));
    });

    test('查看他人时不用当前登录用户的头像和用户组', () {
      final p = parseProfileApi(_otherSample)!;
      expect(p.uid, 10001);
      expect(p.username, '路人甲');
      expect(p.avatar, isNull);
      expect(p.group, isNull);
      expect(p.threads, 3);
      expect(p.replies, 9);
    });
  });

  group('parseProfile HTML 等级', () {
    test('有独立等级时用等级文案', () {
      final p = parseProfile(_otherHtml, fallbackUid: 10001)!;
      expect(p.group, '注册会员');
      expect(p.level, '中级会员');
    });
    test('无独立等级时回落用户组', () {
      final p = parseProfile(
        '<html><body><p>用户组: 大会员</p></body></html>',
        fallbackUid: 1,
        fallbackName: 'a',
      )!;
      expect(p.group, '大会员');
      expect(p.level, '大会员');
    });

    test('跳过游客 noavatar 占位图，取真实头像', () {
      const html = '''
<html><body>
  <img class="user_avatar" src="./data/avatar/noavatar.svg" />
  <div class="kmavt">
    <a href="space-uid-31981.html">
      <img class="user_avatar" src="./data/avatar/000/03/19/81_avatar_middle.jpg" />
    </a>
  </div>
</body></html>
''';
      final p = parseProfile(html, fallbackUid: 31981, fallbackName: '木里得斯')!;
      expect(p.avatar, contains('/data/avatar/000/03/19/81_avatar_middle.jpg'));
      expect(p.avatar, isNot(contains('noavatar')));
    });
  });

  group('avatarUrlFromUid', () {
    test('9 位补零后按 3/2/2/2 切目录', () {
      expect(avatarUrlFromUid(31981), contains('/data/avatar/000/03/19/81_avatar_middle.jpg'));
      expect(avatarUrlFromUid(10001), contains('/data/avatar/000/01/00/01_avatar_middle.jpg'));
      expect(avatarUrlFromUid(0), isNull);
    });
  });

  group('parseUserThreadList', () {
    test('comiis kmlist', () {
      final page = parseUserThreadList(_kmlistHtml);
      expect(page.items, hasLength(1));
      expect(page.items.first.tid, 153502);
      expect(page.items.first.title, '主题甲');
      expect(page.items.first.replies, 3);
      expect(page.items.first.views, 21);
      expect(page.totalPages, 2);
    });
    test('空间页 xl 结构', () {
      final page = parseUserThreadList(_spaceXlHtml);
      expect(page.items.map((e) => e.tid), [111, 222]);
      expect(page.items.first.title, '空间主题一');
    });
    test('空空间页', () {
      final page = parseUserThreadList('<html><body>还没有相关的帖子</body></html>');
      expect(page.items, isEmpty);
      expect(page.totalPages, 1);
    });
  });

  group('ForumApi.userProfile / userThreads', () {
    test('JSON 成功 + HTML 补 group', () async {
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          if (req.url.path.contains('api/mobile')) {
            return http.Response.bytes(utf8.encode(_otherSample), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response.bytes(utf8.encode(_otherHtml), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      ));
      final u = await api.userProfile(10001);
      expect(u.uid, 10001);
      expect(u.points, 120);
      expect(u.group, '注册会员');
      expect(u.level, '中级会员');
      expect(u.avatar, contains('/data/avatar/'));
    });

    test('JSON 500 退回 HTML', () async {
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          if (req.url.path.contains('api/mobile')) {
            return http.Response('fatal', 500);
          }
          return http.Response.bytes(utf8.encode(_otherHtml), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      ));
      final u = await api.userProfile(10001);
      expect(u.username, '路人甲');
      expect(u.group, '注册会员');
    });

    test('两边失败抛错', () async {
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async => http.Response('oops', 500)),
      ));
      expect(() => api.userProfile(10001), throwsA(isA<ForumException>()));
    });

    test('空间不存在', () async {
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          if (req.url.path.contains('api/mobile')) {
            return http.Response('{}', 200);
          }
          return http.Response.bytes(
            utf8.encode('<html>抱歉，您指定的用户空间不存在</html>'),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      ));
      expect(
        () => api.userProfile(9),
        throwsA(isA<ForumException>().having((e) => e.message, 'msg', contains('不存在'))),
      );
    });

    test('HTML 只有 noavatar 时按 UID 拼头像', () async {
      const html = '''
<html><body><img class="user_avatar" src="./data/avatar/noavatar.svg" />
<p>用户组: 注册会员</p></body></html>
''';
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          if (req.url.path.contains('api/mobile')) {
            return http.Response.bytes(utf8.encode(_otherSample), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response.bytes(utf8.encode(html), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      ));
      final u = await api.userProfile(10001);
      expect(u.avatar, contains('/data/avatar/000/01/00/01_avatar_middle.jpg'));
    });

    test('游客访问主题列表提示需登录', () async {
      const html = '<html><body>提示信息 请先登录后才能继续浏览</body></html>';
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async => http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            )),
      ));
      expect(
        () => api.userThreads(uid: 10001),
        throwsA(isA<ForumException>().having((e) => e.message, 'msg', contains('登录'))),
      );
    });

    test('主题列表 URL 带 page', () async {
      final urls = <String>[];
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          urls.add(req.url.toString());
          return http.Response.bytes(utf8.encode(_kmlistHtml), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      ));
      final p1 = await api.userThreads(uid: 10001, page: 1);
      final p2 = await api.userThreads(uid: 10001, page: 2);
      expect(p1.items, isNotEmpty);
      expect(p2.page, 2);
      expect(urls[0], contains('uid=10001'));
      expect(urls[0], contains('do=thread'));
      expect(urls[1], contains('page=2'));
    });
  });

  group('LinkResolver 用户空间', () {
    test('space-uid 与 uid 查询', () {
      final a = LinkResolver.resolveInAnySite(Uri.parse('https://ycoo.net/space-uid-10001.html'));
      expect(a!.target.kind, InAppTargetKind.user);
      expect(a.target.id, 10001);
      final b = LinkResolver.resolveInAnySite(
        Uri.parse('https://ycoo.net/home.php?mod=space&uid=10001&do=profile'),
      );
      expect(b!.target.kind, InAppTargetKind.user);
      expect(b.target.id, 10001);
    });
  });

  group('ThreadTile 头像点击', () {
    testWidgets('点头像只触发 onAvatarTap', (tester) async {
      var card = 0;
      var avatar = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ThreadTile(
            item: const ThreadItem(
              tid: 1,
              title: '标题',
              url: '/t',
              author: '甲',
              authorId: 9,
            ),
            onTap: () => card++,
            onAvatarTap: () => avatar++,
          ),
        ),
      ));
      await tester.tap(find.byType(Avatar));
      await tester.pump();
      expect(avatar, 1);
      expect(card, 0);
    });
  });
}
