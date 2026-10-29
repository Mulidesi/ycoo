# Yuan Forum 任务清单（ycoo_client）

> 本文中 `lib/`、`test/`、`tool/` 等路径均以 `ycoo_client/` 工程目录为基准；项目文档（AGENTS / DESIGN / README）在仓库根目录。

## P0 — 基础（已完成，v1.0.0）

- [x] 站点结构分析（Discuz! X3.5 + comiis 模板，HTML 解析）
- [x] Cookie 持久化 HTTP 客户端、登录、版块/列表/详情/回复/签到全链路
- [x] Material 3 主题（亮/暗）、多端适配（窄屏底栏 / 宽屏 NavigationRail）

## P1 — 修复与图片（已完成，v1.0.1–v1.0.2）

- [x] 正文不完整修复（locked 顶掉正文 → 递归内容解析）
- [x] 回复失败修复（inajax 成功响应解析）
- [x] 图片加载统一栈（Cookie / Referer 降级 / SVG 占位 / 错误原因）

## P2 — 列表缩略图与版式（已完成，v1.0.3）

- [x] 移动端 JSON 接口 → 列表首图 + 摘要（PreviewStore 节流）
- [x] 卡片式帖子行（作者行/标题/摘要/首图/数据行）
- [x] 正文图片限高 + 裸链接可点击
- [x] 正文与评论视觉分离（独立白卡 vs 平铺评论）

## P3 — 设计系统与自动化合并（已完成，v1.0.4，合并自 yuan_forum）

- [x] `lib/design/tokens.dart`：颜色/间距/圆角/字号/运动/尺寸 + `YuanSemanticColors` 语义色 ThemeExtension（亮/暗对等）
- [x] 主题接入语义色，全站 UI（thread_tile / html_content / detail / sign / profile）替换硬编码色
- [x] 悬浮液态玻璃底栏（三 Tab：首页/版块/我的），签到并入「我的」
- [x] 帖子层级硬约束落地：正文 16/26、回帖 14/22、回帖左轨线、表面色三档
- [x] 自动化领域逻辑：`automation_engine`（预设随机 + {author}/{title} 占位符）、`auto_reply_queue`（tid 去重）、`checkin_service`（12h 去重窗口调度）
- [x] AppState 接入：预设 5 条随机回复、自动化日志（回复/签到各留 200/100 条）、外观三态
- [x] 「我的」页重构：签到入口、预设编辑器（增删 5 条）、自动化记录查看、外观选择
- [x] 核心工具移植：`site_config`（站点能力位）、`app_exception`（统一错误文案）、`link_resolver`（站内 tid/fid 解析）、`download_service`（附件流式下载）
- [x] `app.dart` themeMode 由设置驱动（system/light/dark 持久化）

## P5 — 付费购买 / 链接直达 / 双域名（已完成，v1.0.6）

- [x] 付费帖应用内购买：解析 locked 块的 `mod=misc&action=pay` 链接、价格（如"5 星币"）、已购人数；`buyThread` 弹窗取 formhash → POST paysubmit → 重新拉帖验证解锁（离线样本 t_152621 验证）
- [x] 正文站内链接应用内跳转：`html_content` 点击先经 `openInAppIfInternal`（帖子→详情页，版块→列表页），非站内才走外部浏览器；路由经 `core/navigation/in_app_nav.dart` 注册避免循环依赖
- [x] 剪贴板链接识别：冷启动首帧 + 回前台读取剪贴板，命中 `ycoo.net` / `pc.sysbbs.com` 帖子/版块链接弹窗询问打开；同一内容只提示一次，设置可关
- [x] 双域名设置：`kBaseUrl` 改为可变全局；设置页「站点与网络」支持主域名切换（ycoo ↔ sysbbs，切换清 Cookie 需重登）+ 逐域名访问测试（延迟/可用性）
- [x] 登录页域名选择（v1.0.7）：SegmentedButton 选登录域名，所选域名即 APP 主域名并持久化；切换即时生效（登录请求发往新域名）；退出/切换域名后 RootGate 自动回到登录页，页脚文案跟随当前域名
- [x] 购买修复（v1.0.8）：Discuz `forum/pay.htm` 表单 action 为 `mod=misc&action=pay&paysubmit=yes&infloat=yes` 不含 tid（tid 在隐藏域），buyThread 在 POST body 与 URL 双侧补 tid；GET 弹窗补 infloat/handlekey/inajax；弹窗阶段站点消息（已购买/余额不足）透传。离线 tool/pay_regex_check.dart 验证表单解析
- [x] 新增单测 link_resolver_test（12/12 过）+ 离线脚本 tool/pay_check.dart

## P4 — 附件/楼中楼/收藏/取色/后台签到（已完成，v1.0.9）

- [x] 附件卡片 UI + 下载进度：解析 pattl 非图片附件（name/sizeText/`mod=attachment` 链接）→ Post.attachments；详情页附件卡片（按扩展名图标），流式下载带百分比进度条，复用登录 Cookie+Referer；公共 Download 目录不可写（Android 10+ scoped storage）时回落应用专属目录
- [x] 楼中楼引用折叠：评论 PostContent `collapseQuotes` 模式下 >60 字引用块默认收起为单行预览，点击展开/收起
- [x] 收藏板块：favoriteFids 本地持久化；版块卡片星标切换 + 「我的收藏」快捷磁贴区
- [x] 动态取色：dynamic_color DynamicColorBuilder；「Material You 动态取色」开关（默认开，Android 12+ 壁纸取色覆盖 ColorScheme，语义色 tokens 不变）
- [x] workmanager 后台周期签到：MainApplication.kt 自定义 WorkManager 配置；登录后注册 4 小时周期任务（回调重建 AppState → autoSignIfNeeded，当日去重），登出/切域名取消；仅 Android

