// ignore_for_file: avoid_print

/// 「我的」页积分 / 统计的离线断言 + 可选真实联调。
///
/// 用法：
///   dart run tool/stats_check.dart ../recon        # 只用抓下来的样本断言
///   dart run tool/stats_check.dart ../recon --live  # 额外打一次真实接口
library;

import 'dart:io';

import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

var _failed = 0;

void _expect(String label, bool ok, [String detail = '']) {
  print('${ok ? "  ok  " : "  FAIL"}  $label${detail.isEmpty ? "" : "  -> $detail"}');
  if (!ok) _failed++;
}

Future<void> main(List<String> args) async {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');
  final live = args.contains('--live');

  // ---- 1. 抓下来的真实接口样本 ----
  print('[api_profile_31981.json] 移动端接口样本');
  final f = File('${dir.path}/api_profile_31981.json');
  if (!f.existsSync()) {
    print('  skip  样本不存在');
  } else {
    final p = parseProfileApi(f.readAsStringSync());
    if (p == null) {
      _expect('样本可解析', false);
    } else {
      _expect('uid = 31981', p.uid == 31981, '${p.uid}');
      _expect('用户名 = 木里得斯', p.username == '木里得斯', p.username);
      _expect('星币 = 2026', p.coins == 2026, '${p.coins}');
      _expect('经验 = 8456', p.exp == 8456, '${p.exp}');
      _expect('贡献 = 1506', p.contribution == 1506, '${p.contribution}');
      _expect('积分 = 9207', p.points == 9207, '${p.points}');
      _expect('帖子 = 714', p.posts == 714, '${p.posts}');
      _expect('关注 = 20', p.following == 20, '${p.following}');
      _expect('粉丝 = 188', p.followers == 188, '${p.followers}');
      _expect('主题 = 39', p.threads == 39, '${p.threads}');
      _expect('在线 = 362 小时', p.onlineHours == 362, '${p.onlineHours}');
      _expect('注册时间 = 2025-10-1 12:03', p.registerTime == '2025-10-1 12:03', '${p.registerTime}');
    }
  }

  // ---- 2. 真实接口 ----
  if (live) {
    print('[live] api/mobile/index.php?module=profile&uid=31981');
    final api = ForumApi(DiscuzClient());
    final p = await api.userStats(31981);
    if (p == null) {
      _expect('接口可用', false, '返回 null（可能被墙/改版）');
    } else {
      _expect('uid = 31981', p.uid == 31981, '${p.uid}');
      _expect('用户名非空', p.username.isNotEmpty, p.username);
      _expect('星币 > 0', (p.coins ?? 0) > 0, '${p.coins}');
      _expect('经验 > 0', (p.exp ?? 0) > 0, '${p.exp}');
      _expect('积分 > 0', (p.points ?? 0) > 0, '${p.points}');
      _expect('帖子 > 0', (p.posts ?? 0) > 0, '${p.posts}');
      _expect('粉丝 > 0', (p.followers ?? 0) > 0, '${p.followers}');
      print('  实时值: 星币=${p.coins} 经验=${p.exp} 贡献=${p.contribution} 积分=${p.points} '
          '帖子=${p.posts} 关注=${p.following} 粉丝=${p.followers}');
    }
  }

  print(_failed == 0 ? '\nALL PASS' : '\n$_failed FAILED');
  if (_failed != 0) exitCode = 1;
}
