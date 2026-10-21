# AGENTS.md

源论坛 App（ycoo_client）。Flutter 客户端，对接 Discuz! X3.5 站点 `https://ycoo.net/`，覆盖 Android / iOS / Windows / macOS / Linux / Web。

进入本仓库后，按下列顺序阅读：

1. `TODO.md` — 当前优先级与完成边界
2. `DESIGN.md` — 视觉与交互硬约束
3. `README.md` — 站点结构分析、接口封装、构建与实测
4. `docs/architecture.md` — 分层与数据流

改 UI 前先对 `DESIGN.md`；改解析前先跑 `tool/parse_test.dart` 回归；改需求前先更新文档再写代码。

## 项目一句话

原生 Flutter 论坛客户端：首页信息流、版块浏览、帖子阅读/回复、签到与自动化（自动签到、隐藏贴自动回复），深浅色跟随 Material Design 3。

## 技术边界

| 项 | 约定 |
|----|------|
| 框架 | Flutter 3.24.5 / Dart 3.5.4 |
| 设计 | Material Design 3，`lib/design/tokens.dart` 单一令牌来源，悬浮液态玻璃底栏 |
| 状态 | Provider 2（`AppState` extends `ChangeNotifier`） |
| 网络 | `package:http` + 自维护 Cookie（`core/discuz_client.dart`） |
| 解析 | `html` 包，纯 Dart 解析器（不 import Flutter，可离线回归） |
| 本地 | `shared_preferences`（Cookie / 设置 / 自动化日志） |
| 正文 | 自研 HTML 渲染器（`data/content.dart` + `ui/widgets/html_content.dart`） |

## 模块地图

```
lib/
  main.dart / app.dart      启动、主题（themeMode 由 settings 驱动）、启动闸门
  core/
    discuz_client.dart      Cookie 持久化 HTTP 客户端
    image_loader.dart       图片加载（Cookie / 防盗链降级 / SVG 判定）
    network/site_config.dart  ForumSite / SiteCapability（站点能力位）
    error/app_exception.dart  统一错误类型与中文文案
    automation/             纯领域逻辑：engine / queue / checkin 调度
    services/download_service.dart  附件流式下载（Android 公共 Download）
    utils/link_resolver.dart  站内 tid/fid 链接解析
    storage/automation_models.dart  Preset / AutoReplyLog / CheckinLog
  data/
    parsers.dart            HTML → 模型（纯 Dart）
    content.dart            正文 HTML → 内容块（纯 Dart）
    previews.dart           移动端 JSON → 列表首图/摘要（纯解析）
    forum_api.dart          站点接口封装
  models/models.dart        Board / ThreadItem / Post / UserProfile / SignStatus
  state/
    app_state.dart          登录态、设置、签到、自动回复、外观
    preview_store.dart      列表预览缓存 + 节流请求
  design/
    tokens.dart             颜色/间距/圆角/字号/运动/尺寸 + 语义色 ThemeExtension
    glass/liquid_glass_bar.dart  悬浮液态玻璃底栏
  ui/
    theme.dart              Material 3 主题（亮/暗，注入语义色）
    widgets/                正文渲染器、帖子行、通用组件
    pages/                  登录 / 首页 / 版块 / 列表 / 详情 / 签到 / 我的 / 搜索
```

## 硬约束

- 帖子正文与回帖必须有可感知的视觉层级差（字号 16/14、表面色、回帖左轨线 3px）。
- 颜色、间距、圆角、字号一律走 `lib/design/tokens.dart`，业务代码禁止散落 Magic Number 与硬编码 `Color(0x...)`。
- 语义色通过 `YuanSemanticColors.of(context)` 获取，Widget 内禁止判断 `ThemeMode` 拼颜色。
- 解析层（`data/parsers.dart` / `content.dart` / `previews.dart`）保持纯 Dart，不 import Flutter。
- 自动化行为（签到/回复）默认遵守：每日限额、按 tid 去重、随机延时、预设随机取一，不做批量刷帖。
- 站点改版时优先跑 `dart run tool/live_test.dart` 验证选择器。

## 常用命令

```bash
flutter pub get
flutter analyze        # 必须 0 issue
flutter test           # 离线 + 联网图片测试
dart run tool/parse_test.dart ../recon   # 解析器离线回归
flutter build apk --release   # Android 打包（见 README 构建章节）
```

## 文档索引

| 文件 | 用途 |
|------|------|
| `DESIGN.md` | 视觉规则 |
| `TODO.md` | 任务与进度 |
| `README.md` | 站点分析、接口、构建、实测记录 |
| `docs/architecture.md` | 分层与数据流 |