## P6 — 付费购买修复（v1.0.10）

- [x] 根因定位（真实抓包 thread-153650）：购买成功后站点**仍保留** `div.locked`，内容退化为
      `<a href="…action=viewpayments…">记录</a> 付费主题, 价格: 5 星币`。旧逻辑「locked 含星币 → 仍需购买」
      导致 POST 已成功（`succeedhandle_('…','主题购买成功')`）却提示购买失败、且买完仍显示锁定
- [x] 解析层：`div.locked` 改为按「购买入口 `a[href*=action=pay]` + 阻塞措辞」判定，
      已购信息栏（`action=viewpayments` / `付费主题, 价格` / 正文已回到 `#postmessage`）不再算锁定
- [x] 消息层：`parseAjaxMessage` 支持 `succeedhandle_`（handlekey 为空）与 `errorhandle_*`，
      购买成功/余额不足等站点原文不再丢成空串
- [x] 流程层：提交补 `handlekey=pay`；成功判定改为「回调文案 + 重新拉帖」双通道，拉帖异常不再静默吞掉
- [x] 回归：`test/paid_thread_test.dart`（6 例，含 MockClient 全流程回放）；`tool/pay_check.dart` 改为带期望值的断言脚本
- [x] 验证：真实抓包样本 5/5 符合预期；`flutter analyze` 0 issue；`flutter test` 17 全过
- [x] CI：GitHub Actions 自动构建 release APK 并上传 artifact

## P7 — 正文排版对齐移动端（v1.0.11）

- [x] 附件小图标过大：`#postmessage` 内 `<ignore_js_op>` 的 `static/image/filetype/*.gif`（16px 行内图标）
      被当正文图片渲染成整屏问号 → 解析层抽成附件卡片并从正文移除，`_imageUrl` 过滤 filetype 路径
- [x] 隐藏文案泄漏：`display:none` 的 `.tip`（「点击文件名下载附件」「21 小时前 上传」）被当正文输出 →
      新增 `_isHidden()`，按 inline style 与 `.tip` 类名跳过
- [x] 附件行样式：改为单行「文件名  (13.83 KB)」，图标 20→17，与移动端网页一致；
      下载失败文案移到行下方独立小字，不再挤在文件名下撑高行
- [x] 大小解析兼容两种模板：`<em class="xg1">(13.83 KB, 下载次数: 531)</em>` 与 `<p>5.92 KB, 下载次数: 6</p>`
- [x] 空正文误报：附件抽出后 `contentHtml` 只剩空白 → 新增 `_hasVisibleBody()`，
      只有附件的帖子不再显示「正文需登录或购买后可见」/「（该楼内容不可见）」
- [x] 回归：`tool/attach_check.dart` 改为断言脚本（含 41 个样本全量扫描，leak=0）；
      `test/preview_attach.dart` 输出 `goldens/attach_body.png`、`goldens/attach_mixed.png` 供人工比对
- [x] 验证：`flutter analyze` 0 issue；`flutter test` 17 全过；全样本 168 楼 0 残留

## P8 — 我的页积分与统计（v1.0.12）

- [x] 问题：`me()` 用正则从 `home.php?mod=space&do=profile` 抠「积分/主题数/回帖数/好友数」，
      模板改版后全部失配，「我的」页显示 `—` 或错值
- [x] 数据源换成移动端 JSON 接口 `api/mobile/index.php?version=4&module=profile&uid=N`：
      与 `spacecp&ac=credit&showcredit=1`（星币/经验/积分）、`space-uid-N.html`（帖子/关注/粉丝）同源，结构化且免登录
- [x] `parseProfileApi()`：`space.credits` → 总积分、`extcredits*` → 经验/贡献/星币（按 `Variables.extcredits[*].title`
      映射，站点改编号不错位）、`posts/threads/following/follower/friends/oltime/views/feeds/regdate`
- [x] `parseDiscuzUid()`：从任意登录态页面的 `discuz_uid` 取 UID，作为跳转 URL 与头部链接之外的第三来源
- [x] `parseProfile()` HTML 兜底同步增强：积分页取星币/经验/贡献/总积分+公式，空间页取「714 帖子 / 20 关注 / 188 粉丝」
- [x] `me()` 流程：资料页取 UID → 接口取准确数值 → `mergeMissingFrom` 用 HTML 补头像/用户组 → 接口失败自动退回 HTML
- [x] `DiscuzClient.get(absorbCookies: false)`：接口会重发 `saltkey`，避免污染登录会话
- [x] UI：资料卡改为两排 3 列 —— 上排「星币 / 经验 / 积分」，下排「帖子 / 关注 / 粉丝」，
      副行显示「主题 · 贡献 · 好友 · 在线时长」，数字加千分位
- [x] 回归：`test/user_stats_test.dart` 12 例（含 MockClient 走通 `me()` 全链路与接口 500 降级）；
      `tool/stats_check.dart` 离线断言 + `--live` 真实接口；`test/preview_profile.dart` 输出 `goldens/profile_card.png`
