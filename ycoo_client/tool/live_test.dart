// ignore_for_file: avoid_print
// 真机联调：直接请求 ycoo.net 验证解析与接口。
// 运行：dart run tool/live_test.dart [--login]
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';

Future<void> main(List<String> args) async {
  final api = ForumApi(DiscuzClient());
  final doLogin = args.contains('--login');

  print('== 1. 版块 ==');
  final groups = await api.boards();
  print('分组 ${groups.length} 个，版块 ${groups.fold<int>(0, (a, g) => a + g.boards.length)} 个');
  for (final g in groups.take(2)) {
    print('  ${g.name}: ${g.boards.map((b) => b.name).join(' / ')}');
  }

  print('\n== 2. 版块帖子列表 ==');
  final tp = await api.threads(fid: 2, page: 1);
  print('fid=2 第1页 ${tp.items.length} 条，共 ${tp.totalPages} 页');
  for (final t in tp.items.take(3)) {
    print('  [${t.tid}] ${t.title} | ${t.author} 回复${t.replies} ${t.timeText}');
  }

  print('\n== 3. 导读最新 ==');
  final g = await api.guide('newthread');
  print('${g.items.length} 条');
  for (final t in g.items.take(2)) {
    print('  [${t.tid}] ${t.title}');
  }

  print('\n== 4. 帖子详情 ==');
  final d = await api.thread(tp.items.first.tid);
  print('标题: ${d.title}');
  print('fid=${d.fid} 楼层=${d.posts.length} 页数=${d.totalPages} 隐藏=${d.isLocked} 回复可见=${d.needsReply}');
  if (d.posts.isNotEmpty) {
    print('楼主: ${d.posts.first.author} ${d.posts.first.floor} ${d.posts.first.timeText}');
    print('正文长度: ${d.posts.first.contentHtml.length}');
  }

  print('\n== 5. 签到状态 ==');
  final s = await api.signStatus();
  print('今日已签到=${s.signedToday} 连续=${s.streakDays} 今日人数=${s.todayCount}');

  if (doLogin) {
    print('\n== 6. 登录测试 ==');
    final r = await api.login('木里得斯', '123456asd');
    print('success=${r.success} message=${r.message} 剩余尝试=${r.remainingAttempts}');
    if (r.success) {
      final me = await api.me();
      print('当前用户: ${me?.username} uid=${me?.uid} 积分=${me?.credits} 用户组=${me?.group}');
      final s2 = await api.signStatus();
      print('签到状态: 已签到=${s2.signedToday} 连续=${s2.streakDays}');
      if (args.contains('--sign')) {
        print('\n== 7. 执行签到 ==');
        final sr = await api.sign();
        print('success=${sr.success} message=${sr.message}');
        final s3 = await api.signStatus();
        print('签到后: 已签到=${s3.signedToday} 连续=${s3.streakDays} 今日人数=${s3.todayCount}');
      }
    }
  }
}
