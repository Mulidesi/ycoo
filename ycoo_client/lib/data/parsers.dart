/// 纯 Dart 的 Discuz! 页面解析器。
/// 之所以与 UI 分离，是为了能直接用 curl 抓下来的真实页面做离线回归测试。
library;

import 'dart:convert';
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
      final hasReplyLink =
          lockedEl.querySelector('a[href*="action=reply"]') != null;
      final hasBlockerText = _lockedBlockerRe.hasMatch(t) ||
          t.contains('隐藏内容') ||
          (hasReplyLink && t.contains('回复'));
      // 已购信息栏的 locked 在正文外，链接是购买记录而非购买入口；
      // 不能用「存在 #postmessage」判断，否则回复可见的 locked 嵌在正文里
      // 会被误当成已购信息栏，隐藏标识和自动回复都会失效。
      final infoBarOnly = payLink == null &&
          !hasBlockerText &&
          (lockedEl.querySelector('a[href*="action=viewpayments"]') != null ||
              t.contains('付费主题'));
      if (!infoBarOnly) {
        isLocked = true;
        lockedText ??= t;
        if (t.contains('回复') || hasReplyLink) needsReply = true;
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

/// 解析移动端 JSON 接口 `api/mobile/index.php?version=4&module=profile&uid=N`。
///
/// 这是「我的」页积分与统计的**主数据源**：与
/// `home.php?mod=spacecp&ac=credit&showcredit=1`（积分页）和
/// `space-uid-N.html`（空间页）展示的是同一份后台数据，但结构化、无模板依赖。
///
/// 关键字段：
/// ```
/// space.credits      总积分        9207
/// space.extcredits2  经验          8456   ← 由 extcredits 映射决定，不写死
/// space.extcredits3  贡献          1506
/// space.extcredits4  星币          2026
/// space.posts        帖子          714
/// space.threads      主题          39
/// space.following    关注          20
/// space.follower     粉丝          188
/// ```
/// 积分类型的编号→名称映射由 `Variables.extcredits[*].title` 给出，
/// 站点改过编号也不会错位；缺失时回退到本站约定（2 经验 / 3 贡献 / 4 星币）。
UserProfile? parseProfileApi(String json, {int? fallbackUid, String? fallbackName}) {
  Map<String, dynamic> root;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return null;
    root = decoded;
  } catch (_) {
    return null;
  }
  final vars = root['Variables'];
  if (vars is! Map<String, dynamic>) return null;
  final space = vars['space'];
  if (space is! Map<String, dynamic>) return null;

  int? numOf(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  String? strOf(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  final uid = numOf(space['uid']) ?? fallbackUid ?? 0;
  final name = strOf(space['username']) ?? fallbackName ?? '';

  // 积分类型映射：{2: 经验, 3: 贡献, 4: 星币}
  final creditsByTitle = <String, int>{};
  final ext = vars['extcredits'];
  if (ext is Map) {
    ext.forEach((key, meta) {
      if (meta is! Map) return;
      final title = strOf(meta['title']);
      if (title == null) return;
      final value = numOf(space['extcredits$key']);
      if (value != null) creditsByTitle[title] = value;
    });
  }
  // 站点约定兜底（creditnotice = '2|经验|,3|贡献|,4|星币|'）
  creditsByTitle.putIfAbsent('经验', () => numOf(space['extcredits2']) ?? -1);
  creditsByTitle.putIfAbsent('贡献', () => numOf(space['extcredits3']) ?? -1);
  creditsByTitle.putIfAbsent('星币', () => numOf(space['extcredits4']) ?? -1);
  int? credit(String title) {
    final v = creditsByTitle[title];
    return (v == null || v < 0) ? null : v;
  }

  // 头像：member_avatar 是当前登录用户的，noavatar 视为没有。
  // 查看他人时 member_uid != uid，头像留给空间页 HTML 或调用方按 UID 拼接。
  String? avatar;
  final memberAvatar = strOf(vars['member_avatar']);
  final memberUid = numOf(vars['member_uid']);
  if (memberAvatar != null &&
      !memberAvatar.contains('noavatar') &&
      (memberUid == null || memberUid == uid)) {
    avatar = absoluteUrl(memberAvatar);
  }

  // Variables.group 是当前登录用户的用户组，只在查看自己时可用。
  String? groupTitle;
  String? level;
  final viewingSelf = memberUid == null || memberUid == uid;
  if (viewingSelf) {
    final groupMeta = vars['group'];
    if (groupMeta is Map) {
      groupTitle = strOf(groupMeta['grouptitle']);
      final stars = strOf(groupMeta['stars']);
      if (stars != null && stars.isNotEmpty && stars != '0') {
        level = 'Lv.$stars';
      }
    }
  }
  level ??= strOf(space['stars']);
  if (level != null && RegExp(r'^\d+$').hasMatch(level)) {
    level = 'Lv.$level';
  }
  level ??= groupTitle;

  if (uid == 0 && name.isEmpty) return null;
  return UserProfile(
    uid: uid,
    username: name.isEmpty ? '用户' : name,
    avatar: avatar,
    group: groupTitle,
    level: level,
    points: numOf(space['credits']),
    coins: credit('星币'),
    exp: credit('经验'),
    contribution: credit('贡献'),
    posts: numOf(space['posts']),
    threads: numOf(space['threads']),
    following: numOf(space['following']),
    followers: numOf(space['follower']),
    friends: numOf(space['friends']),
    digestPosts: numOf(space['digestposts']),
    onlineHours: numOf(space['oltime']),
    views: numOf(space['views']),
    feeds: numOf(space['feeds']),
    registerTime: strOf(space['regdate']),
    signature: strOf(space['spacedescription']),
  );
}

/// Discuz 头像路径：uid 补零到 9 位后按 3/2/2/2 切目录。
String? avatarUrlFromUid(int uid) {
  if (uid <= 0) return null;
  final padded = uid.toString().padLeft(9, '0');
  final a = padded.substring(0, 3);
  final b = padded.substring(3, 5);
  final c = padded.substring(5, 7);
  final d = padded.substring(7, 9);
  return absoluteUrl('data/avatar/$a/$b/$c/${d}_avatar_middle.jpg');
}

/// 从任意登录态页面里取当前用户 UID（Discuz 每页都注入 `discuz_uid = '31981'`）。
int? parseDiscuzUid(String html) {
  final m = RegExp(r"discuz_uid\s*=\s*'(\d+)'").firstMatch(html);
  if (m == null) return null;
  final uid = int.tryParse(m.group(1)!);
  return (uid == null || uid <= 0) ? null : uid;
}

/// 顶部用户菜单里的头像属于**当前登录用户**，不是被查看用户，必须排除。
///
/// comiis 模板把当前用户头像放在 `#comiis_user_menu` / `.comiis_user_info`，
/// 标准模板放在 `#um`，两者都渲染在 `img.user_avatar` 上。
bool _insideUserMenu(Element img) {
  for (Element? e = img.parent; e != null; e = e.parent) {
    if (e.id == 'comiis_user_menu' || e.id == 'um') return true;
    final cls = e.className;
    if (cls.contains('comiis_user_info') || cls.contains('comiis_headb')) return true;
    if (e.localName == 'a' && cls.contains('nvtx')) return true;
  }
  return false;
}

/// HTML 兜底解析（移动端接口不可用时）。
///
/// 兼容两个页面：
///  - `home.php?mod=spacecp&ac=credit&showcredit=1`：星币 / 经验 / 贡献 / 总积分 + 积分公式
///  - `space-uid-N.html`：帖子 / 关注 / 粉丝
UserProfile? parseProfile(String html, {int? fallbackUid, String? fallbackName}) {
  final doc = html_parser.parse(html);
  final body = doc.documentElement?.text ?? html;

  var uid = fallbackUid ?? parseDiscuzUid(html) ?? 0;
  var name = fallbackName ?? '';

  final title = _text(doc.querySelector('title'));
  final tm = RegExp(r'(.+?)的个人资料').firstMatch(title);
  if (tm != null) name = tm.group(1)!.trim();

  final uidLink = doc.querySelector('a[href*="space-uid-"]');
  uid = _uidFromHref(uidLink?.attributes['href']) ?? uid;

  String? pick(RegExp re) => re.firstMatch(body)?.group(1)?.trim();
  int? pickInt(RegExp re) {
    final s = pick(re);
    return s == null ? null : _toInt(s);
  }

  final group = pick(RegExp(r'用户组[:：\s]*([^\s\n]{2,16})'));
  final levelRaw = pick(RegExp(r'等级[:：\s]*([^\s\n]{1,16})'));
  final level = (levelRaw == null || levelRaw.isEmpty) ? group : levelRaw;
  final reg = pick(RegExp(r'注册时间[:：\s]*([\d]{4}-\d{1,2}-\d{1,2})'));

  // 积分页：「星币: 2026」「经验: 8456」「贡献: 1506」「积分: 9207 ( 总积分= … )」
  final coins = pickInt(RegExp(r'星币[:：\s]*([\d,]+)'));
  final exp = pickInt(RegExp(r'经验[:：\s]*([\d,]+)'));
  final contribution = pickInt(RegExp(r'贡献[:：\s]*([\d,]+)'));
  final points = pickInt(RegExp(r'积分[:：\s]*([\d,]+)'));
  final formula = pick(RegExp(r'(总积分\s*=\s*[^\n<]{4,120})'));

  // 空间页：714 帖子 / 20 关注 / 188 粉丝；资料页：主题数 / 回帖数 / 好友数
  final posts = pickInt(RegExp(r'([\d,]+)\s*帖子')) ?? pickInt(RegExp(r'(?:回帖数|帖子数)[:：\s]*([\d,]+)'));
  final following = pickInt(RegExp(r'([\d,]+)\s*关注'));
  final followers = pickInt(RegExp(r'([\d,]+)\s*粉丝'));
  final threads = pickInt(RegExp(r'主题数[:：\s]*([\d,]+)'));
  final friends = pickInt(RegExp(r'好友数[:：\s]*([\d,]+)'));
  final onlineHours = pickInt(RegExp(r'在线时间[:：\s]*([\d,]+)\s*小时'));
  final views = pickInt(RegExp(r'空间访问量[:：\s]*([\d,]+)'));

  // 页面头部可能先出现游客自己的 noavatar 占位图，必须跳过，取真正的头像。
  // 登录后头部会显示当前登录用户（而非被查看用户）的头像，同样要跳过。
  String? avatar;
  for (final img in doc.querySelectorAll('img.user_avatar, .kmavt img, .avt img')) {
    final src = img.attributes['src'];
    if (src == null || src.isEmpty || src.contains('noavatar')) continue;
    if (_insideUserMenu(img)) continue;
    avatar = src;
    break;
  }

  if (uid == 0 && name.isEmpty) return null;
  return UserProfile(
    uid: uid,
    username: name.isEmpty ? (fallbackName ?? '用户') : name,
    avatar: avatar == null ? null : absoluteUrl(avatar),
    group: group,
    level: level,
    points: points,
    coins: coins,
    exp: exp,
    contribution: contribution,
    creditFormula: formula,
    posts: posts,
    threads: threads,
    following: following,
    followers: followers,
    friends: friends,
    onlineHours: onlineHours,
    views: views,
    registerTime: reg,
  );
}

/// 空间页要求登录（游客访问他人主题列表时站点返回该提示）。
bool isLoginRequired(String html) {
  return html.contains('请先登录后才能继续浏览') || html.contains('您需要登录后才可以');
}

/// 空间页提示用户不存在或空间不可见。
bool isUserSpaceMissing(String html) {
  return html.contains('您指定的用户空间不存在') ||
      html.contains('用户不存在') ||
      html.contains('空间不存在') ||
      html.contains('抱歉，您指定的用户不存在') ||
      html.contains('该用户已禁止使用') ||
      (html.contains('没有权限') && html.contains('空间'));
}

/// 用户空间主题列表。优先复用版块列表解析；空间页常用 `div.xl` / `li` + `a[href*="thread-"]`。
ThreadPage parseUserThreadList(String html, {int page = 1}) {
  final fromBoard = parseThreadList(html, page: page);
  if (fromBoard.items.isNotEmpty) return fromBoard;

  final doc = html_parser.parse(html);
  final items = <ThreadItem>[];
  final seen = <int>{};
  for (final a in doc.querySelectorAll('a[href*="thread-"]')) {
    final href = a.attributes['href'] ?? '';
    final m = RegExp(r'thread-(\d+)').firstMatch(href);
    if (m == null) continue;
    final tid = int.tryParse(m.group(1)!) ?? 0;
    if (tid == 0 || seen.contains(tid)) continue;
    var title = _text(a);
    if (title.isEmpty) title = (a.attributes['title'] ?? '').trim();
    if (title.isEmpty) continue;
    if (title.contains('下一页') || title.contains('上一页') || title == '查看') continue;
    seen.add(tid);

    final li = a.parent;
    final timeText = _text(li?.querySelector('.xg1, .time, em, span.xs0'));
    items.add(ThreadItem(
      tid: tid,
      title: title,
      url: absoluteUrl(href),
      timeText: timeText.isEmpty ? null : timeText,
    ));
  }

  var total = _parseTotalPages(doc, page);
  if (items.isEmpty) total = 1;
  return ThreadPage(items: items, page: page, totalPages: total);
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

/// 发帖表单：`form#postform` 的 action、令牌与主题分类。
///
/// 无权限 / 未登录 / 版块关闭时页面里没有 postform，此时 `canPost` 为 false，
/// 并尽量把站点提示（「抱歉，您没有权限…」）带出来。
PostForm parsePostForm(String html) {
  final doc = html_parser.parse(html);
  final form = doc.querySelector('form#postform');
  if (form == null) {
    return PostForm(canPost: false, notice: parsePostNotice(html));
  }

  String? hidden(String name) =>
      form.querySelector('input[name="$name"]')?.attributes['value'];

  final categories = <ThreadCategory>[];
  for (final opt in form.querySelectorAll('select#typeid option')) {
    final id = int.tryParse((opt.attributes['value'] ?? '').trim()) ?? 0;
    if (id <= 0) continue;
    final name = _text(opt).replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) continue;
    categories.add(ThreadCategory(id: id, name: name));
  }

  final action = form.attributes['action']?.replaceAll('&amp;', '&');
  return PostForm(
    canPost: action != null && action.isNotEmpty,
    action: action,
    formhash: hidden('formhash') ?? parseFormhash(html),
    posttime: hidden('posttime'),
    categories: categories,
  );
}

/// 从发帖页提取站点提示（通常位于 `div.alert_error` / `#messagetext`）。
String? parsePostNotice(String html) {
  final doc = html_parser.parse(html);
  const selectors = <String>[
    'div.alert_error',
    'div.alert_info',
    'div#messagetext',
    'div.message',
    'p.alert_error',
  ];
  for (final sel in selectors) {
    final text = _text(doc.querySelector(sel)).replaceAll(RegExp(r'\s+'), ' ');
    if (text.isNotEmpty) return text;
  }
  final m = RegExp(r'(?:抱歉|对不起)[^<]{0,160}').firstMatch(html);
  return m?.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 解析 `forum.php?mod=post&action=newthread` 的 AJAX 返回。
///
/// 成功时站点返回 `succeedhandle_newthread('forum.php?mod=viewthread&tid=…', '帖子发布成功', {...})`；
/// 需要审核时同样走成功回调，只是文案里带「审核」。
NewThreadResult parseNewThreadResult(String body) {
  final msg = parseAjaxMessage(body);

  int? tid;
  final cb = RegExp(
    r"""succeedhandle_\w*\s*\(\s*['"]([^'"]*)['"]""",
  ).firstMatch(body);
  if (cb != null) {
    tid = int.tryParse(
      RegExp(r'tid=(\d+)').firstMatch(cb.group(1)!)?.group(1) ?? '',
    );
  }
  tid ??= int.tryParse(
    RegExp(r"""['"]tid['"]\s*:\s*['"]?(\d+)""").firstMatch(body)?.group(1) ??
        '',
  );

  final callbackOk = RegExp(
    r'succeedhandle_(?:newthread|post)\b',
  ).hasMatch(body);
  final pending = msg.contains('审核');
  final ok = callbackOk ||
      (tid != null && (msg.contains('发布成功') || msg.contains('发表成功')));

  if (ok) {
    return NewThreadResult(
      success: true,
      message: pending ? '主题已提交，等待审核通过' : '发布成功',
      tid: tid,
      pending: pending,
    );
  }
  if (msg.contains('验证码') || msg.contains('seccode') || msg.contains('安全验证')) {
    return const NewThreadResult(
      success: false,
      message: '站点要求输入验证码，请到网页端发帖一次后重试',
      needCaptcha: true,
    );
  }
  if (msg.contains('登录') || msg.contains('游客')) {
    return const NewThreadResult(success: false, message: '登录状态已失效，请重新登录');
  }
  return NewThreadResult(
    success: false,
    message: msg.isEmpty ? '发布失败，站点未返回提示，请稍后重试' : msg,
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