- [x] 验证：真实接口实测 星币 2021 / 经验 8456 / 积分 9207 / 帖子 714 / 关注 20 / 粉丝 188（与站点一致）；
      `flutter analyze` 0 issue；`flutter test` 29 全过

## P9 — 预设初始化 + 底栏不遮挡内容（v1.0.13）

- [x] 问题 1：自动回复预设首次启动是空列表 → `automation.pickPreset()` 抛 `没有可用的自动回复预设`，
      「隐藏贴自动回复」开关打开也不回帖，设置页副标题显示「尚未设置」
- [x] `AppSettings.defaultReplyPresets`：5 条通用致谢预设（取满 `Preset.maxCount`，随机取一时有差异）
- [x] 三处兜底：构造参数为空 / `fromJson` 读到空数组 / `effectivePresets` 归一化后为空，都回落到默认预设
- [x] 老版本迁移：只存过一条内置默认语（`感谢分享，感谢楼主！`）的视为「没设置过」，一并升级成整套；
      自定义过 `replyContent` 的仍保留用户原话
- [x] `updateReplyPresets`：全部清空时不留空状态，回落到默认预设并同步 `replyContent`
- [x] 预设编辑弹窗新增「恢复默认」按钮；提示文案说明「全部清空会回落到默认预设」
- [x] 问题 2：`Scaffold(extendBody: true)` 的悬浮底栏盖在内容之上，首页 / 版块 / 我的三个列表末条被胶囊挡住
- [x] `YuanSizes.barTotalHeight`（4 + 64 + 12）+ `bottomBarInset(safeBottom)`，安全区在 `removePadding` 之前取
- [x] `BottomBarInset`（InheritedWidget）由 `HomeShell` 窄屏分支注入；`ThreadListView` / 版块页 / 我的页
      把 `BottomBarInset.of(context)` 加进 `ListView.padding.bottom`；二级路由自动为 0
- [x] 回归：`test/automation_presets_test.dart` 13 例、`test/bottom_bar_inset_test.dart` 6 例；
      `test/preview_home.dart` 输出 `goldens/home_bottom.png`
- [x] 验证：`flutter analyze` 0 issue；`flutter test` 48 全过（1 项因缺 recon 样本跳过）

## P10 — 液态玻璃底栏与回复栏（v1.1.0）

- [x] 底栏选中态去掉椭圆背景块：仅 `brand.primary` + 填充图标 + `w600` 标签，图标/文字 150ms 过渡
- [x] 底栏容器迁移到 `liquid_glass_widgets` 1.x `GlassContainer`，磨砂/厚度参数统一走 `YuanGlass`
- [x] 详情页底部改为悬浮玻璃回复栏 `GlassReplyBar`：收起（输入胶囊 + 点赞/收藏/分享）↔ 展开（多行输入 + 右下角发布）
- [x] 点赞（站点「支持」）：`supportThread` + 成功/重复/失效文案区分，成功本地高亮
- [x] 收藏：`favoriteThread`，成功后本地高亮（站点无取消收藏入口，不做反向操作）
- [x] 分享：`GlassModalSheet` 弹层（复制链接 / 在浏览器打开）
- [x] 工具链升级 Flutter 3.41.9 / Dart 3.11.5（`liquid_glass_widgets` 依赖 `Color.withValues`），CI `flutter-version` 同步
- [x] 全仓清理 3.41 弃用项：`withOpacity` → `withValues`、`CardTheme` → `CardThemeData`、`FormField.value` → `initialValue`、Radio → `RadioGroup`
- [x] 回归：`test/thread_actions_test.dart` 9 例、`test/glass_reply_bar_test.dart` 3 例；analyze 0 issue

## P11 — v1.1.0 发布构建修复（v1.1.1）

- [x] Android 工具链对齐 Flutter 3.41.9 模板：Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 / JDK 17（原 8.3 / 8.1.0 / 1.8.22 触发 CI 的 AGP 最低版本检查）
- [x] `workmanager` 0.5.2 → 0.10.10：旧版使用已被 Flutter 3.41 移除的 v1 embedding API，Android 无法编译
- [x] 新增 `tool/patch_flutter_gradle_plugin.sh`：修复 Flutter 3.41.9 Gradle 插件的 `com.android.Version` 编译期引用与 `:gradle:jar` 重复类问题，CI 构建前执行
- [x] 本地 `flutter build apk --release` 通过（59.1MB），推 v1.1.1 tag 后 CI 出包并发布 Release
- 完成 = analyze 0 issue + 全量测试全过 + CI 产出 `ycoo-client-1.1.1.apk`

## P12 — AppState 服务层拆分与架构重构（v1.1.3）

