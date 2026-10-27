# 源坛 · 源论坛多端客户端

基于 Flutter 编写的 **ycoo.net（源论坛）** 第三方客户端，一套代码同时适配 **Android / iOS / Windows / macOS / Linux / Web**。

针对论坛场景重做了登录、帖子阅读与版块浏览，并实现了两个特色能力：**自动签到** 与 **隐藏贴自动回复**。

[![Android APK](https://github.com/Mulidesi/ycoo/actions/workflows/android.yml/badge.svg)](https://github.com/Mulidesi/ycoo/actions/workflows/android.yml)
[![Release](https://img.shields.io/github/v/release/Mulidesi/ycoo?label=release&color=blue)](https://github.com/Mulidesi/ycoo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.5-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![minSdk](https://img.shields.io/badge/Android-minSdk%2021-brightgreen)](https://developer.android.com)

---

## 一、源论坛结构分析

### 1. 站点技术栈

| 项目        | 结论                                                                                      |
| --------- | --------------------------------------------------------------------------------------- |
| 论坛程序      | **Discuz! X3.5**（页面 meta 中 `generator` 明确标注）                                            |
| 前端模板      | 第三方模板 **comiis**（`discuz_theme_n7`），列表用 `li.kmlist` 结构                                  |
| Web 服务器   | nginx + HTTPS（HSTS 已开启）                                                                 |
| 编码        | UTF-8                                                                                   |
| Cookie 前缀 | `YPSa_2132_`（含 `saltkey` / `sid` / `auth`，会话完全依赖 Cookie）                                |
| 插件        | `k_misign`（每日签到）、`boan_buycode`（邀请码）、`jnfarm`、`viewui_lottery`、`comiis_app_video`       |
| 附件        | `/data/attachment/`，头像 `/data/avatar/`                                                  |
| 伪静态       | `forum-{fid}-{page}.html`、`thread-{tid}-{page}-{ordertype}.html`、`space-uid-{uid}.html` |

站点**没有公开 JSON API**，所有数据通过 HTML 解析获得；移动端 `?mobile=2` 会 302 回桌面模板，因此统一按桌面 HTML 解析。

### 2. 页面入口

| 入口 | 地址                                                     | 说明                              |
| -- | ------------------------------------------------------ | ------------------------------- |
| 门户 | `portal.php`                                           | 首页聚合（公告、媒体、置顶）                  |
| 论坛 | `forum.php`                                            | 版块分组总览                          |
| 导读 | `forum.php?mod=guide&view=newthread\|hot\|new\|digest` | 最新发表 / 热门 / 回复 / 精华             |
| 版块 | `forum-{fid}-{page}.html`                              | 帖子列表                            |
| 帖子 | `thread-{tid}-{page}-1.html`                           | 楼层详情                            |
| 个人 | `home.php?mod=space&do=profile`                        | 资料、积分、用户组                       |
| 签到 | `k_misign-sign.html`                                   | 即 `plugin.php?id=k_misign:sign` |

### 3. 版块结构（6 个分组 / 27 个版块）

| 分组 (gid)   | 版块 (fid)                                                                           |
| ---------- | ---------------------------------------------------------------------------------- |
| 书源交流 (1)   | 书源发布 2 · 悬赏问答 106（私密）· 订阅源区 40 · 主题专区 49 · 语音净化 48 · 开源阅读 91 · 轻悦时光 151 · 喵喵专区 163 |
| 网络资源 (111) | 精品软件 39 · 音视频区 113 · 游戏专区 110 · 漫画专区 114                                           |
| 小说专区 (142) | 精品小说 143 · 其他小说 144 · 漫画世界 145 · 有声听书 146                                          |
| 综合交流 (36)  | 黄金书屋 46 · 技术专区 38 · 数码专区 107 · 知识科普 53 · 情报速递 98                                   |
| 福利娱乐 (95)  | 休闲专区 96 · 活动专区 105                                                                 |
| 日常站务 (41)  | 站务公告 42 · 投诉建议 43 · 认证专区 51 · 繁星专区 102                                             |

> 版块列表在运行时动态解析 `forum.php`，站点增删版块无需改代码。

### 4. 关键接口（客户端已封装）

| 能力    | 方法与地址                                                                                            | 关键参数                                                                                      |
| ----- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| 取登录令牌 | `GET member.php?mod=logging&action=login`                                                        | 解析 `formhash`、`loginhash`                                                                 |
| 登录    | `POST member.php?mod=logging&action=login&loginsubmit=yes&handlekey=login&loginhash=xx&inajax=1` | `formhash` `loginfield=username` `username` `password` `questionid` `answer` `cookietime` |
| 当前用户  | `GET home.php?mod=space&do=profile`                                                              | 重定向后的 `space-uid-{uid}.html` 即 uid                                                        |
| 版块列表  | `GET forum.php`                                                                                  | 解析 `h2[gid]` + `div#category_*` + `dl`                                                    |
| 帖子列表  | `GET forum-{fid}-{page}.html`                                                                    | 解析 `li.kmlist` / `li[id^=normalthread_]`                                                  |
| 帖子详情  | `GET thread-{tid}-{page}-1.html`                                                                 | 解析 `div[id^=post_]`、`#postmessage_*`、`div.locked`                                         |
| 发帖页   | `GET forum.php?mod=post&action=newthread&fid={fid}`                                               | 解析 `form#postform` 的 action、`formhash`、`posttime`、`typeid` 分类                            |
| 发帖    | `POST` 发帖页 action + `&inajax=1`                                                                 | `formhash` `posttime` `subject` `message` `typeid` `usesig=1` `wysiwyg=0`                    |
| 回复    | 按页面 `form#fastpostform` 的 action 原样提交 + `&inajax=1`                                              | `formhash` `message` `subject` `usesig` `posttime`                                        |
| 签到状态  | `GET k_misign-sign.html`                                                                         | 已签到标记：`.btnvisted` + 「您的签到排名」                                                             |
| 执行签到  | `POST plugin.php?id=k_misign:sign&operation=qiandao&format=button&formhash=xx`                   | 返回 `签到成功` / `今日已签`                                                                        |

### 5. 内容与权限模型

- **隐藏内容**：Discuz 把提示放在 `div.locked`（在 `#postmessage_` 的**兄弟节点**），文本区分三种：
  - `本帖隐藏的内容需要回复才可以浏览` → 回复可见
  - `本主题需向作者支付 N 星币才能浏览` → 购买可见
  - `您需要登录才可以下载或查看` → 登录可见
- **购买后信息栏（易踩坑）**：购买成功后站点**不会删除** `div.locked`，只是内容退化成
  `<a href="…action=viewpayments…">记录</a> 付费主题, 价格: 5 星币`，同时正文回到 `#postmessage_`。
  判定「是否仍需购买」必须看**购买入口 `a[href*=action=pay]` 与阻塞措辞**，不能只看是否含「星币」，
  否则买完仍会被判成锁定（v1.0.10 修复）。
- **购买流程**：`GET …mod=misc&action=pay&tid&pid&infloat=yes&handlekey=pay&inajax=1` 取弹窗表单 →
  按表单 action（`…action=pay&paysubmit=yes&infloat=yes`，需补 `tid`）POST `formhash/paysubmit/handlekey/tid` →
  响应是 `succeedhandle_('…', '主题购买成功', {})`（**handlekey 为空，下划线后无字符**）。
- **附件下载**：游客可见 `div.attach_nopermission` 提示，附件真实地址在 `a[href*=attachment]`。
- **附件有两种位置（易踩坑）**：
  1. `div.pattl > dl.tattl dd` —— 图片附件（`img[zoomfile]`）并入正文，纯文件附件做成卡片；
  2. 直接嵌在 `#postmessage_` 里的 `<ignore_js_op>` —— 内含 **16px 文件类型小图标**
     （`static/image/filetype/unknown.gif`）+ `<a href*=attachment>` + 大小文本 + `display:none` 的 `.tip` 提示。
     整块当正文渲染会把小图标拉成整屏问号、还会漏出「点击文件名下载附件」文案（v1.0.11 修复：
     抽成附件卡片后从正文移除；大小兼容 `<em>(13.83 KB, 下载次数: 531)</em>` 与 `<p>5.92 KB, 下载次数: 6</p>` 两种写法）。
- **附件抽出后正文可能只剩空白**：判断「正文为空」不能只看 `contentHtml.trim().isEmpty`，
  要按解析后的纯文本（或含 `<img>`）判断，否则只有附件的帖子会误报「正文需登录或购买后可见」。
- **私密版块**：版块列表 `dd` 中出现「私密版块」，未授权用户进入会提示无权限。
- **移动端 JSON 接口存在且免登录**：`api/mobile/index.php?version=4&module=profile&uid=N` 直接返回
  `Variables.space`，含 `credits`（总积分）、`extcredits2/3/4`（经验/贡献/星币）、`posts`、`threads`、
  `following`、`follower`、`oltime`、`regdate` 等。「我的」页积分与统计用它，不要正则爬
  `spacecp&ac=credit&showcredit=1` / `space-uid-N.html`——那两个页面里积分记录表格的「星币 -5」
  会把正则带偏。积分编号→名称映射取 `Variables.extcredits[*].title`，按名称取值才不会因站点改编号错位。
- **移动端接口会重新下发 `saltkey`**：请求时不要吸收 Set-Cookie，否则可能干扰已登录会话。
- **正文结构**：`<br>` 分段 + `<img class="zoom">` 图片 + `<a>` 外链 + `<blockquote>` 引用 + `<pre>` 代码。

### 6. 界面约束（易踩坑）

- **悬浮底栏遮挡列表**：底栏用 `Scaffold(extendBody: true)` 浮在内容之上，页面内边距不会自动让位。
  底部留白必须 = `MediaQuery.viewPadding.bottom`（安全区）+ `YuanSizes.barTotalHeight`（4 + 64 + 12）+ 16（呼吸距离），
  统一由 `HomeShell` 注入 `BottomBarInset`，页面用 `BottomBarInset.of(context)` 加进 `ListView.padding.bottom`。
  推入的二级路由不在其子树内，`of()` 返回 0，不会多留空白。
  注意 `MediaQuery.removePadding(removeBottom: true)` 会把 `viewPadding` 一起清掉，所以安全区要在移除**之前**算。
- **自动回复预设必须自带默认值**：`replyPresets` 为空时自动回复会抛 `没有可用的自动回复预设`，用户看到的是
  「开关开着但不回帖」。现在 `AppSettings` 在构造 / `fromJson` / `effectivePresets` 三处都会回落到
  `defaultReplyPresets`（5 条），老版本只存了一条内置默认语的也一并升级。

---

## 二、客户端设计

### 1. 分层结构

```
ycoo_client/                # 工程根目录（App 代码都在这里）
├── lib/
│   ├── main.dart                启动：加载状态后注入 Provider
│   ├── app.dart                 MaterialApp + 启动闸门（启动页/登录/主框架）
│   ├── core/
│   │   ├── discuz_client.dart   带 Cookie 持久化的 HTTP 客户端
│   │   └── image_loader.dart    图片加载器（Cookie / 防盗链降级 / 失败原因）
│   ├── data/
│   │   ├── parsers.dart         纯 Dart HTML 解析（可离线回归）
│   │   ├── content.dart         正文 HTML → 内容块（无损，可离线回归）
│   │   ├── previews.dart        移动端接口 → 列表首图 / 摘要（纯解析）
│   │   └── forum_api.dart       全部站点接口
│   ├── models/models.dart       Board / ThreadItem / Post / UserProfile / SignStatus ...
│   ├── state/
│   │   ├── app_state.dart       登录态、设置、签到、自动回复配额
│   │   └── preview_store.dart   列表预览缓存 + 节流请求
│   └── ui/
│       ├── theme.dart           Material 3 主题（亮/暗）
│       ├── widgets/             正文渲染器、帖子行、通用组件
│       └── pages/               登录 / 首页 / 版块 / 帖子列表 / 帖子详情 / 签到 / 我的 / 搜索
└── tool/                        离线回归脚本（配合 ../recon 抓取样本）
```

**为什么解析层独立**：`parsers.dart` 不 import Flutter，可以直接 `dart run tool/parse_test.dart` 用真实抓取页面做回归，站点改版时能第一时间定位。

### 2. 关键技术点

- **Cookie 管理**：`package:http` 不自带 Cookie，客户端自行维护 `name→value` 表，处理了多个 `Set-Cookie` 被逗号拼接、而 `expires` 也含逗号的问题（按 `,(?=name=)` 切分），并持久化到 `SharedPreferences` 实现免登录。
- **正文渲染**：把帖子 HTML 拆成 段落 / 图片 / 引用 / 代码块 四类块，段落内保留加粗、斜体、下划线、颜色、字号与超链接；链接可点击跳转，图片点击进入可缩放预览，并带 `Referer` 头绕过防盗链。
- **多端适配**：宽度 ≥ 900 自动切换 `NavigationRail` 侧栏布局（PC/平板），窄屏使用底部导航（手机）；内容区最大宽度受控，避免 PC 上过宽。
- **液态玻璃**：底栏与详情页回复栏由 `liquid_glass_widgets` 渲染（磨砂 6 / 厚度 24），Shader 不可用时自动退回磨砂；底栏选中态只用高亮色，不画背景块。
- **自动签到**：启动、回到前台、手动触发三个时机；按自然日去重，先查状态再签到，失败不影响启动。
- **隐藏贴自动回复**：仅在用户**真正打开**隐藏贴时触发，随机延时 2.2–6 秒，按 tid 去重、按自然日限额（默认 20 条/天）、支持版块白名单，避免批量刷帖。

### 3. 功能清单

| 模块   | 能力                                        |
| ---- | ----------------------------------------- |
| 登录   | 账号/UID/邮箱、安全提问、记住密码、登录失败提示剩余次数、Cookie 免登录 |
| 首页   | 最新发表 / 热门 / 回复 / 精华 四个信息流，下拉刷新 + 触底加载；再点底栏「首页」刷新当前信息流 |
| 版块   | 分组折叠式浏览、今日新增、主题/帖数、私密标识、搜索入口              |
| 帖子列表 | 置顶/分类标签、附件标识、作者与回复/查看数、分页加载               |
| 帖子阅读 | 富文本渲染、图片预览、楼层列表、楼层跳页、复制正文/链接、浏览器打开；底部玻璃回复栏支持点赞/收藏/分享 |
| 发帖   | 选版块与主题分类、标题/正文编辑、Discuz BBCode、审核状态提示、发布后直达新主题          |
| 过滤   | 按标题关键词隐藏帖子，默认过滤「打卡」，可在「我的」中增删关键词或关闭 |
| 隐藏内容 | 回复可见/购买可见/登录可见 分类提示；自动回复解锁                |
| 签到   | 状态、连续天数、今日人数、排名、奖励、自动签到开关                 |
| 我的   | 头像/用户组/积分/主题/回帖/好友、自动回复内容与限额、清除记录、退出登录    |
| 搜索   | 关键词搜索帖子（需站点允许）                            |

---

## 三、构建与运行

以下命令均在 `ycoo_client/` 工程目录内执行，Android / iOS / 桌面端统一使用 **Flutter 3.41.9（Dart 3.11.5）** 及以上（`liquid_glass_widgets` 依赖 `Color.withValues`）。

```bash
# Android 构建前先修复 Flutter 自带的 Gradle 插件（CI 已自动执行）
bash tool/patch_flutter_gradle_plugin.sh

flutter pub get

# Android（按 ABI 拆分为 3 个独立 APK）
flutter build apk --release --split-per-abi
# 产物 build/app/outputs/flutter-apk/app-release-arm64-v8a.apk
#        build/app/outputs/flutter-apk/app-release-armeabi-v7a.apk
#        build/app/outputs/flutter-apk/app-release-x86_64.apk

# iOS（需 macOS + Xcode）
flutter build ios --release

# Windows / macOS / Linux
flutter build windows --release
flutter build macos --release
flutter build linux --release

# Web
flutter build web --release
```

> 项目路径含中文时，Gradle 需要 `android/gradle.properties` 中的 `android.overridePathCheck=true`（已内置）。
>
> Android 工具链为 Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 / JDK 17（Flutter 3.41.9 模板默认组合）。
>
> Flutter 3.41.9 自带的 Gradle 插件有两处源码缺陷：版本检测在编译期引用已移除的 `com.android.Version`，旧 Groovy 插件与 Kotlin DSL 插件还会生成同名 `FlutterPlugin.class` 导致 `:gradle:jar` 失败。`tool/patch_flutter_gradle_plugin.sh` 会就地打补丁，升级 Flutter 后可移除。
>
> 但 Dart AOT 快照器在中文路径下仍会失败（`app.dill` 读取乱码），**Android 发布包请把工程复制到纯英文路径再构建**，例如 `C:\Users\Administrator\build\ycoo_client`。
>
> 国内环境建议使用镜像：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

### 已构建产物

正式包统一由 GitHub Actions 构建并发布到 [Releases](https://github.com/Mulidesi/ycoo/releases)，推 `v*` tag 自动出包。

| 来源 | 文件 | 说明 |
| --- | --- | --- |
| GitHub Release | `ycoo-client-1.1.6-arm64-v8a.apk` | 当前最新（[v1.1.6](https://github.com/Mulidesi/ycoo/releases/tag/v1.1.6)，搜索筛选 + 首页骨架屏；versionCode 27，minSdk 24） |
| GitHub Release | `ycoo-client-1.1.6-armeabi-v7a.apk` | 同上，32 位 ARM |
| GitHub Release | `ycoo-client-1.1.6-x86_64.apk` | 同上，x86_64 模拟器/平板 |
| GitHub Release | `ycoo-client-1.1.5-arm64-v8a.apk` | v1.1.5（修复帖子页关注按钮丢失；versionCode 26） |
| GitHub Release | `ycoo-client-1.1.3-arm64-v8a.apk` | v1.1.3（AppState 服务层拆分；versionCode 24） |
| GitHub Release | `ycoo-client-1.1.2-arm64-v8a.apk` | v1.1.2（发版构建修复；versionCode 23） |
| GitHub Release | `ycoo-client-1.1.1-arm64-v8a.apk` | v1.1.1（液态玻璃底栏/回复栏 + Android 构建链修复；versionCode 22） |
| GitHub Release | `ycoo-client-1.0.19.apk` | v1.0.19（修复更新说明中文乱码 + 隐藏贴标识与自动回复；versionCode 20，minSdk 21） |
| GitHub Release | `ycoo-client-1.0.18.apk` | v1.0.18（发帖、标题关键词过滤、点击底栏首页刷新；versionCode 19） |
| GitHub Release | `ycoo-client-1.0.17.apk` | v1.0.17（应用内 GitHub Release 更新 + 国内加速下载 + SHA-256 校验；versionCode 18） |
| GitHub Release | `ycoo-client-1.0.16.apk` | v1.0.16（回复输入框不再被键盘遮挡 + 默认头像显示；versionCode 17） |
| GitHub Release | `ycoo-client-1.0.15.apk` | v1.0.15（固定 release 签名，可直接覆盖安装；versionCode 16） |
| GitHub Release | `ycoo-client-1.0.14.apk` | v1.0.14（点击头像查看用户个人中心与主题列表；versionCode 15） |
| GitHub Release | `ycoo-client-1.0.13.apk` | v1.0.13（自动回复预设默认初始化 + 底栏不遮挡列表；versionCode 14） |
| GitHub Release | `ycoo-client-1.0.12.apk` | v1.0.12（「我的」页积分/统计改为接口取值；versionCode 13） |
| GitHub Release | `ycoo-client-1.0.11.apk` | v1.0.11（正文排版对齐移动端；versionCode 12） |
| GitHub Release | `ycoo-client-1.0.10.apk` | v1.0.10（修复付费主题购买；versionCode 11） |
| 本地构建 | `build/app/outputs/flutter-apk/app-release-arm64-v8a.apk` | 按 ABI 拆分，共 3 个 |
| 历史本地包 | `dist/ycoo-client-1.0.9.apk` | v1.0.9（P4：附件卡片、引用折叠、收藏板块、动态取色、后台签到） |

Windows / macOS / Linux / iOS 的工程目录已生成，但需要对应平台的原生工具链（Visual Studio C++ / Xcode）才能产出安装包。

- 支持 ABI：`arm64-v8a` / `armeabi-v7a` / `x86_64`
- 使用固定 release 签名，可直接覆盖安装后续版本，**仅供个人测试**，请勿二次分发

### 应用内更新

Android 端「我的 → 通用 → 检查更新」会读取最新 Release 的 `latest.json`，与当前 `versionName` 比较后下载安装：

- `latest.json` 内含 `apks` 数组，每项带 `abi` 字段；App 按当前设备 ABI 自动选择匹配的 APK，回退顺序为 arm64-v8a → 第一项
- 元数据优先 `https://gproxy.mulides.cc.cd/` 加速线路，失败回退 `github.com` / `api.github.com` 直连
- APK 下载同样先加速后直连，按 `size` / `sha256` 校验，只接受 GitHub 域名下的 HTTPS 地址
- 安装通过 `FileProvider` + `ACTION_VIEW` 调起系统安装器；Android 8+ 需允许「安装未知应用」
- 相关代码：`ycoo_client/lib/data/update_manifest.dart`、`ycoo_client/lib/core/update_service.dart`、`ycoo_client/lib/ui/pages/update_page.dart`、`ycoo_client/android/.../MainActivity.kt`
- CI 在 tag 构建时生成并上传 `latest.json`，与 APK 同属一个 Release

### 离线自测

```bash
# 解析器回归（需要先用 curl 抓取页面到 ../recon）
dart run tool/parse_test.dart ../recon     # 版块 / 列表 / 帖子元信息
dart run tool/parse_check.dart ../recon    # 楼层、楼主、锁定状态
dart run tool/content_check.dart ../recon  # 正文零丢失校验（文本 + 图片）
dart run tool/attach_check.dart ../recon   # 附件卡片 + 正文无残留（含全样本扫描）
dart run tool/stats_check.dart ../recon    # 我的页积分/统计解析断言
dart run tool/stats_check.dart ../recon --live  # 额外打一次真实移动端接口

# 真实站点联调
dart run tool/live_test.dart            # 只读接口
dart run tool/live_test.dart --login    # 含登录
dart run tool/reply_check.dart          # 提示语提取 + 错误透传
dart run tool/reply_check.dart --live <tid>   # 真实回帖
dart run tool/image_probe.dart          # 图片字节 / 编码探测
dart run tool/preview_check.dart ../recon        # 列表预览解析 + 裸链接识别
dart run tool/preview_check.dart ../recon --live # 在线校验移动端接口

# Flutter 测试（图片加载单测 + 真实网络解码）
flutter test test/image_loader_test.dart   # 离线：Cookie / Referer 降级 / SVG / 错误卡片
flutter test test/live_image_test.dart     # 联网：真实图片下载并解码
flutter test test/ui_smoke_test.dart       # 卡片 / 正文布局、窄屏不溢出
flutter test test/detail_layout_test.dart  # 详情页正文与评论分栏
flutter test test/automation_presets_test.dart  # 自动回复预设初始化 / 升级迁移 / 队列同步
flutter test test/bottom_bar_inset_test.dart    # 悬浮底栏占位高度与列表底部留白
flutter test test/thread_actions_test.dart      # 点赞/收藏入口解析与 inajax 响应
flutter test test/glass_reply_bar_test.dart     # 收起/展开、发布、点赞收藏状态
flutter test test/preview_home.dart --update-goldens   # 底栏 + 列表版式预览 PNG
flutter test --update-goldens test/golden_preview_test.dart  # 生成版式预览 PNG
```

`content_check` 会逐个页面比对「渲染后纯文本」与「DOM 文本」是否完全一致，并统计图片数量与嵌套图片数（旧版渲染器会丢掉嵌在 `div/p/td` 里的图片）。当前 9 个样本页面：文本 9/9 一致，图片 100% 保留。

---

## 四、实测结果

针对账号 `木里得斯` 的验证（2026-10-20）：

| 项目   | 结果                                |
| ---- | --------------------------------- |
| 登录   | ✅ 成功，`uid=31981`，用户组「大会员」，积分 9148 |
| 版块解析 | ✅ 6 个分组 / 27 个版块                  |
| 帖子列表 | ✅ 书源发布 200 页，首页 22 条（含置顶）         |
| 帖子详情 | ✅ 标题/楼层/作者/时间/正文解析正常（20 楼、2 页）    |
| 签到状态 | ✅ 已签到，连续 122 天，排名第 50，今日 673 人    |
| 签到接口 | ✅ 调用返回「今日已签」，与网页状态一致              |
| 点赞 | ✅ `recommend&do=add` 成功（`errorhandle_recommend` + `recommentc`），重复提示「您已评价过本主题」 |
| 收藏 | ✅ `spacecp&ac=favorite` 返回 `favid`，`op=delete` 可取消               |
| 液态玻璃 | ✅ Flutter 3.41.9 下 `flutter analyze` 0 issue，全量测试通过            |

---

## 五、修复记录（v1.0.1）

### 1. 帖子正文显示不完整

**根因**：售价 / 隐藏主题的楼主楼，Discuz 不生成 `#postmessage_<pid>`，正文被 `div.locked` 顶掉。旧解析器找不到正文容器就直接 `continue`，整层被跳过 —— 于是详情页只剩标题和回复，看起来就是「正文不完整」。另外旧渲染器把 `div/p/td` 里的图片、表格、附件区一起拍平，图片会丢。

**修复**：

- 正文容器按 `#postmessage_` → `.t_fsz` → `td.t_f` → `.pcb` 逐级兜底，楼主楼不再被跳过；
- 新增 `lib/data/content.dart`：递归遍历整棵 DOM，任意深度的文本 / 图片 / 链接 / 引用 / 代码都保留，只剔除 `script`、`style`、版权声明、楼层操作区等模板噪声；
- 楼主判定改用 `comiis_vone` / 楼层文字，隐藏提示由楼主楼决定（回复被屏蔽不再把整个主题判成隐藏贴）；
- 正文图片同时兼容 `zoomfile` / `file` / `data-original`，过滤占位图与表情图。

**验证**：9 个真实页面（普通贴 / 付费贴 / 隐藏贴 / 20 楼长贴）渲染后纯文本与 DOM 文本 **9/9 完全一致**，图片 **100% 保留**。

### 2. 自动回帖与手动回帖都提示「回复失败」

**根因**：回复其实**已经发送成功**，是客户端把成功响应当成了失败。Discuz 的 `inajax` 成功响应是

`<root><![CDATA[<script>succeedhandle_fastpost('url', '回复发布成功…', {...})</script>]]></root>`，

而 `parseAjaxMessage` 先删掉了整段 `<script>` 再取文本，得到空串 → 落到兜底分支「回复失败」。

同时旧代码提交的 URL 缺 `handlekey` / `infloat` / `posttime`，与页面表单不一致。

**修复**：

- `parseAjaxMessage` 先提取 `succeedhandle_*('url','提示语',{...})` 的第二个参数，再清洗标签；
- 回复直接复用页面 `form#fastpostform` 的 action 与隐藏字段（`posttime` / `subject` / `usesig`）；
- 成功判定增加 `succeedhandle_fastpost` / `succeedhandle_reply`，并区分「已提交待审核」；
- 未登录判定改用「有登录表单且无退出入口」，避免错误页被误判成登录失效；
- 自动回复失败时不再一直转圈，改为显示站点原始提示 + 「重试」。

**验证**：真实账号登录 → `ForumApi.reply` 返回 `success=true / 回复成功`，回帖后楼层数由 1 变 2，本人楼层为「沙发」；离线样本的三类响应（登录成功 / 回复成功 / 主题不存在）提示语均正确提取。

---

## 六、图片加载（v1.0.2）

原先所有图片都直接用 `Image.network(url, headers: {'Referer': ...})`，有四个硬伤：

| 问题           | 后果                                             |
| ------------ | ---------------------------------------------- |
| 拿不到站点 Cookie | 站内附件图（`data/attachment/...`）在需要登录时 403 / 返回占位图 |
| 只带一种 Referer | 图床按 Referer 反防盗链时直接拒绝                          |
| 无法解码 SVG     | 大量用户的默认头像 `noavatar.svg` 必然报错，头像全空             |
| 错误被吞掉        | 只显示「图片加载失败」，不知道是 403、超时还是解码失败                  |

现在统一走 `core/image_loader.dart` + `ui/widgets/net_image.dart`：

- 自己发请求：`User-Agent` + `Referer: https://ycoo.net/` + **当前登录态 Cookie**；
- 失败自动降级：带 Referer 失败后去掉 Referer 再试一次（两种防盗链方向都覆盖）；
- SVG / 空内容直接判定并跳过，不再抛解码异常；头像回落到字母占位；
- 错误卡片显示真实原因（`HTTP 403` / `网络异常：...`）+ 「重试」按钮，点一下重新拉取；
- 登录 / 退出后自动清空图片缓存，避免游客态拿到的占位图一直留着。

**自检入口**：「我的 → 图片加载诊断」会依次探测 站内头像 / 站内附件图 / 默认头像(SVG) / 外链图床，显示 HTTP 状态、字节数、解码尺寸与耗时，并标明本次是否带登录态。

**实测**（真实网络 + 真机同栈解码，`flutter test test/live_image_test.dart`）：

| 资源                                               | 结果                                 |
| ------------------------------------------------ | ---------------------------------- |
| `data/avatar/..._avatar_middle.jpg`              | ✅ 6997B → 120x120                  |
| `data/attachment/common/template/boardimg_*.png` | ✅ 7257B → 192x69                   |
| `data/avatar/noavatar.svg`                       | ⚠️ 判定为 SVG，走占位（Flutter 不支持 SVG 解码） |
| `s1.imagehub.cc/...jpg`                          | ✅ 138845B → 450x1000               |

---

## 七、列表缩略图与正文版式（v1.0.3）

### 1. 列表卡片：首图 + 摘要

版块列表 / 导读页的 HTML **只有头像，没有首图和摘要**，所以早期列表只能显示标题。

排查时发现站点开放了 Discuz 移动端接口：

```
GET api/mobile/index.php?version=4&module=forumdisplay&fid={fid}&page={page}
```


```

返回 JSON 里 `forum_threadlist[]` 带 `attachmentImagePreviewList`（首图附件）、`message`（正文预览）、
`recommend_add`（点赞）、`attachmentImageNumber`（图片数），**一次请求覆盖整页帖子**，
比逐帖抓详情页（约 100KB/帖）轻一个数量级。

实现：

- `lib/data/previews.dart`：纯解析（JSON → `ThreadPreview{image, excerpt, imageCount, likes}`），
  摘要会去标签、去 BBCode、去「本帖最后由…编辑」，并在 URL 紧贴中文处补空格；
- `lib/state/preview_store.dart`：按 `fid+page` 去重请求、并发 2、间隔 250ms、命中 429 冷却 8 秒，
  拿到后增量通知 UI，卡片先出文字再补首图，不阻塞首屏；
- `ui/widgets/thread_tile.dart` 改成卡片式：作者行（头像/昵称/时间/版块胶囊）→ 标题 → 摘要 2 行 →
  16:9 首图（多图右上角「N 图」角标）→ 浏览/回复/点赞数据行；没有预览时卡片自动收缩。

### 2. 正文里的图片与链接

- **链接**：统一主色 + 下划线，点击走外部浏览器；另外 `content.dart` 会把**纯文本里的裸链接**
  （`https://...` / `www....`，Discuz 很多网盘地址没包 `<a>`）识别成可点击 run，
  并去掉尾部中文标点；长 URL 会正常折行（见 `test/ui_smoke_test.dart`）。
- **图片**：正文图改为「整行宽度 + 最高 420px + `BoxFit.contain`」，长截图不再把一屏撑满，
  点开仍是原图可缩放；加载中显示骨架，失败给出原因与「点此重试」。
- 顺带修掉一个隐患：链接手势识别器原先在每次 build 都新建并累积，长贴滚动会持续泄漏，现在按 URL 复用。

### 3. 正文与评论视觉分离

详情页原先所有楼层都是同样的白卡，长贴滑到底分不清哪里是正文、哪里是评论。现在：

| 区域 | 样式 |
| --- | --- |
| 楼主正文 | 独立白卡：大标题（19.5/w700）→ 作者行 + 版块胶囊 → 正文（16pt）→ 操作行（复制正文 / 分享 / 浏览器 / 楼层统计） |
| 评论 | 无卡片平铺：`全部评论 (N)` 标题 + 正序/倒序切换 + 浅分隔线，楼层名按 沙发 / 板凳 / 报纸 / N 楼 |
| 结尾 | 单页显示「已经到底了」，多页显示翻页器 |

评论内容字号 14.5，作者行 13，与正文形成层级差；评论右侧的回复按钮会把 `@作者` 预填进输入框。

---

## 八、已知限制

1. **Web 端受浏览器 CORS 限制**：ycoo.net 未返回 `Access-Control-Allow-Origin`，浏览器直连会被拦截；同时浏览器禁止脚本设置 `Cookie` 头，登录态无法在 Web 端保持。**Android / iOS / 桌面端不受影响**。
2. **验证码**：若站点对低等级账号开启发帖验证码，自动回复会失败并提示「请到网页端回复一次」。
3. **购买贴**：付费主题支持应用内购买（星币扣费走 `misc&action=pay`），余额不足时透传站点原文；若站点风控拦截会提示到网页端购买。
4. **搜索**：部分关键词/版块要求登录或受频率限制。

## 文档索引

| 文件 | 用途 |
|------|------|
| `AGENTS.md` | 协作约定：阅读顺序、技术边界、硬约束、常用命令 |
| `DESIGN.md` | 视觉与交互硬约束（改 UI 前必读） |
| `TODO.md` | 任务清单与版本进度 |
| `README.md` | 本文件：站点分析、接口封装、构建与实测记录 |

## 九、合规说明

本项目为第三方客户端，与源论坛官方无关。账号密码仅用于直连 `ycoo.net` 登录，保存在本机，不上传任何第三方服务器。自动签到与自动回复作用于**使用者本人的账号**，请遵守论坛版规，合理设置每日限额，避免灌水。
