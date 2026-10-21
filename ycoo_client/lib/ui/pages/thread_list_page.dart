import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/thread_list_view.dart';

class ThreadListPage extends StatelessWidget {
  const ThreadListPage({super.key, required this.fid, required this.name});

  final int fid;
  final String name;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ThreadListView(
        loader: (page) => api.threads(fid: fid, page: page),
        emptyText: '本版块暂无帖子',
      ),
    );
  }
}