- [x] 新增 `core/storage/settings_repository.dart`：SharedPreferences 统一读写入口（Cookie / 设置 / 签到 / 回复 / 日志 / 剪贴板），AppState 不再直接操作 SharedPreferences 或 import `dart:convert`
- [x] 新增 `core/session/session_service.dart`：登录 / 登出 / 用户信息 / Cookie 持久化 / 会话恢复
- [x] 新增 `core/services/checkin_service.dart`：签到操作 / 状态查询 / 自动签到调度 / 签到日志 / 后台签到注册与取消
- [x] 新增 `core/services/reply_service.dart`：自动回复判定与执行 / 手动回复 / tid 去重 / 日限额 / 回复日志 / 预设队列同步
- [x] AppState 瘦身（772→522 行）：业务方法委托给 Service，保留 UI 状态（booting / homeTabIndex / homeRefreshTick）和设置编排
- [x] 平台判断收敛：`Platform.isAndroid` 全部收进 `background_checkin.dart`，`main.dart` / `app_state.dart` / `checkin_service.dart` 调用方零判断
- [x] 新增 `state/settings_model.dart`：`AppSettings` + `dayKey` 从 app_state.dart 外移（514→187 行独立模型），Service 层改为导入 settings_model，打破 Service → AppState 反向依赖
- [x] 新增 `core/services/site_manager.dart`：切站编排（更新 base URL → 清 Cookie → 清用户 → 清签到状态 → 清图片缓存 → 取消后台签到），AppState.switchSite 只留持久化 + notify
- [x] `clearAllImageCache()` 收敛到 `core/image_loader.dart` 单一实现，AppState / SessionService 共用
- [x] AppState 二次瘦身（522→265 行，达成 ≤300 目标）：app_state.dart 仅剩 UI 状态 + 服务委托 + init 编排；ForumApi / PreviewStore 跟随 client 构造注入（测试可传 MockClient）
- [x] 修复预存测试失败：`user_space_test` 期望基础设施层抛 `AppException`（500 → `AppException.server`），业务层仍抛 `ForumException`
- [x] 验证：`flutter analyze` 0 issue；`flutter test` 130 全过（1 项因缺 recon 样本跳过）
- [x] 发布 v1.1.3+24：推 tag 由 GitHub Actions 构建 per-ABI APK 并发布 Release + latest.json
- [x] 修复发版 CI：manifest 生成把 abi/size/sha 拼成单个加引号参数，Python 只收到一个 argv 导致 `apks` 恒为空 IndexError；改为 bash 数组逐项传参 + `$GITHUB_WORKSPACE` 绝对路径定位 APK + 零匹配快速失败诊断（929b0ff），v1.1.3 tag 重指后重跑成功

### P12 待优化（后续迭代）

> 核心原则检查：UI 层只渲染 + 回调，State 层只留视图状态，业务能力归 Service，数据层管持久化，基础设施管网络 / Cookie / 缓存。

| 优先级 | 问题 | 当前状态 | 目标动作 |
|--------|------|----------|----------|
| P1 | 敏感数据明文存储 | `AppSettings.savedPassword` 经 `toJson()` → `jsonEncode` → SharedPreferences 明文（settings_model.dart 序列化时直接输出） | 引入 `flutter_secure_storage`（Android/iOS 走 EncryptedSharedPreferences/Keychain）；Web/Linux/macOS 降级为内存态不持久化密码；或改为仅存 token 不存密码 |
| P2 | DiscuzClient 与 CookieStore 耦合 | `discuz_client.dart` 构造函数已接受 `CookieStore? store` 参数（部分可注入），内部直接操作 `store` 实例 | 如需多账户支持，抽取 `SessionManager` 管理多套 Cookie 按域名隔离；当前单站点场景优先级低 |
| P2 | background_checkin 反向依赖 AppState | `core/automation/background_checkin.dart` 的 isolate 回调 `AppState()` 全量引导（需 repo + settings + 会话恢复），core → state 反向引用 | 抽取轻量 `CheckinBootstrap`（只建 repo/client/session/checkin 四件套），或接受现状（后台 isolate 必须完整引导，注释已说明） |
| P2 | user_nav 反向依赖 AppState | `core/navigation/user_nav.dart` import app_state.dart 做站内路由跳转 | 路由回调改由 main.dart 注册时闭包注入，core 层持函数引用而非 AppState |

- 完成 = AppState ≤300 行（达成 265）+ 编排逻辑下沉 Service + 敏感数据加密 + 测试全过 + analyze 0 issue

## P13 — 用户反馈：帖子等级显示 / 关注体系 / 我的页入口（v1.1.5）

> 来源：App 用户反馈（2026-10-27）。参考链接为 sysbbs 域名（P5 双域名之一），接口均为 Discuz! X3.5 标准格式，实现时一律 `kBaseUrl` 拼相对路径，禁止硬编码域名。
>
> 现状核实：详情页楼主 / 回帖头像已可点进 UserSpacePage（`openUserFromAvatar`，thread_detail_page.dart:311/497）；`UserProfile.group/level` 字段已有（models.dart:195）；`userThreads()` 已拉他人主题列表（forum_api.dart:529）但只有主题一种；`ac=usergroup` / `ac=follow` / `mod=follow` 全仓零命中；formhash 获取与 `parseAjaxMessage`（succeedhandle_/errorhandle_ 透传）可直接复用。

### 帖子正文优化

- [x] R1 帖子作者等级显示：解析 `a.km_lvs`（PC 模板，`Lv.7`，链接带 `ac=usergroup&gid=N`），移动模板 `a.top_lev` 兜底；`Post.level` 新增字段，详情页楼主与回帖作者行均显示徽章。不做点击跳用户组页（客户端无对应页面，外链体验差）
- [x] R2 关注 / 取关：帖子页解析 `a#followmod_{uid}`（`op=add` 带 hash / `op=del` 已关注 / `op=relay` 转播需排除），楼主行加关注按钮；`UserSpacePage` 资料卡加关注按钮，状态由空间页 `#followmod_{uid}` + `parseFormhash` 得出；`ForumApi.setFollow` 走 `ac=follow&op=add|del&hash=…&fuid=…` + `inajax=1`，`parseAjaxMessage` 透传站点文案（成功 / 来路不正确 / 无权限）

