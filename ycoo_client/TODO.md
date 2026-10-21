# Yuan Forum 任务清单（ycoo_client）

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

## 完成边界
- P3 完成 = 设计系统全站接入 + 自动化引擎纯逻辑化 + analyze 0 issue + 11 测试全过
- P5 完成 = 付费购买 / 剪贴板识别 / 站内跳转 / 双域名切换 + analyze 0 issue + 12 测试全过
- P4 完成 = 附件下载 / 引用折叠 / 收藏版块 / 动态取色 / 后台签到 + analyze 0 issue + 12 测试全过
- P6 完成 = 付费购买修复 + analyze 0 issue + 17 测试全过 + CI 出包
- P7 完成 = 正文排版对齐移动端 + analyze 0 issue + 17 测试全过 + 41 样本 0 残留
- P8 完成 = 我的页积分/统计取值准确 + analyze 0 issue + 29 测试全过 + 真实接口实测一致
- APK 产物：`dist/ycoo-client-1.0.9.apk`（本地）、v1.0.10 起由 GitHub Actions 产出
