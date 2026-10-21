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

## 完成边界

- P3 完成 = 设计系统全站接入 + 自动化引擎纯逻辑化 + analyze 0 issue + 11 测试全过
- P5 完成 = 付费购买 / 剪贴板识别 / 站内跳转 / 双域名切换 + analyze 0 issue + 12 测试全过
- P4 完成 = 附件下载 / 引用折叠 / 收藏版块 / 动态取色 / 后台签到 + analyze 0 issue + 12 测试全过
- APK 产物：`dist/ycoo-client-1.0.9.apk`
