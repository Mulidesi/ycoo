/// 数据模型：全部来自 Discuz! 页面解析结果，不依赖任何第三方序列化库。
library;

class Board {
  final int fid;
  final String name;
  final String? icon;
  final int todayPosts;
  final int threads;
  final int posts;
  final String? lastPost;
  final bool isPrivate;

  const Board({
    required this.fid,
    required this.name,
    this.icon,
    this.todayPosts = 0,
    this.threads = 0,
    this.posts = 0,
    this.lastPost,
    this.isPrivate = false,
  });
}

class BoardGroup {
  final int gid;
  final String name;
  final List<Board> boards;

  const BoardGroup({required this.gid, required this.name, required this.boards});
}

class ThreadItem {
  final int tid;
  final String title;
  final String url;
  final String? author;
  final int? authorId;
  final String? avatar;
  final int replies;
  final int views;
  final String? timeText;
  final String? typeName;
  final bool hasAttachment;
  final bool isSticky;
  final int? fid;

  const ThreadItem({
    required this.tid,
    required this.title,
    required this.url,
    this.author,
    this.authorId,
    this.avatar,
    this.replies = 0,
    this.views = 0,
    this.timeText,
    this.typeName,
    this.hasAttachment = false,
    this.isSticky = false,
    this.fid,
  });
}

class ThreadPage {
  final List<ThreadItem> items;
  final int page;
  final int totalPages;

  const ThreadPage({required this.items, required this.page, required this.totalPages});

  bool get hasMore => page < totalPages;
}

/// 帖子附件（非图片的文件附件；图片已并入正文渲染）。
class PostAttachment {
  final String name;

  /// 形如 `148.78 KB` 的原始大小文本。
  final String? sizeText;

  /// 下载链接（forum.php?mod=attachment&aid=…&nothumb=yes 的绝对地址）。
  final String url;

  const PostAttachment({required this.name, this.sizeText, required this.url});

  String get key => url;
}

class Post {
  final int pid;
  final String author;
  final int? authorId;
  final String? avatar;
  final String? floor;
  final String? timeText;
  final String contentHtml;
  final bool isOp;
  final List<PostAttachment> attachments;

  const Post({
    required this.pid,
    required this.author,
    this.authorId,
    this.avatar,
    this.floor,
    this.timeText,
    required this.contentHtml,
    this.isOp = false,
    this.attachments = const <PostAttachment>[],
  });
}

class ThreadDetail {
  final int tid;
  final int fid;
  final String title;
  final List<Post> posts;
  final int page;
  final int totalPages;
  final String? lockedText;
  final bool needsReply;
  final bool needsPurchase;
  final bool needsLogin;
  final bool isLocked;

  /// 购买主题弹窗链接（forum.php?mod=misc&action=pay&tid=…&pid=…），
  /// 仅付费主题的楼主楼存在；应用内购买据此发起。
  final String? payUrl;

  /// 价格文本，如 `5 星币`。
  final String? payPriceText;

  /// 已购买人数（页面显示 `已有 N 人购买`）。
  final int payBuyers;

  const ThreadDetail({
    required this.tid,
    required this.fid,
    required this.title,
    required this.posts,
    this.page = 1,
    this.totalPages = 1,
    this.lockedText,
    this.needsReply = false,
    this.needsPurchase = false,
    this.needsLogin = false,
    this.isLocked = false,
    this.payUrl,
    this.payPriceText,
    this.payBuyers = 0,
  });

  bool get hasMore => page < totalPages;

  /// 是否可以在应用内发起购买（锁定为付费贴且有购买链接）。
  bool get canPurchase => needsPurchase && payUrl != null;
}

/// 购买主题结果。
class BuyResult {
  final bool success;

  /// true 表示无需扣费（已购买过 / 已解锁）。
  final bool alreadyOwned;
  final String message;

  const BuyResult({required this.success, this.alreadyOwned = false, required this.message});
}

/// 当前登录用户的资料与统计。
///
/// 数据来源（优先级从高到低）：
///  1. 移动端 JSON 接口 `api/mobile/index.php?version=4&module=profile&uid=N`
///     —— 与 `spacecp&ac=credit&showcredit=1`（积分页）、`space-uid-N.html`（空间页）
///     展示的是同一份后台数据，但结构化、无需正则，数值最准；
///  2. 上述两个页面的 HTML 兜底解析（`parseProfile`）。
class UserProfile {
  final int uid;
  final String username;
  final String? avatar;
  final String? group;

  /// 等级文案；站点无独立等级时与用户组相同。
  final String? level;

  // ---- 积分体系 ----
  /// 总积分（空间页 / 积分页的「积分」）。
  final int? points;

  /// 星币（extcredits4）。
  final int? coins;

  /// 经验（extcredits2）。
  final int? exp;

  /// 贡献（extcredits3）。
  final int? contribution;

  /// 总积分公式说明，如「总积分= 发帖数 X 1.5 + …」。
  final String? creditFormula;

  // ---- 社区统计 ----
  /// 帖子总数（主题 + 回复）。
  final int? posts;

  /// 主题数。
  final int? threads;

  /// 关注数。
  final int? following;

  /// 粉丝数。
  final int? followers;

  /// 好友数。
  final int? friends;