### 我的页面优化

- [x] R3 「我的帖子」入口 + 双 Tab 页：ProfilePage「社区」分区磁贴 + 顶部「帖子」数字可点；新页 `MyPostsPage`，主题复用 `userThreads`，回帖走 `home.php?mod=space&uid=N&do=reply&view=me`，新增 `parseUserReplyList`（`goto=findpost&ptid=` 优先，`thread-N` 兜底）并统一映射回主题
- [x] R4 「我的关注」入口 + 关注 / 粉丝页：ProfilePage「关注 / 粉丝」数字改为可点（粉丝直达 Tab2）；新页 `FollowListPage` 双 Tab，数据源 `home.php?mod=space&uid=N&do=follow|follower&view=…&from=space&page=N`，`parseFollowList` 解析 `a[href*=mod=space&uid=]` 昵称锚点 + 行内头像 / 签名
- [x] R5 列表头像点击进主页：他人空间页、我的帖子列表的 `ThreadTile` 补 `onAvatarTap`（原本只有搜索 / 版块列表接线）；关注 / 粉丝行整行可点进 `UserSpacePage`

- [x] 验证：`flutter analyze` 0 issue；`flutter test` 全过（新增 `test/follow_test.dart` 15 例，CI 离线用例清单已同步）
- [x] 发布 v1.1.4+25：推 tag 由 GitHub Actions 构建 per-ABI APK 并发布 Release + latest.json
- [x] 修复 v1.1.4 反馈「R2 未生效」：`ForumApi.thread` 重建 `ThreadDetail` 时漏拷 `followUrl/followHash/following`，解析结果被丢弃导致关注按钮不渲染；补字段并加接口级回归测试；关注入口解析增加「无 followmod id 时按 ac=follow&fuid 兜底」
- [x] 发布 v1.1.5+26：修复关注按钮后重打包
- 真实接口实测（等级显示 / 关注取关 / 回帖列表 / 粉丝列表）待客户端联网后确认；沙箱访问站点 TLS 间歇失败

## P14 — 用户反馈：搜索筛选 / 首页返回空白（v1.1.6）

> 来源：GitHub Issues（2026-10-27）。#1 搜索无法像网页端筛选；#2 从版块页点回首页出现短暂空白。
> 参考链接为 ycoo.net（主域名），接口为 Discuz! X3.5 + twpx_xunsearch 插件标准格式，实现时一律 `kBaseUrl` 拼相对路径，禁止硬编码域名。

- [x] 发布 v1.1.6+27：搜索筛选 + 首页骨架屏

### 搜索筛选（Issue #1）

> 现状核实：
> - 当前 `ForumApi.search` 固定参数 `plugin.php?id=twpx_xunsearch&q=$kw&m=&syn=yes&f=_all&s=relevance&fid=0&p=$page`（forum_api.dart:64-75），无任何筛选 UI。
> - 网页端筛选条件（实测 search.php 表单 HTML）：
>   - 搜索范围 `f`：全文 `_all` / 标题 `subject` / 用户名 `author`
>   - 模糊搜索 `m`：checkbox，勾选时提交 `m=yes`
>   - 同义词 `syn`：checkbox，默认勾选 `syn=yes`
>   - 排序 `s`：相关性 `relevance` / 时间倒序 `dateline_DESC` / 时间顺序 `dateline_ASC`
>   - 版块 `fid`：空=所有版块，否则指定版块 id（表单 optgroup 分组：书源交流/网络资源/小说专区/综合交流/福利娱乐/日常站务/广播专区）
> - 版块列表数据已有 `api.boards()`（BoardsPage 使用），`loadBoards` 已导出供搜索页复用（boards_page.dart:301-302）
> - 解析器 `parseXunsearchResults` 已解析 fid/作者/时间/标题，结果结构无需改

- [x] R1 搜索范围筛选：全文 / 标题 / 用户名（SegmentedButton），映射 `f=_all|subject|author`
- [x] R2 排序筛选：相关性（默认）/ 时间倒序 / 时间顺序，映射 `s=relevance|dateline_DESC|dateline_ASC`
- [x] R3 版块筛选：所有版块 + 站点版块分组列表（复用 `api.boards()`，选择器用底部弹层按分组列出），映射 `fid`（空=所有版块）
- [x] R4 模糊搜索开关（默认关）、同义词开关（默认开，与网页一致），映射 `m=yes` / `syn=yes`
- [x] R5 筛选 UI：搜索结果页顶部筛选条（SegmentedButton + ActionChip 排序/版块 + FilterChip 开关），任一条件变更自动重新搜索
- [x] R6 `ForumApi.search` 扩展可选参数 `{searchField, sortBy, fid, fuzzy, synonym}`，缺省沿用现默认值
- [x] 边界：筛选后无结果 → EmptyView 文案区分「没有找到相关帖子」与「没有符合条件的帖子，试试调整筛选」；私密版块无权限站点返回空，正常降级
- [x] 验证：`flutter analyze` 0 issue；`flutter test` 全过（155 过 + 1 项因缺 recon 样本跳过），新增 `test/search_filter_test.dart` 6 例覆盖 URL 拼装/解析/频率限制 + `test/search_page_test.dart` 2 例筛选条 widget 冒烟

### 首页返回空白（Issue #2）

