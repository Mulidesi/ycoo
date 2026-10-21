import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/utils/link_resolver.dart';

void main() {
  test('findForumUrlInText', () {
    final a = LinkResolver.findForumUrlInText('快看这个 https://ycoo.net/thread-153569-1-1.html 不错');
    expect(a.toString(), contains('thread-153569'));
    final b = LinkResolver.findForumUrlInText('www.ycoo.net/forum-2-1.html');
    expect(b!.host, 'ycoo.net');
    final c = LinkResolver.findForumUrlInText('https://pc.sysbbs.com/thread-123-1-1.html?x=1');
    expect(c!.host, 'pc.sysbbs.com');
    expect(LinkResolver.findForumUrlInText('https://example.com/thread-1-1.html'), isNull);
    final r = LinkResolver.resolveInAnySite(Uri.parse('https://ycoo.net/thread-153569-1-1.html'));
    expect(r!.target.id, 153569);
    final r2 = LinkResolver.resolveInAnySite(Uri.parse('https://pc.sysbbs.com/forum-45-1.html'));
    expect(r2!.target.kind, InAppTargetKind.forum);
  });
}
