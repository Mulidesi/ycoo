// ignore_for_file: avoid_print
// 离线回归测试：直接用 curl 抓下来的真实页面验证解析器。
// 运行：dart run tool/parse_test.dart ../recon
import 'dart:io';

import 'package:ycoo_client/data/parsers.dart';

void main(List<String> args) {
  final dir = args.isEmpty ? '../recon' : args.first;
  String read(String name) => File('$dir/$name').readAsStringSync();

  print('===== 版块 =====');
  final groups = parseBoards(read('forum.html'));
  for (final g in groups) {
    print('gid=${g.gid} ${g.name} -> ${g.boards.length} 个版块');
    for (final b in g.boards) {
      print('   [${b.fid}] ${b.name} 今日${b.todayPosts} 主题${b.threads} 帖${b.posts} '
          '${b.isPrivate ? "私密" : ""} icon=${b.icon != null} last=${b.lastPost}');
    }
  }

  print('\n===== 版块帖子列表 =====');
  final tp = parseThreadList(read('forum2.html'));
  print('page=${tp.page} total=${tp.totalPages} items=${tp.items.length}');
  for (final t in tp.items.take(6)) {
    print('   ${t.tid} ${t.title} | ${t.author} 回复${t.replies} 查看${t.views} '
        '${t.timeText} ${t.typeName ?? ""} 附件=${t.hasAttachment} fid=${t.fid} 置顶=${t.isSticky}');
  }

  print('\n===== 导读最新 =====');
  final g = parseThreadList(read('guide.html'));
  print('items=${g.items.length} total=${g.totalPages}');
  for (final t in g.items.take(3)) {
    print('   ${t.tid} ${t.title} | ${t.author} ${t.timeText}');
  }

  print('\n===== 帖子详情（免费贴）=====');
  final d = parseThread(read('thread_free.html'), tid: 152951);
  print('title=${d.title} fid=${d.fid} posts=${d.posts.length} pages=${d.totalPages}');
  print('locked=${d.isLocked} reply=${d.needsReply} buy=${d.needsPurchase} login=${d.needsLogin}');
  for (final p in d.posts.take(2)) {
    print('   ${p.author} ${p.floor} ${p.timeText} uid=${p.authorId} '
        'contentLen=${p.contentHtml.length}');
    print('   plain: ${htmlToPlainText(p.contentHtml, maxLen: 100)}');
  }

  print('\n===== 帖子详情（购买贴）=====');
  final d2 = parseThread(read('thread.html'), tid: 152947);
  print('title=${d2.title} fid=${d2.fid} posts=${d2.posts.length}');
  print('locked=${d2.isLocked} reply=${d2.needsReply} buy=${d2.needsPurchase} '
      'login=${d2.needsLogin} text=${d2.lockedText}');

  print('\n===== 签到页 =====');
  final s = parseSignPage(read('sign.html'));
  print('signed=${s.signedToday} streak=${s.streakDays} today=${s.todayCount} '
      'rank=${s.rankText} reward=${s.rewardText}');

  print('\n===== formhash / 登录页 =====');
  print('formhash=${parseFormhash(read('login2.html'))} '
      'loginhash=${parseLoginhash(read('login2.html'))}');

  print('\n===== 登录响应 =====');
  final msg = parseAjaxMessage(read('login2.xml'));
  print('msg=$msg remaining=${parseRemainingAttempts(msg)}');

  print('\n===== 头部用户（游客页）=====');
  print('user=${parseHeaderUser(read('forum.html'))} logged=${looksLoggedIn(read('forum.html'))}');
}
