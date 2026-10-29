# 帖子正文分享为图片（Share Post as Image）

Feature Name: post-share-image
Updated: 2026-10-29

## Description

将帖子标题、楼主信息、正文内容块与页脚信息渲染为一张固定宽度（1080px 逻辑宽，2 倍图输出）的 PNG 长图，保存到本地并通过系统分享面板分享。渲染采用 `dart:ui` Canvas 纯命令式绘制（不依赖 Flutter widget 树），跨 Android / iOS / 桌面 / Web 全平台可用，渲染逻辑纯 Dart 可离线测试。

## Architecture

### 渲染管线

```
ThreadDetail (tid/title/op Post)
  │
  ▼
[1] 内容提取：parsePostContent(op.contentHtml) → List<ContentBlock>
  │
  ▼
[2] 图片预取：过滤 image 块 → 并发下载（≤4，单张 ≤4MB，总数 ≤20）→ Map<url, ui.Image>
  │
  ▼
[3] 布局计算：逐块测量高度（Paragraph.measure）→ 累计 totalHeight
  │
  ▼
[4] 画布绘制：PictureRecorder(1080, totalHeight) → drawHeader/drawBlocks/drawFooter
  │
  ▼
[5] 编码保存：picture.toImage → encodeToPng → 写文件（path_provider）
  │
  ▼
[6] 分享：share_plus（移动端/桌面）/ blob 下载（Web）
```

### 分层结构

```
lib/core/share/
  share_renderer.dart    纯 Dart（dart:ui）：布局 + 绘制，可离线测试
  share_image_service.dart  平台适配：下载、保存、分享、Web blob
lib/ui/
  share_image_sheet.dart  分享面板中的「分享为图片」入口与进度弹窗
```

- `share_renderer.dart` 不依赖 Flutter widget，仅 `dart:ui` + `dart:async`，可用 `flutter_test` 的 `PictureRecorder` 断言输出尺寸与非空像素。
- `share_image_service.dart` 处理平台差异（path_provider 目录、share_plus、Web download），注入 `httpClient` 与 `cookieProvider` 便于测试。

## Components and Interfaces

### ShareRenderer（share_renderer.dart）

```dart
class ShareImageSpec {
  final double width;        // 逻辑宽，默认 1080
  final int maxImages;       // 嵌入图片上限，默认 20
  final int maxImageBytes;   // 单张字节上限，默认 4MB
  final int maxConcurrent;   // 下载并发，默认 4
  final double maxHeight;    // 总高上限，默认 8000
}

class ShareRenderer {
  ShareRenderer({required this.httpClient, required this.cookieProvider, this.spec = const ShareImageSpec()});

  // 渲染：输入标题/作者/时间/正文块，输出 ui.Image
  Future<ui.Image> render({
    required String title,
    required String author,
    required String authorAvatarUrl,
    required String timeText,
    required List<ContentBlock> blocks,
    required String siteName,
    required String threadUrl,
    void Function(double progress)? onProgress,
  });

  // 布局：仅计算高度，不绘制（供测试与预览）
  double computeHeight(List<ContentBlock> blocks, {required ui.Image? placeholderForMissing});
}
```

### ShareImageService（share_image_service.dart）

```dart
class ShareImageService {
  ShareImageService({required this.renderer, required this.saver});

  // 一键：渲染 → 保存 → 分享。返回保存路径。
  Future<String> generateAndShare({
    required String title,
    required String author,
    required String authorAvatarUrl,
    required String timeText,
    required List<ContentBlock> blocks,
    required String siteName,
    required String threadUrl,
    void Function(String phase)? onPhase,
  });

  // Web 端 blob 下载
  Future<void> downloadPng(ui.Image image, String fileName);
}
```

### UI 入口

- 详情页「分享」弹层新增「分享为图片」按钮（第 4 项，位于「复制链接」「浏览器」之前）。
- 渲染期间显示进度弹窗（LiquidGlass 风格）：「正在生成分享图片 42%」。
- 失败时弹层内展示原因 + 「复制链接」降级按钮。

## Data Models

复用现有 `ContentBlock`（`lib/data/content.dart`）：

| BlockKind | 渲染方式 |
|-----------|----------|
| text | Paragraph 文本，支持 bold/italic/underline/strike/href/color/fontSize |
| quote | 左侧 4px 竖线 + 灰色底，文本样式同 text |
| code | 等宽字体（monospace），浅灰底，保留换行与缩进 |
| image | 缩放到内容宽度，居中；失败时灰色占位块 + 「图片加载失败」 |
| divider | 1px 灰线 |

新增轻量模型：

```dart
class ShareHeader {
  final String title;
  final String author;
  final String? avatarUrl;
  final String timeText;
}

class ShareFooter {
  final String siteName;
  final String threadUrl;
}
```

## Correctness Properties

1. 图片宽度恒为 1080 逻辑像素，高度按内容自适应，不超过 `maxHeight`（截断 + 底部提示）。
2. 正文内容块渲染顺序与详情页一致（parsePostContent 顺序）。
3. 附件图片下载失败不阻断整体渲染，以占位符替代。
4. 渲染完成后释放所有 `ui.Image` 解码资源（`dispose`）。
5. 分享图片不包含回帖内容（仅楼主首帖）。
6. 锁定帖（付费/登录）且当前用户无权限时，入口禁用。
7. 页脚链接为完整 URL（`kBaseUrl` + 相对路径），非相对路径。
8. 渲染逻辑纯 Dart（`dart:ui` + `dart:async`），不 import Flutter widgets，可通过 `flutter_test` 离线断言。

## Error Handling

| 场景 | 处理 |
|------|------|
| 图片下载失败/超时 | 占位符替代，计入失败计数，不阻断 |
| 图片超过 4MB | 跳过下载，占位符替代 |
| 图片超过 20 张 | 仅下载前 20 张，其余占位符 |
| 渲染高度超 8000px | 截断 + 底部「内容过长，仅展示部分内容」 |
| 保存失败（权限/空间） | 弹层提示 + 「复制链接」降级按钮 |
| share_plus 不支持当前平台 | 展示保存路径，用户手动分享 |
| Web 无 File 系统 | 触发浏览器下载 PNG |
| 用户未登录 | 仅渲染可见内容，不请求未授权资源 |

## Test Strategy

1. **布局测试**（`test/share_renderer_test.dart`）：
   - 纯文本块高度计算正确
   - 混合块（text+quote+code+image+divider）高度累加
   - 超长内容截断到 maxHeight
2. **渲染测试**（`test/share_renderer_test.dart`）：
   - `PictureRecorder` 输出尺寸 = (1080, computedHeight)
   - 输出像素非全白（有内容绘制）
   - 图片块下载失败时占位符渲染
3. **服务测试**（`test/share_image_service_test.dart`）：
   - 保存路径正确
   - Web blob 下载触发
4. **集成测试**（`test/share_integration_test.dart`）：
   - 详情页分享弹层包含「分享为图片」入口
   - 锁定帖入口禁用

## References

[^1]: `lib/data/content.dart` - ContentBlock 模型与解析
[^2]: `lib/design/tokens.dart` - 颜色/间距 token（渲染器使用固定值，不随主题）
[^3]: `lib/core/image_loader.dart` - Cookie/防盗链图片下载参考
[^4]: `lib/ui/pages/thread_detail_page.dart` - 现有分享弹层 `_showShareSheet`（:1133）
