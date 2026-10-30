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

/// 关注 / 粉丝列表里的用户条目。
class FollowUser {
  final int uid;
  final String username;
  final String? avatar;

  /// 行内附加文案（签名 / 活跃时间等），解析不到时为 null。
  final String? note;

  const FollowUser({
    required this.uid,
    required this.username,
    this.avatar,
    this.note,
  });
}

/// 关注 / 粉丝列表分页结果。
class FollowPage {
  final List<FollowUser> items;
  final int page;
  final int totalPages;

  const FollowPage({required this.items, required this.page, required this.totalPages});

  bool get hasMore => page < totalPages;
}

/// 某个用户的关注状态与可用的 formhash。
class FollowLink {
  /// 已关注时为 true（站点入口为 `op=del`）。
  final bool following;

  /// 站点 formhash；关注（op=add）时必须携带。解析不到时为 null。
  final String? hash;

  const FollowLink({required this.following, this.hash});
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

  /// 用户组等级徽章文案（PC 模板 `a.km_lvs`，如 `Lv.7`；
  /// 移动模板 `a.top_lev` 会带组名，如 `Lv.7 大会员`）。无徽章时为 null。
  final String? level;

  final String contentHtml;
  final bool isOp;
  final List<PostAttachment> attachments;

  /// 楼主主题投票（仅楼主楼可能携带；无投票时为 null）。
  final Poll? poll;

  /// 楼中楼点评列表。
  final List<ForumComment> comments;

  /// 打赏记录。
  final List<RateRecord> rates;

  /// 打赏入口标题（如「搬砖不容易，打赏一下楼主吧」）。
  final String? rateTitle;

  /// 是否可对当前楼层发起打赏（站点渲染了 `a.comiis_openrebox`）。
  final bool canRate;

  /// 楼层座位标签（floor≤1 空；2-10 沙发→下水道；>10 `$floor楼`）。
  String get floorLabel {
    final f = int.tryParse(floor ?? '') ?? 0;
    if (f <= 1) return '';
    if (f <= 10) {
      const labels = ['沙发', '椅子', '板凳', '地板', '地下室', '下水道', '地窖', '阁楼', '天台'];
      return labels[f - 2];
    }
    return '$f楼';
  }

  const Post({
    required this.pid,
    required this.author,
    this.authorId,
    this.avatar,
    this.floor,
    this.timeText,
    this.level,
    required this.contentHtml,
    this.isOp = false,
    this.attachments = const <PostAttachment>[],
    this.poll,
    this.comments = const <ForumComment>[],
    this.rates = const <RateRecord>[],
    this.rateTitle,
    this.canRate = false,
  });
}

/// 楼中楼点评（Discuz `action=comment`，挂在指定楼层下）。
class ForumComment {
  final String author;
  final String text;
  final int uid;
  final String time;

  const ForumComment({
    required this.author,
    required this.text,
    this.uid = 0,
    this.time = '',
  });
}

/// 投票选项。
class PollOption {
  final int id;
  final String text;
  final int votes;

  const PollOption({required this.id, required this.text, this.votes = 0});
}

/// 主题投票（Discuz `special=1`）。
class Poll {
  final List<PollOption> options;
  final bool multiple;
  final int total;
  final bool voted;
  final bool expired;

  const Poll({
    this.options = const <PollOption>[],
    this.multiple = false,
    this.total = 0,
    this.voted = false,
    this.expired = false,
  });

  int get totalVotes => total > 0 ? total : options.fold<int>(0, (s, o) => s + o.votes);
}

/// 一次打赏记录（Discuz 评分日志）。
class RateRecord {
  final String username;
  final int uid;
  final String score;
  final String reason;

  const RateRecord({
    required this.username,
    this.uid = 0,
    this.score = '',
    this.reason = '',
  });
}

/// 站点允许的打赏项（好评 / 金币等，取决于用户组评分类别）。
class RateField {
  final int id;
  final String label;
  final int min;
  final int max;

  /// 今日剩余可评分额度（站点评分表「今日剩余」）。
  final int left;

  /// 站点下拉实际给出的可选分值（已按今日剩余裁剪）。
  final List<int> presets;

  const RateField({
    required this.id,
    required this.label,
    this.min = 0,
    this.max = 1,
    this.left = 1,
    this.presets = const <int>[],
  });

  /// 本次实际可选的最大分值。
  int get ceiling => max < left ? max : left;
}

class RateOptions {
  final List<RateField> fields;
  final bool canNotify;

  /// 站点返回的不可打赏提示（如 24 小时内额度已用完）。
  final String notice;

  const RateOptions({
    this.fields = const <RateField>[],
    this.canNotify = false,
    this.notice = '',
  });

  /// 解析失败时的兜底：站点普通用户组每项每天上限均为 1。
  static const RateOptions fallback = RateOptions(
    fields: <RateField>[
      RateField(id: 1, label: '好评', max: 1),
      RateField(id: 2, label: '金币', max: 1),
    ],
  );
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

  /// 点赞（站点「支持/顶一下」）接口地址，含 tid 与 hash；无入口时为 null。
  final String? supportUrl;

  /// 点赞人数（站点 `#recommendv_add`）；解析不到时为 null。
  final int? supportCount;

  /// 收藏接口地址，含 formhash；无入口时为 null。
  final String? favoriteUrl;

  /// 楼主关注入口（`home.php?mod=spacecp&ac=follow&op=add|del&…&fuid=…`）。
  /// 游客 / 自己 / 无权限时站点不渲染该链接，此时为 null。
  final String? followUrl;

  /// 关注 / 取消关注需要的 formhash（站点 formhash，与回复共用）。
  final String? followHash;

  /// 当前登录用户是否已关注楼主（入口为 `op=del` 时 true）。
  final bool following;

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
    this.supportUrl,
    this.supportCount,
    this.favoriteUrl,
    this.followUrl,
    this.followHash,
    this.following = false,
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

/// 站点轻量动作（点赞 / 收藏）结果。
class SiteActionResult {
  final bool success;
  final String message;

  const SiteActionResult({required this.success, required this.message});
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
  final String? uploadhash;
  final int? uid;

  const PostForm({
    required this.canPost,
    this.action,
    this.formhash,
    this.posttime,
    this.categories = const <ThreadCategory>[],
    this.notice,
    this.uploadhash,
    this.uid,
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

class FriendItem {
  final int uid;
  final String username;
  final String avatar;
  final String note;

  const FriendItem({
    required this.uid,
    required this.username,
    this.avatar = '',
    this.note = '',
  });
}
