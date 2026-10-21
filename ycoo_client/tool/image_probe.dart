// ignore_for_file: avoid_print
import 'dart:io';
import 'package:http/http.dart' as http;

String magic(List<int> b) =>
    b.take(4).map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

Future<void> main() async {
  final urls = [
    'https://ycoo.net/data/avatar/000/00/00/01_avatar_middle.jpg',
    'https://ycoo.net/data/attachment/common/template/boardimg_20241216d6f4lsl6.png',
    'https://ycoo.net/data/avatar/noavatar.svg',
    'https://s1.imagehub.cc/images/2026/10/19/6540aa703c836608a8b8e737ff34f2a2.jpg',
  ];
  for (final u in urls) {
    print('=== $u');
    // 1) dart:io HttpClient（Image.network 走的栈）
    final c = HttpClient();
    try {
      final req = await c.getUrl(Uri.parse(u));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0.0.0 Safari/537.36');
      req.headers.set('Referer', 'https://ycoo.net');
      final res = await req.close();
      final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      print('  dart:io  status=${res.statusCode} enc=${res.headers.value('content-encoding')} '
          'type=${res.headers.contentType} len=${bytes.length} magic=${magic(bytes)}');
    } catch (e) {
      print('  dart:io  ERROR $e');
    } finally {
      c.close(force: true);
    }
    // 2) package:http（DiscuzClient 走的栈）
    try {
      final r = await http.get(Uri.parse(u), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0.0.0 Safari/537.36',
        'Referer': 'https://ycoo.net',
      });
      print('  http     status=${r.statusCode} enc=${r.headers['content-encoding']} '
          'type=${r.headers['content-type']} len=${r.bodyBytes.length} magic=${magic(r.bodyBytes)}');
    } catch (e) {
      print('  http     ERROR $e');
    }
  }
}
