# 分享图片二维码

Feature Name: share-image-qr-code
Updated: 2026-11-10

## Description

在分享图片页脚右侧绘制帖子链接二维码（120×120 逻辑像素），左侧保留站点名、App 标识与完整 URL 文字。二维码使用 `qr` 包纯 Dart 生成矩阵数据，渲染器逐模块绘制到 Canvas，不依赖平台通道。

## Architecture

### 渲染管线变更

```
ShareFooter(threadUrl)
  │
  ▼
[1] QR 矩阵生成：QrCode(payload: QrPayload.fromString(url)) → QrImage（moduleCount × moduleCount）
  │
  ▼
[2] 页脚布局：文字区（左）+ 二维码区（右）
  │
  ▼
[3] Canvas 绘制：逐模块 drawRect（dark 模块填黑，light 模块留白）
  │
  ▼
[4] 输出 PNG（含二维码的完整分享图片）
```

### 分层结构

```
lib/core/share/
  share_renderer.dart    新增 _drawQrCode 方法；页脚布局改为左右分栏
  share_image_service.dart  无变更（URL 已在 ShareFooter 中）
```

- `qr` 包仅用于生成矩阵数据（纯 Dart），不引入 Flutter widget
- 渲染器保持纯 `dart:ui`，可离线测试

## Components and Interfaces

### ShareImageSpec 扩展

```dart
class ShareImageSpec {
  // ...existing fields...
  final bool showQrCode;      // 默认 true
  final double qrCodeSize;    // 默认 120
  final double qrQuietZone;   // 默认 4 modules
}
```

### ShareRenderer 新增方法

```dart
class ShareRenderer {
  // 生成 QR 矩阵并绘制到 canvas
  void _drawQrCode(
    ui.Canvas canvas,
    String data,
    ui.Offset origin,
    double size,
  );
}
```

### qr 包 API

```dart
import 'package:qr/qr.dart';

final qrCode = QrCode.fromData(
  data: url,
  errorCorrectLevel: QrErrorCorrectLevel.M,
);
final qrImage = QrImage(qrCode);
// qrImage.moduleCount → 模块数（如 29）
// qrImage.isDark(row, col) → bool
```

## Data Models

无新增模型。`ShareFooter.threadUrl` 作为 QR 数据源。

## 页脚布局

```
┌──────────────────────────────────────────────┐
│ 站点名 · App 标识           ┌──────────────┐  │
│ https://ycoo.net/thread-…   │   QR Code    │  │
│                             │  (120×120)   │  │
│                             └──────────────┘  │
└──────────────────────────────────────────────┘
```

- 左侧文字区宽度 = contentW - qrSize - gap（gap 默认 20）
- 页脚高度 = max(文字区高度, qrSize) + padding
- 二维码带 4 module 静区（白色边框）

## Correctness Properties

1. 二维码编码完整帖子 URL（`kBaseUrl` + 相对路径）。
2. 二维码 module 绘制精度：每个 module 为正方形，尺寸 = qrSize / moduleCount。
3. 二维码静区 ≥ 4 modules，保证扫码识别率。
4. URL 文字与二维码并排，不重叠。
5. 二维码生成失败时以纯文字页脚降级，不阻断渲染。
6. 渲染逻辑纯 Dart，可通过 `flutter_test` 离线断言。

## Error Handling

| 场景 | 处理 |
|------|------|
| URL 为空 | 跳过二维码，仅文字页脚 |
| QR 矩阵生成失败 | 跳过二维码，仅文字页脚 |
| URL 过长（> 2000 字符） | 使用 ERROR_CORRECT_M，仍失败则降级 |

## Test Strategy

1. **QR 矩阵测试**：
   - 生成 QR 矩阵，moduleCount > 0
   - 矩阵尺寸与 URL 长度匹配
2. **布局测试**：
   - 页脚高度 = max(文字高, 120) + padding
   - 文字区宽度 = contentW - 120 - 20
3. **渲染测试**：
   - 输出图片包含非白像素（二维码区域）
   - 降级模式（URL 为空）不绘制二维码
4. **集成测试**：
   - 分享图片包含二维码区域像素

## References

[^1]: `lib/core/share/share_renderer.dart` - ShareRenderer 与页脚绘制
[^2]: `pubspec.yaml` - 新增 `qr` 依赖
[^3]: https://pub.dev/packages/qr - QR 矩阵生成包