  /// 精华帖数。
  final int? digestPosts;

  /// 在线时长（小时）。
  final int? onlineHours;

  /// 空间访问量。
  final int? views;

  /// 广播数。
  final int? feeds;

  final String? registerTime;
  final String? signature;

  const UserProfile({
    required this.uid,
    required this.username,
    this.avatar,
    this.group,
    this.level,
    this.points,
    this.coins,
    this.exp,
    this.contribution,
    this.creditFormula,
    this.posts,
    this.threads,
    this.following,
    this.followers,
    this.friends,
    this.digestPosts,
    this.onlineHours,
    this.views,
    this.feeds,
    this.registerTime,
    this.signature,
  });

  /// 回帖数 = max(0, posts - threads)；缺任一操作数时为 null。
  int? get replies {
    if (posts == null || threads == null) return null;
    final v = posts! - threads!;
    return v < 0 ? 0 : v;
  }

  UserProfile copyWith({
    String? username,
    String? avatar,
    String? group,
    String? level,
    int? points,
    int? coins,
    int? exp,
    int? contribution,
    String? creditFormula,
    int? posts,
    int? threads,
    int? following,
    int? followers,
    int? friends,
    int? digestPosts,
    int? onlineHours,
    int? views,
    int? feeds,
    String? registerTime,
    String? signature,
  }) {
    return UserProfile(
      uid: uid,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      group: group ?? this.group,
      level: level ?? this.level,
      points: points ?? this.points,
      coins: coins ?? this.coins,
      exp: exp ?? this.exp,
      contribution: contribution ?? this.contribution,
      creditFormula: creditFormula ?? this.creditFormula,
      posts: posts ?? this.posts,
      threads: threads ?? this.threads,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      friends: friends ?? this.friends,
      digestPosts: digestPosts ?? this.digestPosts,
      onlineHours: onlineHours ?? this.onlineHours,
      views: views ?? this.views,
      feeds: feeds ?? this.feeds,
      registerTime: registerTime ?? this.registerTime,
      signature: signature ?? this.signature,
    );
  }

  /// 用 [other] 里非空的字段补全当前对象缺失的部分。
  ///
  /// 当前对象的字段优先，[other] 只填空位（例如接口没有头像，就用 HTML 解析出的头像）。
  UserProfile mergeMissingFrom(UserProfile? other) {
    if (other == null) return this;
    return UserProfile(
      uid: uid != 0 ? uid : other.uid,
      username: username.isNotEmpty ? username : other.username,
      avatar: avatar ?? other.avatar,
      group: group ?? other.group,
      level: level ?? other.level,
      points: points ?? other.points,
      coins: coins ?? other.coins,
      exp: exp ?? other.exp,
      contribution: contribution ?? other.contribution,
      creditFormula: creditFormula ?? other.creditFormula,
      posts: posts ?? other.posts,
      threads: threads ?? other.threads,
      following: following ?? other.following,
      followers: followers ?? other.followers,
      friends: friends ?? other.friends,
      digestPosts: digestPosts ?? other.digestPosts,
      onlineHours: onlineHours ?? other.onlineHours,
      views: views ?? other.views,
      feeds: feeds ?? other.feeds,
      registerTime: registerTime ?? other.registerTime,
      signature: signature ?? other.signature,
    );
  }
}

class SignStatus {
  final bool signedToday;
  final int streakDays;
  final int todayCount;
  final String? rankText;
  final String? rewardText;
  final String? rawText;

  const SignStatus({
    required this.signedToday,
    this.streakDays = 0,
    this.todayCount = 0,
    this.rankText,
    this.rewardText,
    this.rawText,
  });
}

class SignResult {
  final bool success;
  final String message;

  const SignResult({required this.success, required this.message});
}

class ReplyResult {
  final bool success;
  final String message;
  final bool needCaptcha;

  const ReplyResult({required this.success, required this.message, this.needCaptcha = false});
}

/// 发帖表单里的「主题分类」选项（Discuz `typeid`）。
class ThreadCategory {
  final int id;
  final String name;

  const ThreadCategory({required this.id, required this.name});
}

/// 发帖页 `form#postform` 的真实提交信息。
///
/// Discuz 会校验 `formhash` + `posttime`，并用表单 action 里写死的
/// `extra` / `topicsubmit` 判断来路，所以不能自己拼一个干净的 URL。
class PostForm {
  final bool canPost;
  final String? action;
  final String? formhash;
  final String? posttime;
  final List<ThreadCategory> categories;
  final String? notice;

  const PostForm({
    required this.canPost,
    this.action,
    this.formhash,
    this.posttime,
    this.categories = const <ThreadCategory>[],
    this.notice,
  });
}

/// 发帖结果。`tid` 用于发布成功后直接打开新主题。
class NewThreadResult {
  final bool success;
  final String message;
  final int? tid;
  final bool pending;
  final bool needCaptcha;

  const NewThreadResult({
    required this.success,
    required this.message,
    this.tid,
    this.pending = false,
    this.needCaptcha = false,
  });
}

class LoginResult {
  final bool success;
  final String message;
  final int remainingAttempts;

  const LoginResult({
    required this.success,
    required this.message,
    this.remainingAttempts = -1,
  });
}
