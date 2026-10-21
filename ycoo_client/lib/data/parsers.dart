/// 纯 Dart 的 Discuz! 页面解析器。
/// 之所以与 UI 分离，是为了能直接用 curl 抓下来的真实页面做离线回归测试。
library;

import 'dart:math' as math;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/models.dart';

/// 当前站点根地址（不带尾部斜杠）。
///
/// 论坛有 ycoo.net / pc.sysbbs.com 两个域名，用户可在设置里切换主域名；
/// 解析、请求、图片 Referer 都以该值为准。默认 ycoo.net。
String kBaseUrl = 'https://ycoo.net';

/// 切换主域名（设置页「站点与网络」调用）。
void setBaseUrl(String url) {
  final u = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  if (u.isNotEmpty) kBaseUrl = u;
}

String absoluteUrl(String? href) {
  if (href == null || href.isEmpty) return kBaseUrl;
  if (href.startsWith('http://') || href.startsWith('https://')) return href;
  if (href.startsWith('//')) return 'https:$href';
  return Uri.parse(kBaseUrl).resolve(href).toString();
}

/// `div.locked` 里表示「正文真的被挡住了」的措辞。
///
/// 购买成功后的信息栏（「付费主题, 价格: 5 星币」）不含这些词，
/// 借此把「待购买」与「已购买」区分开。
final RegExp _lockedBlockerRe = RegExp(
  r'才能浏览|才能查看|才能下载|需向作者支付|回复后才|回复后可见|回复可见'
  r'|登录后可见|登录后才能|登录后浏览|购买后可见|购买后才能|仅作者可见|需要购买',
);

String _text(Element? e) => e?.text.replaceAll('\u00a0', ' ').trim() ?? '';

/// 从附件区文本里抽文件大小，兼容两种模板写法：
///   `<em class="xg1">(13.83 KB, 下载次数: 531)</em>`
///   `<p>5.92 KB, 下载次数: 6</p>`
String? _attachSize(String text) =>
    RegExp(r'([\d.]+\s*[KMGT]B)').firstMatch(text)?.group(1)?.trim();

int _toInt(String? s) {
  if (s == null) return 0;
  final t = s.replaceAll(RegExp(r'[^\d.万亿]'), '');
  if (t.isEmpty) return 0;
  if (t.endsWith('万')) {
    return (double.tryParse(t.substring(0, t.length - 1)) ?? 0).toInt() * 10000;
  }
  if (t.endsWith('亿')) {
    return (double.tryParse(t.substring(0, t.length - 1)) ?? 0).toInt() * 100000000;
  }
  return int.tryParse(t.split('.').first) ?? 0;
}

