# 源坛 · 源论坛第三方客户端

面向 [ycoo.net](https://ycoo.net)（源论坛）的原生 Flutter 客户端。一套代码覆盖 **Android / iOS / Windows / macOS / Linux / Web**，把 Discuz! 论坛重新做成了信息流 + 卡片式的移动端体验。

站点没有公开 API，客户端全部通过解析 HTML 实现，解析层保持**纯 Dart**，可以用真实抓取页面离线回归。

[![Android APK](https://github.com/Mulidesi/ycoo/actions/workflows/android.yml/badge.svg)](https://github.com/Mulidesi/ycoo/actions/workflows/android.yml)
[![Release](https://img.shields.io/github/v/release/Mulidesi/ycoo?label=release&color=blue)](https://github.com/Mulidesi/ycoo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![minSdk](https://img.shields.io/badge/Android-minSdk%2021-brightgreen)](https://developer.android.com)

---

## 下载

最新安装包在 [Releases](https://github.com/Mulidesi/ycoo/releases) 页面，由 GitHub Actions 自动构建。

| 版本 | 文件 | 说明 |
| --- | --- | --- |
| [v1.0.13](https://github.com/Mulidesi/ycoo/releases/tag/v1.0.13) | `ycoo-client-1.0.13.apk` | 自动回复预设默认初始化；悬浮底栏不再遮挡列表末条；versionCode 14 |
| [v1.0.12](https://github.com/Mulidesi/ycoo/releases/tag/v1.0.12) | `ycoo-client-1.0.12.apk` | 「我的」页积分/帖子/关注/粉丝改为接口取值，与站点一致；versionCode 13 |
| [v1.0.11](https://github.com/Mulidesi/ycoo/releases/tag/v1.0.11) | `ycoo-client-1.0.11.apk` | 正文排版对齐移动端：附件小图标不再被放大、隐藏提示文案不再泄漏；versionCode 12 |
| [v1.0.10](https://github.com/Mulidesi/ycoo/releases/tag/v1.0.10) | `ycoo-client-1.0.10.apk` | 修复付费主题购买；versionCode 11 |

- 支持 ABI：`arm64-v8a` / `armeabi-v7a` / `x86` / `x86_64`
- 使用 debug 签名，**仅供个人测试**，请勿二次分发
- iOS / 桌面端需自行用对应工具链构建（见下方「构建」）

## 功能

| 模块 | 能力 |
| --- | --- |
| 登录 | 用户名 / UID / 邮箱登录，支持安全提问；Cookie 持久化免登录；登录失败提示剩余尝试次数 |
| 首页 | 最新发表 / 热门 / 回复 / 精华 四个信息流，下拉刷新 + 触底加载 |
| 版块 | 分组折叠浏览、今日新增、主题/帖数、私密版块标识、收藏版块 |
| 帖子列表 | 置顶与分类标签、附件标识、作者与回复/查看数、首图 + 摘要卡片 |
| 帖子阅读 | 自研富文本渲染（段落/图片/引用/代码块）、图片缩放预览、楼层跳页、复制正文与链接 |
| 隐藏内容 | 区分「回复可见 / 购买可见 / 登录可见」并给出对应操作入口 |
| 付费主题 | 应用内星币购买，走 `misc&action=pay` 流程，成功后自动刷新解锁 |
| 附件 | 非图片附件卡片 + 流式下载进度，复用登录 Cookie 与 Referer |
| 签到 | 状态、连续天数、今日人数、排名、奖励；自动签到 + 后台周期签到（Android） |
| 我的 | 星币 / 经验 / 积分（积分页）+ 帖子 / 关注 / 粉丝（空间页），取自移动端接口，与站点数值一致 |
| 自动化 | 隐藏贴自动回复：预设默认初始化（5 条，可改可恢复默认）、随机延时、按 tid 去重、每日限额、版块白名单 |
| 站点 | 主域名切换（`ycoo.net` ↔ `pc.sysbbs.com`）、站内链接应用内跳转、剪贴板链接识别 |
| 外观 | Material 3 亮/暗主题、Material You 动态取色（Android 12+）、悬浮液态玻璃底栏 |

## 技术栈

| 项 | 选型 |
| --- | --- |
| 框架 | Flutter 3.24.5 / Dart 3.5.4 |
| 设计 | Material 3，令牌集中在 `lib/design/tokens.dart` |
| 状态 | Provider（`AppState extends ChangeNotifier`） |
| 网络 | `package:http` + 自维护 Cookie 表（Discuz 会话完全依赖 Cookie） |
| 解析 | `package:html`，解析层不 import Flutter，可离线回归 |
| 存储 | `shared_preferences`（Cookie / 设置 / 自动化日志） |
| 正文 | 自研 HTML → 内容块渲染器（`data/content.dart` + `ui/widgets/html_content.dart`） |

## 项目结构

```
.
├── .github/workflows/android.yml   # CI：analyze + 离线测试 + 构建 APK + 打 tag 自动发版
└── ycoo_client/                    # Flutter 工程
    ├── lib/
    │   ├── core/                   # HTTP 客户端、图片加载、站点能力位、自动化领域逻辑
    │   ├── data/                   # 解析器、正文渲染、接口封装
    │   ├── models/                 # Board / ThreadItem / Post / ThreadDetail ...
    │   ├── state/                  # AppState、列表预览缓存
    │   ├── design/                 # 设计令牌、液态玻璃底栏
    │   └── ui/                     # 主题、页面、通用组件
    ├── test/                       # 单元测试 / 布局测试 / 版式 golden
    ├── tool/                       # 离线回归与联调脚本（用真实抓包页面）
    └── dist/                       # 本地构建产物（不入库）
```

## 站点适配要点

源论坛是 **Discuz! X3.5 + comiis 模板**（`discuz_theme_n7`），伪静态路径 `thread-{tid}-{page}-1.html`、`forum-{fid}-{page}.html`，Cookie 前缀 `YPSa_2132_`。以下几条是踩过的坑，改解析前建议先看：

- **正文位置不固定**：楼主楼在「付费/回复可见」时没有 `#postmessage`，内容被 `div.locked` 顶掉，需要退到 `.t_fsz` / `td.t_f` / `.pcb` 递归取，否则正文整层丢失。
- **购买成功后 `div.locked` 不会消失**：内容退化成 `<a href="…action=viewpayments…">记录</a> 付费主题, 价格: N 星币`，正文回到 `#postmessage`。判断「是否仍需购买」必须看**购买入口 `a[href*=action=pay]` 与阻塞措辞**，只看「星币」会把已购帖判成锁定。
- **购买回调名可能没有 handlekey**：`misc&action=pay` 提交成功后返回 `succeedhandle_('…', '主题购买成功', {})`，下划线后为空，正则必须写 `\w*`；失败时是 `errorhandle_pay('抱歉，您的星币不足', {})`。
- **多个 `Set-Cookie` 被逗号拼接**：`expires` 里也含逗号，需按 `,(?=name=)` 切分，否则 Cookie 解析错位导致登录态丢失。
- **移动端模板会 302，但移动端 JSON 接口可用**：`?mobile=2` 会跳回桌面模板，所以正文/列表仍按桌面 HTML 解析；
  但 `api/mobile/index.php?version=4&module=profile&uid=N` 是**免登录可用的 JSON 接口**，
  「我的」页的积分与统计就走它（见下条）。
- **积分/统计别去正则爬页面**：`spacecp&ac=credit&showcredit=1`（星币/经验/积分）与 `space-uid-N.html`
  （帖子/关注/粉丝）都是重模板页面，正则很容易被积分记录表格里的「星币 -5」之类干扰。
  移动端接口一次给全：`space.credits`（总积分）、`space.extcredits2/3/4`（经验/贡献/星币）、
  `space.posts`、`space.threads`、`space.following`、`space.follower`。
  积分编号→名称的映射在 `Variables.extcredits[*].title` 里，按名称取才不会因站点改编号而错位。
- **附件图片不在正文里**：登录态下图片附件在兄弟节点 `div.pattl`，`img.src` 是占位图，真实地址在 `zoomfile` / `file`。
- **文件附件有两处，其中一处会"炸图"**：除了 `div.pattl`，`#postmessage` 里还有 `<ignore_js_op>`，内含 16px 的
  `static/image/filetype/*.gif` 小图标 + 下载链接 + `display:none` 的 `.tip` 提示。整块当正文渲染会把小图标拉成整屏问号，
  并漏出「点击文件名下载附件」文案。正确做法是抽成附件卡片后从正文移除，并按 `<em>(13.83 KB, 下载次数: N)</em>`
  或 `<p>5.92 KB, 下载次数: N</p>` 两种写法解析大小。
- **悬浮底栏会盖住列表末条**：底栏用 `extendBody: true` 浮在内容之上，页面自身的内边距不够。底栏高度
  （`4 + 64 + 12`）加上系统安全区必须由列表底部 padding 让出来 —— 统一走 `BottomBarInset` +
  `YuanSizes.bottomBarInset()`，二级页面（推入的路由）不在其子树内自动为 0。

## 构建

### 本地构建

```bash
cd ycoo_client
flutter pub get
flutter build apk --release     # Android
flutter build ios --release     # 需 macOS + Xcode
flutter build windows --release # 其余平台同理：macos / linux / web
```

> **路径含中文会构建失败**：Gradle 已内置 `android.overridePathCheck=true`，但 Dart AOT 快照在中文路径下仍会读取乱码，Android 发布包请把工程复制到纯英文路径（如 `C:\build\ycoo_client`）再构建。
>
> 国内环境建议镜像：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

### 通过 CI 构建（推荐）

推送到 `main` 或手动触发 `.github/workflows/android.yml`，Actions 会执行：

```
flutter analyze → 离线单元测试 → flutter build apk --release → 上传 artifact
```

### 发版

```bash
# 1. 改 ycoo_client/pubspec.yaml 的 version
# 2. 打 tag 并推送
git tag v1.0.11
git push origin v1.0.11
```

推 `v*` tag 会触发构建，并自动把 APK 挂到对应的 GitHub Release（APK 按 pubspec 版本号命名）。

## 测试与回归

```bash
cd ycoo_client

# 单元测试（离线）
flutter test test/paid_thread_test.dart test/link_resolver_test.dart
flutter test                        # 全量（含联网图片测试与布局测试）

# 用真实抓包页面做解析回归（样本放 ../recon，不入库）
dart run tool/parse_check.dart ../recon
dart run tool/pay_check.dart ../recon     # 付费贴：购买前 / 购买后状态断言
dart run tool/content_check.dart ../recon # 正文零丢失校验
dart run tool/live_test.dart              # 真实站点联调（只读）
```

`test/paid_thread_test.dart` 用 MockClient 回放了完整购买链路（弹窗 → 提交 → 重新拉帖校验），不需要真实扣费。

## 已知限制

- **Web 端**：站点未返回 `Access-Control-Allow-Origin`，且浏览器禁止脚本设置 `Cookie` 头，登录态无法保持。Android / iOS / 桌面端不受影响。
- **验证码**：若站点对低等级账号开启发帖验证码，自动回复会失败并提示到网页端回复一次。
- **搜索**：部分关键词/版块要求登录或受频率限制。

## 文档

| 文档 | 内容 |
| --- | --- |
| [`ycoo_client/README.md`](ycoo_client/README.md) | 站点结构分析、接口清单、设计细节、离线自测脚本 |
| [`ycoo_client/DESIGN.md`](ycoo_client/DESIGN.md) | 视觉与交互硬约束 |
| [`ycoo_client/AGENTS.md`](ycoo_client/AGENTS.md) | 分层约定与模块地图（给协作/自动化用） |
| [`ycoo_client/TODO.md`](ycoo_client/TODO.md) | 版本演进与完成边界 |

## 免责声明

本项目为**第三方非官方客户端**，与源论坛官方无关。

- 账号密码仅用于直连 `ycoo.net` 登录，保存在本机，不上传任何第三方服务器。
- 自动签到与自动回复只作用于**使用者本人的账号**，默认遵守每日限额、按 tid 去重、随机延时，不做批量刷帖。请遵守论坛版规，合理设置限额。
- 客户端仅做内容展示与常规互动，不提供任何破解付费内容的能力；付费主题的扣费由站点完成。
- 仓库暂未附带开源许可证，如需转载或二次分发请先联系作者。
