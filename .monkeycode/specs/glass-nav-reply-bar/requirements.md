# 需求文档：液态玻璃底栏与回帖栏改版

Feature Name: glass-nav-reply-bar
Updated: 2026-10-23

## 1. 引言

本次改版覆盖三块内容：

1. **底栏选中态重构**：取消选中项背后的小方块（胶囊）背景色，改用纯高亮色区分选中与未选中。
2. **帖子详情页底部回复栏液态玻璃化**：以悬浮液态玻璃样式重做回复栏，包含回复内容输入框、点赞按钮、收藏按钮、分享按钮；点击输入框展开多行输入与输入法，发布按钮位于输入框右下角。
3. **接入 liquid_glass_widgets**（https://pub.dev/packages/liquid_glass_widgets ）：用该组件库渲染底栏与回帖悬浮栏的玻璃效果，支持动态光照、折射、动画过渡与 Shader 渲染，并在不支持的渲染器上自动降级。

工具链前提：liquid_glass_widgets 全部已发布版本依赖 Flutter 3.27+ 的 `Color.withValues` API；用户已决策升级 Flutter 至 3.41+ 并采用 liquid_glass_widgets 1.x。

## 2. 术语表

- **液态玻璃**：iOS 26 Liquid Glass 设计语言对应的玻璃质感容器，具备折射、动态光照、高光描边与模糊。
- **AdaptiveGlass**：liquid_glass_widgets 的自适应玻璃容器，Impeller 上走完整 Shader 管线，Skia/Web/测试环境自动降级为磨砂回退，功能与布局不变。
- **高亮色**：`YuanSemanticColors.brandPrimary`（DESIGN.md 品牌主色）。
- **推荐（点赞）**：站点接口 `forum.php?mod=misc&action=recommend&do=add|subtract&tid=N&hash=...`，即 Discuz「支持/顶一下」。
- **收藏**：站点接口 `home.php?mod=spacecp&ac=favorite&type=thread&id=N&formhash=...`。
- **玻璃弹层**：使用液态玻璃样式的底部弹层，本次用于承载分享动作。

## 3. 需求

### FR1 底栏选中态

**用户故事**：作为论坛用户，我希望底栏当前入口以高亮色突出，以便一眼识别所在页面。

#### 验收标准

1. WHEN 某底栏入口处于选中态，系统 SHALL 以高亮色渲染该入口的图标与文字，且该入口背后 SHALL 无任何背景块（胶囊/方块）。
2. WHEN 某底栏入口处于未选中态，系统 SHALL 以次级文字色渲染，且无背景块。
3. WHEN 选中项切换，系统 SHALL 以 YuanMotion.fast 平滑过渡颜色与图标填充态，并在系统「减弱动态效果」时禁用过渡。
4. WHEN 选中项带角标，系统 SHALL 保留角标展示，角标样式不变。

### FR2 详情页悬浮玻璃回复栏

**用户故事**：作为登录用户，我希望在帖子正文底部有一个悬浮液态玻璃回复栏，随时回复、点赞、收藏与分享帖子。

#### 验收标准