int? _uidFromHref(String? href) {
  if (href == null) return null;
  final m = RegExp(r'(?:space-uid-|uid=)(\d+)').firstMatch(href);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// 版块首页：分组 + 版块
List<BoardGroup> parseBoards(String html) {
  final doc = html_parser.parse(html);
  final groups = <BoardGroup>[];
  var currentGid = 0;
  var currentName = '';
  var buffer = <Board>[];

  void flush() {
    if (buffer.isNotEmpty) {
      groups.add(BoardGroup(gid: currentGid, name: currentName, boards: List.of(buffer)));
      buffer = <Board>[];
    }
  }

  final nodes = doc.querySelectorAll('h2, div[id^="category_"]');
  for (final el in nodes) {
    if (el.localName == 'h2') {
      final a = el.querySelector('a[href*="gid="]');
      if (a == null) continue;
      flush();
      final m = RegExp(r'gid=(\d+)').firstMatch(a.attributes['href'] ?? '');
      currentGid = m == null ? 0 : int.parse(m.group(1)!);
      currentName = _text(a);
      continue;
    }
    // category div
    for (final dl in el.querySelectorAll('dl')) {
      final dt = dl.querySelector('dt');
      final a = dt?.querySelector('a[href*="forum-"]');
      if (a == null) continue;
      final href = a.attributes['href'] ?? '';
      final fidm = RegExp(r'forum-(\d+)-1\.html').firstMatch(href);
      if (fidm == null) continue;
      final fid = int.parse(fidm.group(1)!);

      final ems = dl.querySelectorAll('dd em');
      var threads = 0;
      for (final em in ems) {
        final t = _text(em);
        if (t.startsWith('主题')) threads = _toInt(t);
      }
      final postsSpan = dl.querySelector('dd em span[title]');
      final posts = _toInt(postsSpan?.attributes['title'] ?? postsSpan?.text);
      final ddText = dl.querySelectorAll('dd').map(_text).join(' ');

      final iconImg = dl.parent?.querySelector('div.fl_icn_g img') ??
          dl.parent?.querySelector('img');
      buffer.add(Board(
        fid: fid,
        name: _text(a),
        icon: absoluteUrl(iconImg?.attributes['src']),
        todayPosts: _toInt(_text(dt?.querySelector('em.kmtoday'))),
        threads: threads,
        posts: posts,
        lastPost: _text(dl.querySelector('a.comiis_lastpost_ico')),
        isPrivate: ddText.contains('私密'),
      ));
    }
  }
  flush();
  return groups;
}

/// 版块帖子列表 / 导读列表（模板一致）
ThreadPage parseThreadList(String html, {int page = 1}) {
  final doc = html_parser.parse(html);
  final items = <ThreadItem>[];

  for (final li in doc.querySelectorAll(
      'li[id^="normalthread_"], li[id^="stickthread_"], li.kmlist')) {
    final id = li.id;
    final a = li.querySelector('a.kmtit') ?? li.querySelector('a[href*="thread-"]');
    if (a == null) continue;

    var tid = int.tryParse(id.split('_').last) ?? 0;
    if (tid == 0) {
      final m = RegExp(r'thread-(\d+)-').firstMatch(a.attributes['href'] ?? '');
      tid = m == null ? 0 : int.parse(m.group(1)!);
    }
    if (tid == 0) continue;

    final subject = _text(a.querySelector('span.km_subject'));
    var title = subject.isNotEmpty ? subject : _text(a);
    if (title.isEmpty) title = (a.attributes['title'] ?? '').trim();
    if (title.isEmpty) continue;

    String? author;
    int? authorId;
    for (final ua in li.querySelectorAll('a[href*="space-uid-"]')) {
      final t = _text(ua);
      if (t.isNotEmpty) {
        author = t;
        authorId = _uidFromHref(ua.attributes['href']);
        break;
      }
    }
    final avatarImg = li.querySelector('img.user_avatar');
    final avatar = avatarImg?.attributes['src'] ?? avatarImg?.attributes['data-original'];

    var fid = 0;
    final typeLink = li.querySelector('a.kmbg');
    if (typeLink != null) {
      final m = RegExp(r'forum-(\d+)-1\.html').firstMatch(typeLink.attributes['href'] ?? '');
      if (m != null) fid = int.parse(m.group(1)!);
    }
    if (fid == 0) {
      final m = RegExp(r'fid=(\d+)').firstMatch(li.innerHtml);
      if (m != null) fid = int.parse(m.group(1)!);
    }

    items.add(ThreadItem(
      tid: tid,
      title: title,
      url: absoluteUrl(a.attributes['href']),
      author: author,
      authorId: authorId,
      avatar: avatar == null ? null : absoluteUrl(avatar),
      replies: _toInt(_text(li.querySelector('span.kmpl'))),
      views: _toInt(_text(li.querySelector('span.kmck'))),
      timeText: _text(li.querySelector('.kmtime')).replaceFirst(RegExp(r'^发表于\s*'), ''),
      typeName: _text(li.querySelector('.kmbg')),
      hasAttachment: li.querySelector('i.fico-attachment') != null,
      isSticky: id.startsWith('stickthread') || li.querySelector('.kmding') != null,
      fid: fid == 0 ? null : fid,
    ));
  }

  return ThreadPage(items: items, page: page, totalPages: _parseTotalPages(doc, page));
}

int _parseTotalPages(Document doc, int page) {
  var total = page;
  final pageLabel = RegExp(r'共\s*(\d+)\s*页').firstMatch(doc.documentElement?.outerHtml ?? '');
  if (pageLabel != null) total = math.max(total, int.parse(pageLabel.group(1)!));

  for (final a in doc.querySelectorAll('a[href]')) {
    final h = a.attributes['href'] ?? '';
    final m = RegExp(r'forum-\d+-(\d+)\.html').firstMatch(h);
    if (m != null) total = math.max(total, int.parse(m.group(1)!));
    final p = RegExp(r'[?&]page=(\d+)').firstMatch(h);
    if (p != null) total = math.max(total, int.parse(p.group(1)!));
  }
  // 无法确定总页数时，只要存在“下一页”就认为还有更多
  final hasNext = doc.querySelectorAll('a[href]').any((a) {
    final t = _text(a);
    return t.contains('下一页');
  });
  if (hasNext && total <= page) total = page + 1;
  return total;
}

ThreadDetail parseThread(String html, {int tid = 0, int page = 1}) {
  final doc = html_parser.parse(html);

  var title = _text(doc.querySelector('#thread_subject'));
  if (title.isEmpty) {
    final t = _text(doc.querySelector('title'));
    title = t.split(RegExp(r'\s*-\s*')).first;
  }

  var fid = 0;
  final action = doc.querySelector('form#fastpostform')?.attributes['action'];
  if (action != null) {
    final m = RegExp(r'fid=(\d+)').firstMatch(action);
    if (m != null) fid = int.parse(m.group(1)!);
  }
  if (fid == 0) {
    final m = RegExp(r'forum-(\d+)-1\.html').firstMatch(doc.documentElement?.outerHtml ?? '');
    if (m != null) fid = int.parse(m.group(1)!);
  }

  final posts = <Post>[];
  String? lockedText;
  var needsReply = false;
  var needsPurchase = false;
  var needsLogin = false;
  var isLocked = false;
  String? payUrl;
  String? payPriceText;
  var payBuyers = 0;

  final postDivs = doc.querySelectorAll('div[id^="post_"]');
  for (final p in postDivs) {
    // 只认 #post_<pid>，避免 post_rate_div_* / post_attach_* 之类的同前缀节点
    final idm = RegExp(r'^post_(\d+)$').firstMatch(p.id);
    if (idm == null) continue;
    final pid = int.parse(idm.group(1)!);

    // 正文容器：优先 postmessage；售价/隐藏主题的楼主楼常常没有 postmessage，
    // 内容被 div.locked 顶掉，此时退到 .t_fsz / td.t_f / .pcb，
    // 否则整层会被跳过，客户端就只剩标题和回复，「正文显示不完整」。
    final contentEl = p.querySelector('[id^="postmessage_"]') ??
        p.querySelector('div.t_fsz') ??
        p.querySelector('td.t_f') ??
        p.querySelector('.pcb') ??
        p.querySelector('.pct');
    if (contentEl == null) continue;

    // 是否楼主楼：comiis_vone / 楼层文字 / 第一层
    final isOp = p.classes.contains('comiis_vone') ||
        _text(p.querySelector('strong a[id^="postnum"]')).contains('楼主') ||
        posts.isEmpty;

    // 隐藏内容提示（回复可见 / 购买可见 / 登录可见）
    // 注意：Discuz 把 .locked 放在 #postmessage 的兄弟节点，两种位置都要查。
    // 只有楼主楼决定整个主题的锁定状态，回复被屏蔽不应把主题判成隐藏贴。
    final lockedEl = contentEl.querySelector('div.locked') ?? p.querySelector('div.locked');
    if (lockedEl != null && isOp) {
      final t = _text(lockedEl);
      final payLink = lockedEl.querySelector('a[href*="action=pay"]');
      // 购买成功后站点**仍会输出** <div class="locked">，但内容退化成一条信息栏：
      //   购买前：<a href="…action=pay…">购买主题</a> 本主题需向作者支付 5 星币 才能浏览
      //   购买后：<a href="…action=viewpayments…">记录</a> 付费主题, 价格: 5 星币
      // 后者链接是「购买记录」而非购买入口，正文也已正常回到 #postmessage。
      // 只按「含『星币』就锁定」会把它误判成仍需购买，导致买完仍提示购买失败。
      final hasBlockerText = _lockedBlockerRe.hasMatch(t);
      final infoBarOnly = payLink == null &&
          !hasBlockerText &&
          (lockedEl.querySelector('a[href*="action=viewpayments"]') != null ||
              t.contains('付费主题') ||
              p.querySelector('[id^="postmessage_"]') != null);
      if (!infoBarOnly) {
        isLocked = true;
        lockedText ??= t;
        if (t.contains('回复')) needsReply = true;
        if (payLink != null ||
            t.contains('购买') ||
            t.contains('支付') ||
            t.contains('星币') ||
            t.contains('金币')) {
          needsPurchase = true;
        }
        if (t.contains('登录')) needsLogin = true;

        // 付费主题：locked 块内有「购买主题」链接，指向
        // forum.php?mod=misc&action=pay&tid=…&pid=…（showWindow 弹窗），
        // 价格形如「本主题需向作者支付 <strong>5 星币</strong> 才能浏览」。
        if (payLink != null) {
          final href = payLink.attributes['href'];
          if (href != null && href.isNotEmpty) payUrl = absoluteUrl(href);
        }
        final hm = RegExp(r'支付\s*(?:<[^>]+>\s*)*([\d.]+)\s*([^<\s]{1,8})')
            .firstMatch(lockedEl.innerHtml);
        if (hm != null) payPriceText = '${hm.group(1)} ${hm.group(2)}';
        final bm = RegExp(r'已有\s*(\d+)\s*人购买').firstMatch(t);
        if (bm != null) payBuyers = int.tryParse(bm.group(1)!) ?? 0;
      }
    }
    final noPerm = contentEl.querySelector('div.attach_nopermission') ??
        p.querySelector('div.attach_nopermission');
    if (noPerm != null && isOp && _text(noPerm).contains('登录')) {
      needsLogin = true;
    }

    final nameEl = p.querySelector('a.km_name') ?? p.querySelector('.authi a[href*="space-uid-"]');
    final avatarImg = p.querySelector('.authi img.user_avatar') ?? p.querySelector('img.user_avatar');
    final floor = _text(p.querySelector('strong a[id^="postnum"]')).isEmpty
        ? _text(p.querySelector('.pi strong'))
        : _text(p.querySelector('strong a[id^="postnum"]'));
    final timeText = (_text(p.querySelector('em[id^="authorposton"]')).isEmpty
            ? _text(p.querySelector('.km_time'))
            : _text(p.querySelector('em[id^="authorposton"]')))
        .replaceFirst(RegExp(r'^发表于\s*'), '');

    // 登录态下正文附件图片不在 #postmessage 里，而在其兄弟节点 div.pattl
    // （被 <ignore_js_op> 包裹，img.src 是 none.gif 占位图、真实地址在 zoomfile/file）。
    // 只并入 <img>，附件操作文本（下载附件 / 保存到相册 / 文件名大小）不进正文。
    final pattl = p.querySelector('div.pattl');
    final postAtts = <PostAttachment>[];
    final attachImgs = <String>[];
    if (pattl != null) {
      // 逐个 <dl class="tattl"> 处理：dd 内有 zoomfile/file <img> 的是图片附件
      // （并入正文渲染），纯文件附件提取下载链接做附件卡片。
      final dds = pattl.querySelectorAll('dl.tattl dd');
      for (final dd in dds) {
        final img = dd.querySelector('img[zoomfile], img[file]');
        final link = dd.querySelector('a[href*="mod=attachment"]');
        if (img != null) {
          final zoom = img.attributes['zoomfile'] ?? img.attributes['file'];
          if (zoom != null && zoom.trim().isNotEmpty) attachImgs.add(img.outerHtml);
          continue;
        }
        if (link == null) continue;
        final href = link.attributes['href'];
        if (href == null || href.isEmpty) continue;
        final name = _text(link).isNotEmpty ? _text(link) : '附件';
        postAtts.add(PostAttachment(
          name: name,
          sizeText: _attachSize(_text(dd)),
          url: absoluteUrl(href),
        ));
      }
      // 兼容旧模板：不在 dl.tattl 结构里的 zoomfile/file 图片也并入正文
      if (dds.isEmpty) {
        for (final img in pattl.querySelectorAll('img')) {
          final zoom = img.attributes['zoomfile'] ?? img.attributes['file'];
          final src = (img.attributes['src'] ?? '').toLowerCase();
          final keep = (zoom != null && zoom.trim().isNotEmpty) ||
              (src.isNotEmpty && !src.contains('none.gif') && !src.contains('smiley/'));
          if (keep) attachImgs.add(img.outerHtml);
        }
      }
    }

    // comiis 模板还会把附件直接嵌在 #postmessage 里：
    //   <ignore_js_op>
    //     <img src="static/image/filetype/unknown.gif" class="vm" />   ← 16px 文件类型小图标
    //     <span id="attach_165814"><a href="forum.php?mod=attachment&aid=…">名字.json</a>
    //       <em class="xg1">(13.83 KB, 下载次数: 531)</em></span>
    //     <div class="tip" style="display:none">…点击文件名下载附件</div>
    //   </ignore_js_op>
    // 之前整块当正文渲染：filetype 小图标被放大成整屏问号，隐藏的 tip 文案也漏出来。
    // 这里抽出附件卡片并从正文里摘掉，渲染交给详情页的附件列表。
    for (final op in contentEl.querySelectorAll('ignore_js_op')) {
      // 内联图片附件（img[zoomfile]/img[file]）要保持原样交给正文渲染，不能当文件附件摘掉。
      if (op.querySelector('img[zoomfile], img[file]') != null) continue;
      final link = op.querySelector('a[href*="mod=attachment"]');
      final href = link?.attributes['href'];
      if (link == null || href == null || href.isEmpty) continue;
      final url = absoluteUrl(href);
      if (!postAtts.any((a) => a.url == url)) {
        final name = _text(link).isNotEmpty ? _text(link) : '附件';
        postAtts.add(PostAttachment(
          name: name,
          sizeText: _attachSize(_text(op)),
          url: url,
        ));
      }
      op.remove();
    }

    var bodyHtml = contentEl.innerHtml;
    if (attachImgs.isNotEmpty) bodyHtml += attachImgs.join();

    posts.add(Post(
      pid: pid,
      author: _text(nameEl).isEmpty ? '匿名' : _text(nameEl),
      authorId: _uidFromHref(nameEl?.attributes['href']),
      avatar: avatarImg == null
          ? null
          : absoluteUrl(avatarImg.attributes['src'] ?? avatarImg.attributes['data-original']),
      floor: floor.isEmpty ? null : floor,
      timeText: timeText.isEmpty ? null : timeText,
      contentHtml: bodyHtml,
      isOp: isOp,
      attachments: postAtts,
    ));
  }

  return ThreadDetail(
    tid: tid,
    fid: fid,
    title: title,
    posts: posts,
    page: page,
    totalPages: _parseTotalPages(doc, page),
    lockedText: lockedText,
    needsReply: needsReply,
    needsPurchase: needsPurchase,
    needsLogin: needsLogin,
    isLocked: isLocked,
    payUrl: payUrl,
    payPriceText: payPriceText,
    payBuyers: payBuyers,
  );
}

SignStatus parseSignPage(String html) {
  final doc = html_parser.parse(html);
  final body = doc.documentElement?.text ?? html;

  // k_misign 的已签到状态：按钮换成 .btnvisted，并显示“您的签到排名：N”
  final signed = doc.querySelector('.btnvisted') != null ||
      body.contains('您的签到排名') ||
      body.contains('您今天已经签到') ||
      body.contains('今日已签到') ||
      body.contains('已经签到过');

  final streakInput = doc.querySelector('#lxdays');
  var streak = _toInt(streakInput?.attributes['value']);
  if (streak == 0) {
    final m = RegExp(r'连续签到[^\d]{0,10}(\d+)\s*天').firstMatch(body);
    if (m != null) streak = int.parse(m.group(1)!);
  }

  var todayCount = _toInt(_text(doc.querySelector('div.weather_p div.con')));
  if (todayCount == 0) {
    final cnt = RegExp(r'今日签到[^\d]{0,12}(\d+)').firstMatch(body) ??
        RegExp(r'(\d+)\s*人\s*已签到').firstMatch(body);
    if (cnt != null) todayCount = int.parse(cnt.group(1)!);
  }

  String? rank;
  final rankInput = doc.querySelector('#qiandaobtnnum');
  final rankValue = _toInt(rankInput?.attributes['value']);
  if (rankValue > 0) {
    rank = '第 $rankValue 名';
  } else {
    final rm = RegExp(r'您的签到排名[:：]\s*(\d+)').firstMatch(body) ??
        RegExp(r'第\s*(\d+)\s*名').firstMatch(body);
    if (rm != null) rank = '第 ${rm.group(1)} 名';
  }

  String? reward;
  final rw = RegExp(r'(?:获得|奖励)[^\n]{0,30}?(\d+)\s*(?:星币|金币|源币)').firstMatch(body);
  if (rw != null) reward = rw.group(0)?.trim();

  return SignStatus(
    signedToday: signed,
    streakDays: streak,
    todayCount: todayCount,
    rankText: rank,
    rewardText: reward,
    rawText: body.length > 400 ? body.substring(0, 400) : body,
  );
}

/// 从任意页面提取 formhash
String? parseFormhash(String html) {
  final m = RegExp(r'name="formhash"\s+value="([^"]+)"').firstMatch(html) ??
      RegExp(r'formhash=([0-9a-zA-Z]{8})').firstMatch(html);
  return m?.group(1);
}

String? parseLoginhash(String html) {
  final m = RegExp(r'loginhash=([0-9a-zA-Z]+)').firstMatch(html);
  return m?.group(1);
}

/// 从 forum.php 头部判断是否已登录
({int uid, String name})? parseHeaderUser(String html) {
  if (!looksLoggedIn(html)) return null;
  final doc = html_parser.parse(html);
  final um = doc.querySelector('#um') ??
      doc.querySelector('.comiis_headb_nv') ??
      doc.querySelector('#hd');
  if (um != null) {
    for (final a in um.querySelectorAll('a[href*="space"]')) {
      final uid = _uidFromHref(a.attributes['href']);
      final name = _text(a);
      if (uid != null && name.isNotEmpty) return (uid: uid, name: name);
    }
  }
  return null;
}

bool looksLoggedIn(String html) {
  final hasLogout = html.contains('action=logout') || html.contains('退出');
  final hasLoginForm = html.contains('loginsubmit=yes') || html.contains('mod=logging&amp;action=login');
  return hasLogout && !hasLoginForm;
}

/// 明确是游客页（有登录表单、没有退出入口）。
/// 出错页 / 提示页既没有退出也没有登录表单，不能用 looksLoggedIn 判断。
bool looksLoggedOut(String html) {
  final hasLoginForm = html.contains('loginsubmit=yes') ||
      html.contains('mod=logging&action=login') ||
      html.contains('mod=logging&amp;action=login');
  final hasLogout = html.contains('action=logout') || html.contains('退出');
  return hasLoginForm && !hasLogout;
}

UserProfile? parseProfile(String html, {int? fallbackUid, String? fallbackName}) {
  final doc = html_parser.parse(html);
  final body = doc.documentElement?.text ?? html;

  var uid = fallbackUid ?? 0;
  var name = fallbackName ?? '';

  final title = _text(doc.querySelector('title'));
  final tm = RegExp(r'(.+?)的个人资料').firstMatch(title);
  if (tm != null) name = tm.group(1)!.trim();

  final uidLink = doc.querySelector('a[href*="space-uid-"]');
  uid = _uidFromHref(uidLink?.attributes['href']) ?? uid;

  String? pick(RegExp re) => re.firstMatch(body)?.group(1)?.trim();

  final group = pick(RegExp(r'用户组[:：\s]*([^\s\n]{2,16})'));
  final credits = pick(RegExp(r'积分[:：\s]*([\d,]+)'));
  final threads = pick(RegExp(r'主题数[:：\s]*([\d,]+)'));
  final posts = pick(RegExp(r'(?:回帖数|帖子数)[:：\s]*([\d,]+)'));
  final friends = pick(RegExp(r'好友数[:：\s]*([\d,]+)'));
  final online = pick(RegExp(r'在线时间[:：\s]*([^\s\n]{1,20})'));
  final reg = pick(RegExp(r'注册时间[:：\s]*([\d]{4}-\d{1,2}-\d{1,2})'));

  final avatarImg = doc.querySelector('img.user_avatar, .avt img');
  final avatar = avatarImg?.attributes['src'];

  if (uid == 0 && name.isEmpty) return null;
  return UserProfile(
    uid: uid,
    username: name.isEmpty ? (fallbackName ?? '用户') : name,
    avatar: avatar == null ? null : absoluteUrl(avatar),
    group: group,
    credits: credits,
    threads: threads == null ? null : _toInt(threads),
    posts: posts == null ? null : _toInt(posts),
    friends: friends == null ? null : _toInt(friends),
    onlineTime: online,
    registerTime: reg,
  );
}

/// 解析 Discuz inajax XML 的提示文本。
///
/// 成功响应形如：
/// `<root><![CDATA[<script>...succeedhandle_fastpost('url', '提示语', {...});</script>]]></root>`
/// 提示语在 JS 字符串里，如果先把整段 `<script>` 删掉就会得到空串，
/// 于是「回复成功」被误判成「回复失败」——这里先把回调参数取出来再清洗。
String parseAjaxMessage(String body) {
  if (body.isEmpty) return '';
  final cdata = RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>').firstMatch(body);
  var text = cdata?.group(1) ?? body;

  // succeedhandle_xxx('跳转地址', '提示文本', {...})
  //
  // 注意 handlekey 可能为空：站点在 misc&action=pay 提交后返回的是
  //   succeedhandle_('forum.php?mod=viewthread&tid=…', '主题购买成功 ', {})
  // 下划线后没有任何字符，所以这里必须是 \w* 而不是 \w+，
  // 否则「购买成功」会被解析成空串，进而被当成失败。
  final cb = RegExp(
    r"""succeedhandle_\w*\s*\(\s*(?:'[^']*'|"[^"]*")\s*,\s*['"]((?:[^'\\]|\\.)*)['"]""",
  ).firstMatch(text);
  if (cb != null) {
    text = cb.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
  } else {
    // errorhandle_xxx('失败原因')：余额不足 / 无权限 / 来路不正确等，
    // 这类文案必须透传给用户，否则只剩一句「购买失败」。
    final eb = RegExp(
      r"""errorhandle_\w*\s*\(\s*['"]((?:[^'"\\]|\\.)*)['"]""",
    ).firstMatch(text);
    if (eb != null) {
      text = eb.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
    } else {
      // showmessage('xxx') / showDialog('xxx')
      final sm = RegExp(
        r"""(?:showmessage|showDialog|showError|alert)\s*\(\s*['"]((?:[^'"\\]|\\.)*)['"]""",
      ).firstMatch(text);
      if (sm != null) text = sm.group(1)!.replaceAll(r"\'", "'");
    }
  }

  text = text.replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ');
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 回复表单的真实提交地址与字段（fastpostform）。
/// 站点模板会把 `extra` / `handlekey` / `posttime` 写死在表单里，
/// 直接按表单 action 提交最稳。
({String action, String? formhash, String? posttime})? parseReplyForm(String html) {
  final m = RegExp(
    r'''<form[^>]*id="fastpostform"[^>]*action="([^"]+)"''',
    caseSensitive: false,
  ).firstMatch(html);
  if (m == null) return null;
  final action = m.group(1)!.replaceAll('&amp;', '&');
  String? pick(String name) {
    final r = RegExp(
      '<input[^>]*name="$name"[^>]*value="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);
    return r?.group(1);
  }

  return (
    action: action,
    formhash: pick('formhash') ?? parseFormhash(html),
    posttime: pick('posttime'),
  );
}

int parseRemainingAttempts(String message) {
  final m = RegExp(r'还可以尝试\s*(\d+)\s*次').firstMatch(message);
  return m == null ? -1 : int.parse(m.group(1)!);
}

/// 简易 HTML → 纯文本（用于摘要、分享）
String htmlToPlainText(String html, {int maxLen = 160}) {
  final doc = html_parser.parse(html);
  final t = (doc.body?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length <= maxLen) return t;
  return '${t.substring(0, maxLen)}…';
}
