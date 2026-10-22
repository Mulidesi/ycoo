import '../../models/models.dart';

/// 标题是否命中任一过滤关键词（忽略大小写与首尾空格）。
bool matchesPostKeyword(String title, String keyword) {
  final k = keyword.trim().toLowerCase();
  if (k.isEmpty) return false;
  return title.toLowerCase().contains(k);
}

/// 过滤帖子列表：只隐藏标题命中关键词的帖子，正文不受影响。
List<ThreadItem> filterThreadsByKeywords(
  Iterable<ThreadItem> items, {
  required bool enabled,
  required List<String> keywords,
}) {
  if (!enabled || keywords.isEmpty) return List<ThreadItem>.of(items);
  return <ThreadItem>[
    for (final item in items)
      if (!keywords.any((k) => matchesPostKeyword(item.title, k))) item,
  ];
}
