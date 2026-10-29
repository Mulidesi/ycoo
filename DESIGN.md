# DESIGN.md

源论坛 App（ycoo.net 客户端）视觉与交互硬约束。所有 UI 实现先对本文件，数值一律来自 `lib/design/tokens.dart`（`YuanColors` / `YuanSpace` / `YuanRadius` / `YuanType` / `YuanMotion` / `YuanSizes` / `YuanSemanticColors`）。本文中 `lib/` 路径均以 `ycoo_client/` 工程目录为基准。

> 本文档合并自 yuan_forum 设计规范（v0.1），与本仓库 v1.0.4 起的实现保持同步。

## 1. 设计原则

1. **Material Design 3**：`ColorScheme.fromSeed`，组件使用 Material 3 变体（Filled / Tonal / Outlined）。
2. **信息层级优先于装饰**：帖子正文 > 回帖 > 楼中楼，层级靠字号、表面色、边线、头像尺寸表达。
3. **站内闭环**：回复、签到、登录在 App 内完成；正文外链点按复制、可浏览器打开，但主流程不依赖浏览器。
4. **深浅色对等**：每一个表面、边、玻璃层都定义 Light / Dark 语义色，禁止只做浅色再反相。
5. **液态玻璃克制使用**：仅悬浮底栏与帖子详情底部回复栏使用玻璃；内容卡片保持不透明，保证可读性。同屏玻璃层不超过 3 层。
6. **Token 单一来源**：颜色、间距、圆角、字号一律走 `lib/design/tokens.dart`，禁止散落 Magic Number。

## 2. 品牌与种子色

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `seed` | `#2563EB` | `#60A5FA` | ColorScheme 种子 |
| `brand.primary` | `#2563EB` | `#93C5FD` | 主操作、选中底栏 |
| `brand.deep` | `#1E40AF` | `#1E3A8A` | 渐变端点、强调文字 |
| `brand.secondary` | `#0EA5E9` | `#38BDF8` | 次强调（热门、话题） |
| `brand.tertiary` | `#F59E0B` | `#FBBF24` | 星币、付费、签到奖励 |

源站点视觉偏科技蓝。种子色取蓝，星币走琥珀，避免积分与正文抢层级。

## 3. 语义色（Light / Dark）

| Token | Light | Dark |
|-------|-------|------|
| `surface.base` | `#FFFBFF` | `#111318` |
| `surface.dim` | `#F3F4F6` | `#0B0D11` |
| `surface.container` | `#F8F9FC` | `#1A1D24` |
| `surface.containerHigh` | `#FFFFFF` | `#23262E` |
| `surface.threadBody` | `#FFFFFF` | `#1C1F27` |
| `surface.reply` | `#F4F6FA` | `#181B22` |
| `surface.comment` | `#EEF1F6` | `#15181E` |
| `text.primary` | `#0F172A` | `#F1F5F9` |
| `text.secondary` | `#475569` | `#94A3B8` |
| `text.tertiary` | `#94A3B8` | `#64748B` |
| `outline.subtle` | `#E2E8F0` | `#2A2F3A` |
| `outline.replyRail` | `#CBD5E1` | `#3F4654` |
| `state.success` | `#16A34A` | `#4ADE80` |
| `state.danger` | `#DC2626` | `#F87171` |
| `state.warning` | `#D97706` | `#FBBF24` |
| `glass.fill` | `rgba(255,255,255,0.62)` | `rgba(22,24,31,0.55)` |
| `glass.stroke` | `rgba(255,255,255,0.55)` | `rgba(255,255,255,0.12)` |
| `glass.highlight` | `rgba(255,255,255,0.85)` | `rgba(255,255,255,0.18)` |

对比度：正文与表面 ≥ 4.5:1；次要文字 ≥ 3:1。
Widget 一律通过 `YuanSemanticColors.of(context)` 取色，禁止自行判断 `ThemeMode` 再拼颜色。

## 4. 间距、圆角、字号、运动

### 间距 `space`

`4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48`。页面水平边距 `space.md = 16`；卡片内边距 `space.sm = 12`。

### 圆角 `radius`

| Token | 值 | 用途 |
|-------|----|------|
| `xs` | 8 | Chip、图片圆角 |
| `sm` | 12 | 回帖卡片、输入框 |
| `md` | 16 | 帖子卡片、正文卡 |
| `lg` | 24 | 底栏胶囊、对话框 |
| `pill` | 999 | 选中指示、徽章 |

### 字号 `type`

| Token | 字号 / 行高 / 字重 | 用途 |
|-------|---------------------|------|
| `display` | 28 / 36 / 600 | 空态大标题（少用） |
| `titleLg` | 22 / 28 / 600 | 页面标题 |
| `titleMd` | 18 / 24 / 600 | 帖子标题 |
| `titleSm` | 16 / 22 / 600 | 板块名、分区名 |
| `bodyLg` | 16 / 26 / 400 | **帖子正文** |
| `bodyMd` | 14 / 22 / 400 | **回帖正文** |
| `bodySm` | 13 / 20 / 400 | **楼中楼 / 摘要** |
| `label` | 12 / 16 / 500 | 元信息、时间 |
| `caption` | 11 / 14 / 400 | 辅助提示 |

### 运动 `motion`

`fast` 150ms / `normal` 250ms / `slow` 400ms；底栏选中位移动画用 `springNav`（easeOutBack）。
减少动态（`MediaQuery.disableAnimations`）时所有位移改为淡入淡出 150ms。

## 5. 悬浮液态玻璃底栏

窄屏三 Tab：**首页、版块、我的**（宽屏 NavigationRail 保留四入口，签到并入「我的」）。

