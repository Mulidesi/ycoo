/// 头像点击：他人进个人中心，自己切到「我的」Tab。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../ui/pages/user_space_page.dart';

void openUserFromAvatar(
  BuildContext context, {
  int? uid,
  String? username,
}) {
  if (uid == null || uid <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开该用户资料')),
    );
    return;
  }
  final st = context.read<AppState>();
  final me = st.user?.uid ?? 0;
  if (me > 0 && uid == me) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    st.selectHomeTab(2);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UserSpacePage(uid: uid, username: username),
    ),
  );
}