> 现状核实（根因）：
> - 底栏点「首页」→ `selectHomeTab(0)` → `homeRefreshTick++`（app_state.dart:73-75）→ FeedPage `_onStateChanged`（feed_page.dart:59-67）→ `_refreshTicks[view]++` → ThreadListView 的 `ValueKey` 变化（feed_page.dart:148）→ 列表组件销毁重建 → `_initialLoading=true` → 整屏 LoadingList 转圈，网络期间呈现空白。
> - HomeShell 的 IndexedStack 保活 FeedPage，但列表因 key 变化被重建，已加载数据丢弃。

- [x] R1 切回首页保留强制重建刷新（用户确认可接受），重建期间用骨架屏动画占位，不再整屏空白
- [x] R2 骨架屏为微光扫过动画，卡片布局对齐 ThreadTile（头像/作者行/标题/摘要/首图/数据行），替换 ThreadListView 空白加载态；骨架色走语义 token（surfaceContainerHigh + surfaceDim），新增 `test/skeleton_test.dart` 2 例
- [x] 验证：`flutter analyze` 0 issue；`flutter test` 全过（147 过 + 新增 2 例，1 项因缺 recon 样本跳过）

## P15 — MT 对照优化：结构 / UX / 功能（分析完成，待实施）

> 来源：对开源项目 mtforum-app（github.com/Aioprh/mtforum-app）的源码结构、样式与交互分析，
> 结合源论坛（ycoo.net / pc.sysbbs.com 镜像）站点结构实测。
> MT 项目路径 `/tmp/opencode/mtforum-app`（18630 行 Dart，已 clone 可复用参考）。
>
> 分析结论速览：
> - **结构**：MT 是单文件大仓库（forum_repository 3392 行、thread_page 2869 行），
>   ycoo_client 已按页面/组件分文件 + 解析器独立库，结构更清晰，无需照搬 MT 的组织方式。
> - **UX**：MT 的楼层交互（回复/复制/举报/打赏/PM/编辑/删除/置顶）、投票卡片、
>   楼中楼点评列表、发帖草稿、表情面板三套切换、发帖高级选项（阅读权限/价格/回复可见）
>   等交互细节值得借鉴。
> - **功能**：MT 覆盖投票/评分/打赏、编辑/删除帖、举报、PM 私信、好友/关注、
>   勋章、积分商城、排行榜、通知、离线缓存、下载管理历史、WAF 本地求解等，
>   ycoo_client 目前仅有关注/收藏/签到/自动回复/附件下载，差距集中在「帖子互动增强」
>   与「离线/下载管理」两块。
>
> 实施原则：一律 `kBaseUrl` 拼相对路径，禁止硬编码域名；解析层保持纯 Dart；
> 帖子正文与回帖必须保持视觉层级差（16/14、左轨线 3px）；颜色/间距/圆角/字号走 tokens.dart。

### P15-A 帖子互动增强（投票 / 打赏 / 楼中楼 / 举报 / 编辑删除）

> MT 对照：`ForumPost` 含 `comments`（楼中楼）、`rates`/`rateSummary`（打赏记录）、
> `Poll`（投票选项+票数+多选标记）、`_ReportSheet`（5 类原因+补充说明）、
> `_EditPostPage`（编辑+@好友+附件上传+删除确认）。
> ycoo_client 现状：`Post` 模型仅 `pid/author/avatar/floor/timeText/level/contentHtml/isOp/attachments`，
> 详情页只有回复/购买/收藏/支持/关注/分享/附件下载，无投票/打赏/楼中楼/举报/编辑删除。

- [ ] R1 投票解析与交互：`parsers.dart` 解析 `poll` 块（选项/票数/多选/已投/过期）；
      `Poll`/`PollOption` 模型；详情页楼主楼层下方投票卡片（勾选 + 提交投票按钮 + 票数条形图）；
      投票提交走 `forum.php?mod=post&action=poll&tid=…&fid=…&formhash=…`（inajax）
- [ ] R2 打赏/评分解析与交互：`parsers.dart` 解析 `_parseRates`（打赏记录 + 评分项）；
      `RateField`/`RateOptions`/`RateRecord` 模型；详情页楼层底部打赏按钮 → `_RateSheet` 弹层
      （勾选积分项 + 理由 + 通知作者）；楼主层「赞赏」按钮；打赏记录列表渲染
- [ ] R3 楼中楼点评：`parsers.dart` 解析 `_parseComments`（点评 author/text/uid/time）；
      `ForumComment` 模型；`Post` 新增 `comments` 字段；楼层卡片内嵌点评列表
      （点击点评可发起引用回复）
- [ ] R4 举报：楼层操作菜单新增「举报」→ `_ReportSheet` 弹层（5 类原因单选 + 补充说明）；
      提交走 `forum.php?mod=report&action=submit&…`（inajax），复用 `parseAjaxMessage`
- [ ] R5 编辑/删除帖：楼层操作菜单新增「编辑」「删除」（仅自己帖子 + 楼主非自己时可编辑回复）；
      编辑走 `forum.php?mod=edit&action=edit&pid=…&tid=…&fid=…`（复用 MT `_EditPostPage` 交互范式：
      标题/正文/@好友/附件上传/插入链接/插入媒体）；删除走 `forum.php?mod=delete&action=delete&pid=…`（确认弹窗）
- [ ] R6 楼层操作菜单：详情页每个楼层底部加 `_floorAction`（回复/复制楼层）+ `PopupMenuButton`（更多操作：
      举报/打赏/PM/编辑/删除）；楼主楼层额外加「赞赏」按钮

