// 「我的」页积分与统计的解析回归。
//
// 覆盖：
//  1. 移动端接口真实样本（api/mobile/index.php?module=profile）→ 6 个关键数字
//  2. 积分类型编号被站点改过（星币不再固定在 extcredits4）时仍能取到
//  3. HTML 兜底：积分页（星币/经验/贡献/总积分）与空间页（帖子/关注/粉丝）
//  4. 异常输入不崩：非 JSON、空 space、游客页
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

/// 真实样本（2026-10-21 抓取 uid=31981），与截图数字一致：
/// 星币 2026 / 经验 8456 / 积分 9207 / 帖子 714 / 关注 20 / 粉丝 188
const _realSample = '''
{"Version":"4","Charset":"UTF-8","Variables":{
 "cookiepre":"YPSa_2132_","auth":null,"saltkey":"oNPUA5Ev",
 "member_uid":"31981","member_username":"木里得斯",
 "member_avatar":"./data/avatar/000/31/98/1_avatar_middle.jpg",
 "groupid":"7","formhash":"08f0309c",
 "extcredits":{"2":{"title":"经验"},"3":{"title":"贡献"},"4":{"title":"星币"}},
 "space":{
   "uid":"31981","username":"木里得斯","groupid":"34","regdate":"2025-10-1 12:03",
   "credits":"9207",
   "extcredits1":"0","extcredits2":"8456","extcredits3":"1506","extcredits4":"2026",
   "extcredits5":"0","extcredits6":"0","extcredits7":"0","extcredits8":"0",
   "friends":"1","posts":"714","threads":"39","digestposts":"0",
   "views":"3012","oltime":"362","feeds":"15",
   "follower":"188","following":"20","newfollower":"179",
   "spacedescription":""
 }}}
''';