结构：`SafeArea → Padding(16, 4/12) → GlassContainer(LiquidRoundedSuperellipse 24, blur 6, thickness 24)`，高 64。
玻璃面由 `liquid_glass_widgets` 渲染，参数统一走 `YuanGlass`；Shader 不可用时组件库自动退回磨砂。

交互：

- 未选中：线性图标 24px，`text.secondary`，标签 `label`。
- 选中：填充图标 + `brand.primary` + 标签 `w600`，图标/文字 150ms 过渡。
- **选中态不画任何背景块 / 胶囊 / 椭圆指示**，只靠高亮色与图标形态区分。
- `extendBody: true`，列表底部预留底栏空间。

禁止：底栏贴屏幕底边、直角、实心不透明条、给选中项加方块或胶囊底色。

### 5.1 详情页玻璃回复栏

位置：详情页 body 底部（随键盘上移），左右/底部 12 外边距，悬浮在内容之上。

- 收起态（默认）：高 56 的单行输入胶囊 + 点赞 / 收藏 / 分享三个 `GlassIconButton`；点击胶囊展开并聚焦。
- 展开态：同一玻璃容器变为 24 圆角，最少 148 高；多行输入（3–6 行）+ 同一组操作 + 右下角「发布」。
- 键盘收起且无草稿时自动回收起态；有草稿保持展开，避免丢内容。
- 点赞 / 收藏成功后本地高亮（`brand.primary` 填充图标）；分享用 `GlassModalSheet` 弹层（分享为图片 / 复制链接 / 浏览器打开）。分享图片为固定浅色长图，不跟随主题。
- 玻璃层：容器 1 层，按钮与弹层复用/叠加后同屏 ≤ 3 层。

## 6. 页面骨架

### 6.1 首页

四个信息流（最新发表 / 热门 / 回复 / 精华）+ 下拉刷新 + 触底加载。
帖子卡片（`ThreadTile`）：作者行（头像/昵称/时间/版块胶囊）→ 标题 → 摘要 2 行 → 16:9 首图（「N 图」角标）→ 浏览/回复/点赞数据行。没有预览时卡片自动收缩。

### 6.2 版块

分组折叠式浏览、今日新增、主题/帖数、私密标识、搜索入口。

### 6.3 帖子详情（视觉差硬约束）

| 层级 | 表面 | 字号 | 头像 | 识别 |
|------|------|------|------|------|
| 正文（1 楼） | `surface.threadBody`，无左边线 | `bodyLg` 16/26 | 34 | 标题 + 作者行 + 操作行 |
| 回帖 | `surface.reply` + 左 3px `outline.replyRail` | `bodyMd` 14/22 | 30 | 楼层号（沙发/板凳/报纸/N 楼） |

规则：

- 评论排序：正序 / 倒序切换；单页显示「已经到底了」，多页显示翻页器。
- 表情 / 图片：正文图限高 420px，评论图 300px，点开进可缩放画廊。
- 链接：主色下划线；裸 URL 自动识别为可点击 run（去尾部中文标点）。
- 隐藏块锁定：条件文案 + 自动回复提示；付费帖引导（琥珀色警示条）。
- 底部 `ReplyComposerBar`：输入「@作者」预填；发送后刷新列表。

### 6.4 我的

个人卡（渐变蓝 + 头像/昵称/UID/用户组/积分/主题/回帖/好友）→ 分组列表：

1. **自动功能**：每日签到入口、自动签到开关、隐藏贴自动回复开关、自动回复预设（5 条随机）、自动化记录、每日上限、清除记录。
2. **外观**：跟随系统 / 浅色 / 深色，持久化到 `SharedPreferences`。
3. **账号**：图片诊断、浏览器打开、退出登录。

开启自动回复时若有效预设不足 1 条，拦截并提示先添加预设。

## 7. 组件形态

| 组件 | 形态 | 禁止 |
|------|------|------|
| 主按钮 | FilledButton，高 50，圆角 12 | 渐变按钮、全大写 |
| 次按钮 | Tonal / Outlined | 纯文字当主操作 |
| 卡片 | 不透明表面 + 细 outline | 全站玻璃卡片 |
| Chip | 胶囊 + outline | 彩色胶囊堆砌 |
| 对话框 | 圆角 24 | 全屏 WebView 购买 |
| 输入 | 填充式圆角 12 | 下划线旧风格 |
| 头像 | CircleAvatar | 方形头像（除板块图标） |

## 8. 深浅色切换

- 默认跟随系统；「我的 → 外观」三选一，持久化到 `SharedPreferences`（`settings.themeMode`）。
- `MaterialApp.themeMode` 由 `AppState.settings.themeMode` 驱动。
- 深色模式禁止大面积 `#000`，用 `surface.base`。

## 9. 无障碍与适配

- 最小点击区域 48×48。
- 宽度 ≥ 900 自动切换 `NavigationRail` 侧栏布局（PC/平板），≥1240 扩展标签。
- 图片加载失败显示真实原因 + 「重试」。
- 动态字体放大时底栏标签单行省略。

## 10. 验收清单（视觉）

- [x] 三 Tab 悬浮胶囊底栏，液态玻璃可见；选中项仅高亮色，无背景块。
- [x] 详情页底部玻璃回复栏：收起/展开、点赞/收藏/分享、发布按钮右下角。
- [x] 正文 16px、回帖 14px，表面色与左边线可区分。
- [x] 浅色 / 深色切换后无硬编码色残留（`grep Color(0x` 仅剩 tokens.dart）。
- [x] 星币、签到入口使用 tertiary 琥珀，不与主蓝冲突。
- [x] 外观三选一立即生效并持久化。