### P15-B 发帖页增强（表情 / 草稿 / 附件上传 / 高级选项）

> MT 对照：`ComposePage` 含标题/正文/表情面板（三套切换：默认/滑稽/Doge）/图片上传/@好友/
> 插入链接/插入媒体/附件上传/草稿保存恢复/高级选项（阅读权限/价格/回复可见/倒序/通知/签名）。
> ycoo_client 现状：`NewThreadPage` 仅标题/正文/版块选择/提交，无表情/草稿/附件上传/高级选项。

- [ ] R1 表情面板：`lib/ui/widgets/emoji_panel.dart`（移植 MT 三套表情：默认/滑稽/Doge，
      GridView 8 列，Set 切换）；发帖页正文输入框上方加表情按钮 → 面板展开
- [ ] R2 草稿保存：`shared_preferences` 存标题/正文/版块 fid/时间戳；发帖页 `initState` 恢复草稿；
      提交成功/手动清空后移除；`_draftSubject/_draftMessage/_draftFidKey/_draftAt` 键名
- [ ] R3 图片/附件上传：发帖页加图片选择（`image_picker`）+ 文件选择（`file_picker`）；
      上传走 `forum.php?mod=post&action=newthread&fid=…` 的 `uploadhash`/`uid` 表单
      （复用 MT `uploadAttachment` 参数），成功后插入 `[attachimg]$aid[/attachimg]`
- [ ] R4 高级选项：发帖页加「回复可见」「阅读权限」「价格」「倒序」「通知提醒」「使用签名」开关/输入；
      提交时拼入 `needreply`/`readperm`/`price`/`orderdesc`/`notify`/`signature` 参数
      （站点支持时生效，不支持时忽略）
- [ ] R5 @好友：发帖页加 @ 按钮 → 好友列表选择（`friend.php?mod=friend` 拉取）→ 插入 `@用户名 `

### P15-C 离线缓存与下载管理

> MT 对照：`OfflineThreadCache`（app-private 文件 + JSON 索引 + 图片缓存 80 张/8MB 上限 +
> 原子写入 tmp+rename + 图片 URL 映射）；`DownloadManager`（SharedPreferences 历史 +
> 进度回调 + 中断标记 + 下载目录去重）。
> ycoo_client 现状：仅有 `DownloadService`（附件流式下载，无历史记录/无离线缓存）。

- [ ] R1 离线帖子缓存：`core/services/offline_cache.dart`（移植 MT `OfflineThreadCache` 核心逻辑：
      app-private `offline_threads/` 目录 + `offline_threads.json` 索引 + 图片下载到本地 +
      `imageMap` URL 映射 + 原子写入）；详情页菜单「缓存帖子供离线阅读」；
      离线帖子列表页（「我的」页入口）
- [ ] R2 下载管理增强：`DownloadManager` 扩展为 ChangeNotifier + SharedPreferences 历史记录
      （`mt_forum_download_history_v1` 键）；下载记录含 url/path/name/time/status/receivedBytes/totalBytes/error；
      「中断」状态标记（应用关闭时下载中断可重下）；「我的」页下载历史入口
- [ ] R3 离线阅读：离线缓存帖子离线打开时走本地索引，不发起网络请求；
      图片从本地 `file://` 加载，`NetImage` 兜底远程 URL

### P15-D HTML 渲染器增强（对齐 MT post_html_view）

> MT 对照：`PostHtmlView`（643 行）支持 div/p/section/article/blockquote/pre/ul/ol/table/hr/
> h1-h6/iframe/video/img（懒加载）/a（图片链接展开）/smiley（表情图片过滤）/linkify（裸链接可点）。
> ycoo_client 现状：`html_content.dart` 384 行，支持 text/quote/code/image/divider 块。

- [ ] R1 `content.dart` 新增块类型：`table`（表格）、`pre`（代码块）、`video`/`iframe`（视频/嵌入）、
      `h1`-`h6`（标题层级）、`section`/`article`（分区）、`hr`（分隔线）
- [ ] R2 `html_content.dart` 渲染扩展：表格渲染为 `DataTable`（移动端横向滚动）；
      代码块等宽字体 + 背景色；视频用 `VideoPlayer` 或外链兜底；iframe 用 `WebView` 或外链
- [ ] R3 表情图片过滤：`_isSmiley` 逻辑（`static/image/smiley/` 路径的 img 跳过渲染，
      避免表情图标当正文图片）
- [ ] R4 裸链接可点：正文中的裸 URL 文本自动 `LinkifyText`（复用现有 `openInAppIfInternal` 逻辑）

### P15-E UX 细节对齐

> MT 对照：楼层座位标签（沙发/椅子/板凳/…/下水道）、楼主楼层卡片圆角 16 vs 回复 12、
> 楼主卡片浅色背景 vs 回复白色、点赞/踩双按钮、评论区分隔线+「评论区 N 条回复」标题、
> composer 栏回复目标提示条、SnackBar 文案统一。

- [ ] R1 楼层座位标签：`Post.floorLabel` 计算（floor≤1 空；2-10 沙发→下水道；>10 `$floor楼`）；
      详情页楼层右上角显示
- [ ] R2 楼主/回复卡片差异化：楼主卡片 `surfaceContainerHigh` 底色 + 圆角 16；
      回复卡片 `surface` + 圆角 12；楼主卡片左侧 4px primary 竖条