void main() {
  group('parseProfileApi', () {
    test('真实样本：积分体系', () {
      final p = parseProfileApi(_realSample)!;
      expect(p.uid, 31981);
      expect(p.username, '木里得斯');
      expect(p.points, 9207, reason: '总积分');
      expect(p.coins, 2026, reason: '星币');
      expect(p.exp, 8456, reason: '经验');
      expect(p.contribution, 1506, reason: '贡献');
    });

    test('真实样本：社区统计', () {
      final p = parseProfileApi(_realSample)!;
      expect(p.posts, 714, reason: '帖子');
      expect(p.following, 20, reason: '关注');
      expect(p.followers, 188, reason: '粉丝');
      expect(p.threads, 39);
      expect(p.friends, 1);
      expect(p.onlineHours, 362);
      expect(p.views, 3012);
      expect(p.feeds, 15);
      expect(p.registerTime, '2025-10-1 12:03');
    });

    test('头像取 member_avatar，noavatar 视为没有', () {
      final p = parseProfileApi(_realSample)!;
      expect(p.avatar, contains('/data/avatar/'));

      final noAvatar = _realSample.replaceAll(
        './data/avatar/000/31/98/1_avatar_middle.jpg',
        './data/avatar/noavatar.svg',
      );
      expect(parseProfileApi(noAvatar)!.avatar, isNull);
    });

    test('积分编号被站点改过也能按名称取到', () {
      // 星币挪到 extcredits5、经验挪到 extcredits6，仍应按 title 对上号
      const moved = '''
{"Variables":{
 "member_uid":"31981",
 "extcredits":{"5":{"title":"星币"},"6":{"title":"经验"},"3":{"title":"贡献"}},
 "space":{"uid":"31981","username":"木里得斯","credits":"9207",
   "extcredits3":"1506","extcredits5":"2026","extcredits6":"8456"}
}}
''';
      final p = parseProfileApi(moved)!;
      expect(p.coins, 2026);
      expect(p.exp, 8456);
      expect(p.contribution, 1506);
      expect(p.points, 9207);
    });

    test('缺少 extcredits 映射时回退站点约定（2 经验 / 3 贡献 / 4 星币）', () {
      final noMap = _realSample.replaceFirst(
        '"extcredits":{"2":{"title":"经验"},"3":{"title":"贡献"},"4":{"title":"星币"}},',
        '',
      );
      final p = parseProfileApi(noMap)!;
      expect(p.coins, 2026);
      expect(p.exp, 8456);
    });

    test('异常输入返回 null，不抛异常', () {
      expect(parseProfileApi(''), isNull);
      expect(parseProfileApi('<html>提示信息</html>'), isNull);
      expect(parseProfileApi('{"Variables":{}}'), isNull);
      expect(parseProfileApi('{"Variables":{"space":{}}}'), isNull,
          reason: 'uid 与用户名都为空');
      expect(parseProfileApi(jsonEncode({'Variables': {'space': 'x'}})), isNull);
    });
  });

  group('parseProfile（HTML 兜底）', () {
    test('积分页：星币 / 经验 / 贡献 / 总积分 + 公式', () {
      const html = '''
<html><body>
<div class="creditp">
  <p>星币: 2026</p>
  <p>经验: 8456</p>
  <p>贡献: 1506</p>
  <p>积分: 9207 ( 总积分= 发帖数 X 1.5 + 主题数 X 1.5 + 精华帖数 X 5 + 在线时间(小时) X 5 + 贡献 X 4 + 经验 / 5 )</p>
</div>
<table><tr><td>购买主题</td><td>星币 -5</td></tr></table>
</body></html>
''';
      final p = parseProfile(html, fallbackUid: 31981)!;
      expect(p.coins, 2026, reason: '不能被积分记录里的 -5 抢走');
      expect(p.exp, 8456);
      expect(p.contribution, 1506);
      expect(p.points, 9207);
      expect(p.creditFormula, contains('总积分'));
    });

    test('空间页：帖子 / 关注 / 粉丝', () {
      const html = '''
<html><body>
<ul class="cl bbda pbm">
  <li><a href="home.php?mod=space&uid=31981&do=thread">714</a><em>帖子</em></li>
  <li><a href="home.php?mod=space&uid=31981&do=friend">20</a><em>关注</em></li>
  <li><a href="home.php?mod=space&uid=31981&do=friend&type=friend">188</a><em>粉丝</em></li>
</ul>
<script>var discuz_uid = '31981';</script>
</body></html>
''';
      final p = parseProfile(html, fallbackUid: 31981)!;
      expect(p.posts, 714);
      expect(p.following, 20);
      expect(p.followers, 188);
    });
  });

  group('parseDiscuzUid', () {
    test('从页面 JS 变量取当前 UID', () {
      expect(parseDiscuzUid("var discuz_uid = '31981', VERHASH = 'nfC';"), 31981);
      expect(parseDiscuzUid("discuz_uid = '0'"), isNull, reason: '游客');
      expect(parseDiscuzUid('没有该变量'), isNull);
    });
  });

  group('ForumApi.me()', () {
    /// 资料页：带登录态、discuz_uid、头部用户链接、头像
    const profileHtml = '''
<html><head><title>木里得斯的个人资料</title></head><body>
<div id="um"><a href="home.php?mod=space&uid=31981">木里得斯</a>
<a href="member.php?mod=logging&action=logout">退出</a></div>
<img class="user_avatar" src="./data/avatar/000/31/98/1_avatar_middle.jpg" />
<p>用户组: 注册会员</p>
<script>var discuz_uid = '31981';</script>
</body></html>
''';

    test('先取 UID，再用移动端接口拿准确积分与统计', () async {
      final calls = <String>[];
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          calls.add(req.url.toString());
          if (req.url.path.contains('api/mobile')) {
            return http.Response.bytes(utf8.encode(_realSample), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response.bytes(utf8.encode(profileHtml), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      ));

      final u = (await api.me())!;
      expect(calls.any((c) => c.contains('module=profile&uid=31981')), isTrue,
          reason: '应调用移动端接口');
      expect(u.uid, 31981);
      expect(u.coins, 2026);
      expect(u.exp, 8456);
      expect(u.points, 9207);
      expect(u.posts, 714);
      expect(u.following, 20);
      expect(u.followers, 188);
      expect(u.group, '注册会员', reason: '用户组由 HTML 补齐');
      expect(u.avatar, contains('/data/avatar/'), reason: '头像由接口或 HTML 补齐');
    });

    test('接口挂掉时退回 HTML 解析，不返回 null', () async {
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async {
          if (req.url.path.contains('api/mobile')) {
            return http.Response('<br />Fatal error</b>', 500);
          }
          return http.Response.bytes(utf8.encode(profileHtml), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
      ));
      final u = (await api.me())!;
      expect(u.uid, 31981);
      expect(u.username, '木里得斯');
      expect(u.group, '注册会员');
      expect(u.points, isNull, reason: 'HTML 里没有积分就只能留空，不能编造');
    });

    test('游客页返回 null', () async {
      final api = ForumApi(DiscuzClient(
        client: MockClient((req) async => http.Response.bytes(
              utf8.encode('<html><body><form id="loginform">'
                  '<input name="loginsubmit" value="yes" /></form></body></html>'),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            )),
      ));
      expect(await api.me(), isNull);
    });
  });
}
