import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/thread_list_view.dart';
import 'new_thread_page.dart';

class ThreadListPage extends StatefulWidget {
  const ThreadListPage({super.key, required this.fid, required this.name});

  final int fid;
  final String name;

  @override
  State<ThreadListPage> createState() => _ThreadListPageState();
}

class _ThreadListPageState extends State<ThreadListPage> {
  int _refreshTick = 0;

  Future<void> _compose() async {
    final ok = await openNewThreadFlow(
      context,
      fid: widget.fid,
      boardName: widget.name,
    );
    if (ok && mounted) setState(() => _refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('发帖'),
      ),
      body: ThreadListView(
        key: ValueKey<int>(_refreshTick),
        loader: (page) => api.threads(fid: widget.fid, page: page),
        emptyText: '本版块暂无帖子',
      ),
    );
  }
}