- [ ] R3 评论区分隔：首条回复前加「评论区 N 条回复」标题 + 竖线分隔（对齐 MT 视觉）
- [ ] R4 回复目标提示条：composer 栏展开时显示「回复 @作者 · 楼层」+ 取消按钮
- [ ] R5 SnackBar 文案：统一为「操作成功 / 请先登录 / 网络错误，请重试」三类，
      站点原文（如「主题购买成功」）透传时保留

### P15-F 帖子正文分享为图片（已完成，v1.1.7）

> 来源：用户反馈希望把帖子标题与正文生成分享图片，保存本地并用于站外传播。
> 规格：`.monkeycode/specs/2026-10-29-post-share-image/`。
> 范围：仅楼主正文；内嵌图片下载嵌入、失败占位；保存后调系统分享（`share_plus`）。
>
> 实现：`dart:ui` Canvas 纯命令式绘制（不依赖 widget 树），跨端可用、渲染逻辑可离线测试。

- [x] R1 分享入口：详情页分享弹层新增「分享为图片」（第 4 项，位于复制链接之前）；正文为空 / 锁定无权限时禁用并提示；失败保留「复制链接」降级
- [x] R2 内容渲染：`ShareRenderer` 绘制标题 + 楼主昵称/头像/时间 + 正文块（text/quote/code/image/divider）+ 页脚（站点名 · App 标识 / 帖子链接）
- [x] R3 图片嵌入：`ShareImageFetcher` 并发 ≤4、单张 ≤4MB、总数 ≤20；失败灰色占位「图片加载失败」；复用现有 ContentBlock（video/iframe 由 P15-D 渲染器扩展统一承接）
- [x] R4 尺寸与截断：宽 1080、2 倍图输出；高度自适应，超 8000px 或 100 行截断并标注「内容过长，仅展示部分内容」
- [x] R5 保存与分享：`persistPng` 写入本机（Android 公共 Download 优先，不可写回落应用目录）+ `share_plus` 系统分享（`sharePngFile`）；取消分享不删文件
- [x] R6 Web / 桌面降级：Web 走 `share_plus` `XFile.fromData` 下载；无分享面板时展示保存路径
- [x] R7 测试：`share_renderer_test`（11）/`share_image_service_test`（3）/`share_sheet_test`（2）共 16 例覆盖布局/渲染/截断/占位/弹层入口；`flutter analyze` 0 issue

- 新增依赖：`share_plus ^10.1.4`；Android `queries` 补 `SEND`（image/png + text/plain），`file_paths.xml` 补分享路径（cache/files/external Download）
- 验证：`flutter analyze` 0 issue；`flutter test` 171 过 + 1 跳过（缺 recon 样本）

### 完成边界
- P15-A 完成 = 投票/打赏/楼中楼/举报/编辑删除全部落地 + analyze 0 issue + 新增测试
- P15-B 完成 = 表情/草稿/附件上传/高级选项/@好友 + analyze 0 issue + 新增测试
- P15-C 完成 = 离线缓存 + 下载历史 + analyze 0 issue + 新增测试
- P15-D 完成 = HTML 渲染器扩展 + analyze 0 issue + 新增测试
- P15-E 完成 = 楼层标签/卡片差异化/评论区分隔/回复提示条 + analyze 0 issue + 全量测试全过
- P15-F 完成 = 分享为图片入口 + 渲染/保存/系统分享 + analyze 0 issue + 新增测试

## 完成边界
- P3 完成 = 设计系统全站接入 + 自动化引擎纯逻辑化 + analyze 0 issue + 11 测试全过
- P5 完成 = 付费购买 / 剪贴板识别 / 站内跳转 / 双域名切换 + analyze 0 issue + 12 测试全过
- P4 完成 = 附件下载 / 引用折叠 / 收藏版块 / 动态取色 / 后台签到 + analyze 0 issue + 12 测试全过
- P6 完成 = 付费购买修复 + analyze 0 issue + 17 测试全过 + CI 出包
- P7 完成 = 正文排版对齐移动端 + analyze 0 issue + 17 测试全过 + 41 样本 0 残留
- P8 完成 = 我的页积分/统计取值准确 + analyze 0 issue + 29 测试全过 + 真实接口实测一致
- P9 完成 = 预设默认初始化 + 底栏不遮挡列表 + analyze 0 issue + 48 测试全过
- P10 完成 = 液态玻璃底栏 + 玻璃回复栏 + 点赞/收藏/分享 + analyze 0 issue + 全量测试全过
- P11 完成 = Android 工具链升级 + workmanager 升级 + Gradle 插件补丁 + analyze 0 issue + 全量测试全过 + CI 出包
- P12 完成 = AppState ≤300 行 + 设置模型外移打破 Service 反向依赖 + 切站编排下沉 + analyze 0 issue + 全量测试全过
- P13 完成 = 帖子等级徽章 + 关注/取关 + 我的帖子双 Tab + 关注/粉丝页 + 头像跳转全覆盖 + analyze 0 issue + 全量测试全过 + CI 出包
- P14 完成 = 搜索筛选 + 首页骨架屏 + analyze 0 issue + 全量测试全过 + CI 出包
- P15-F 完成 = 分享为图片入口 + 渲染/保存/系统分享 + analyze 0 issue + 新增 16 测试全过 + CI 出包
- APK 产物：`dist/ycoo-client-1.0.9.apk`（本地）、v1.0.10 起由 GitHub Actions 产出