1. WHEN 已登录且帖子详情加载成功，系统 SHALL 在正文底部展示悬浮液态玻璃回复栏，包含回复输入框胶囊、点赞按钮、收藏按钮、分享按钮。
2. WHEN 用户未登录，系统 SHALL 保持现有行为（展示回复栏入口；未登录动作触发登录引导）。——现状：未登录隐藏回复栏，本版本维持未登录不展示。
3. WHEN 点击回复输入框，系统 SHALL 展开为多行输入区，聚焦输入框并拉起输入法，发布按钮出现在输入框右下角。
4. WHEN 展开态下点击输入区外部区域，系统 SHALL 收起为单行胶囊态并收起键盘。
5. WHEN 回复发送成功，系统 SHALL 清空输入、收起输入区、刷新帖子内容并提示「回复成功」。
6. IF 回复发送失败，系统 SHALL 保留输入内容与展开态，并透传站点错误文案。
7. WHEN 点击点赞按钮，系统 SHALL 调用站点推荐（support）add 接口，成功后将按钮置为高亮已支持态并提示成功；WHEN 该帖本次会话内已点赞，系统 SHALL 忽略重复点赞并提示已支持。
8. WHEN 点击收藏按钮，系统 SHALL 调用站点收藏接口，成功后按钮置为已收藏态并提示「收藏成功」；IF 站点返回已收藏，系统 SHALL 提示已收藏并置为已收藏态。
9. IF 点赞/收藏请求因未登录被站点拒绝，系统 SHALL 提示用户先登录（透传站点文案或统一文案）。
10. WHEN 点击分享按钮，系统 SHALL 弹出玻璃弹层，提供「复制链接」与「在浏览器打开」两个动作；执行任一动作后关闭弹层。
11. WHEN 输入法弹出，系统 SHALL 保证输入区随键盘上移、完整可见，不被悬浮底栏或键盘遮挡。

### FR3 liquid_glass_widgets 接入

**用户故事**：作为 App 使用者，我希望底栏与回帖栏呈现真实的液态玻璃质感（动态光照、折射、高光），在低端设备与桌面/Web 上自动降级且功能完整。

#### 验收标准

1. WHEN App 启动，系统 SHALL 预热液态玻璃 Shader（`LiquidGlassWidgets.initialize()`）并以 `LiquidGlassWidgets.wrap()` 注入玻璃主题（浅色/深色两套参数）。
2. WHEN 渲染底栏或回复栏玻璃容器，系统 SHALL 使用 AdaptiveGlass（或 1.x 等价 API）承载，禁止在 Skia/Web 上走仅 Impeller 支持的裸 `LiquidGlass` 渲染路径。
3. WHEN 运行在支持 Shader 的渲染器（Impeller）上，玻璃 SHALL 呈现折射与动态光照；WHEN 运行在 Skia/Web/测试环境，系统 SHALL 平稳降级为磨砂玻璃，布局与交互不变。
4. WHEN 系统开启「减弱透明度/减弱动态效果」，系统 SHALL 自动降级玻璃强度并禁用相关动画。
5. IF glass 组件渲染异常（Shader 加载失败），系统 SHALL 回退到基础磨砂效果，App 功能不受影响。

### FR4 工具链升级

**用户故事**：作为开发者，我希望工具链升级一次到位，保证 CI 与本地验证环境一致。

#### 验收标准

1. 本地与 CI SHALL 使用 Flutter 3.41.x（Dart 3.11.x）。
2. 依赖 SHALL 加入 liquid_glass_widgets（1.x，与 Flutter 3.41 兼容的最新稳定版）。
3. 工具链升级后，`flutter analyze` SHALL 0 issue，离线测试 SHALL 全部通过；IF 升级引入既有测试失败，系统（开发者）SHALL 修复后再进入功能验收。
4. AGENTS.md 技术边界、README 构建章节 SHALL 同步更新版本号。

## 4. 非功能需求

1. **性能**：玻璃层 SHALL 独立合成层（RepaintBoundary/useOwnLayer），避免列表滚动时的重绘扩散；同一屏幕 SHALL 控制在 ≤3 个玻璃层（底栏 1 + 回复栏 1，弹层按需 +1）。
2. **可访问性**：所有新增按钮 SHALL 保留 tooltip/Semantics 标签；角标与选中态 SHALL 继续向读屏器暴露 selected 状态。
3. **兼容**：Android / iOS / 桌面 / Web SHALL 均可编译运行；玻璃降级路径 SHALL 覆盖全部平台。
4. **解析层纯度**：新增解析（点赞/收藏链接与计数）SHALL 保持纯 Dart，不 import Flutter，可用 recon 抓取样本离线回归。
5. **自动化克制**：点赞/收藏为用户主动触发，每次点击至多一次网络请求，禁止自动重试超过 1 次。
