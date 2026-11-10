# Requirements Document: 分享图片二维码

## Introduction

用户希望分享图片底部包含帖子链接二维码，扫码即可访问帖子，降低站外用户访问门槛。

## Glossary

- **分享图片**：由帖子标题、正文内容与页脚渲染生成的单张长图（PNG）。
- **二维码**：将帖子链接编码为 QR Code 并在分享图片上渲染的矩阵图案。
- **渲染器**：`lib/core/share/share_renderer.dart` 中的 `ShareRenderer`，使用 `dart:ui` Canvas 纯命令式绘制。

## Requirements

### Requirement 1: 二维码渲染

**User Story:** AS 分享图片接收者，我希望扫码即可访问帖子，so that 无需手动输入链接。

#### Acceptance Criteria

1. WHEN 渲染分享图片时，THE 系统 SHALL 在页脚区域绘制帖子链接二维码。
2. WHEN 绘制二维码时，THE 系统 SHALL 使用 QR Code 标准编码帖子完整 URL。
3. IF 帖子链接为空，THE 系统 SHALL 跳过二维码绘制并保留页脚文字。

### Requirement 2: 布局与尺寸

**User Story:** AS 用户，我希望二维码与页脚文字协调排版，so that 分享图片美观易读。

#### Acceptance Criteria

1. WHEN 渲染页脚时，THE 系统 SHALL 将二维码置于页脚右侧，文字信息置于左侧。
2. WHEN 渲染二维码时，THE 系统 SHALL 使用固定尺寸（默认 120×120 逻辑像素）。
3. WHEN 渲染页脚时，THE 系统 SHALL 保持站点名、App 标识与帖子链接文字在二维码左侧。

### Requirement 3: 兼容性与降级

**User Story:** AS 用户，我希望二维码功能在各平台正常工作，so that 跨平台分享体验一致。

#### Acceptance Criteria

1. WHEN 渲染分享图片时，THE 系统 SHALL 使用纯 Dart 生成二维码矩阵数据，不依赖平台通道。
2. IF 二维码生成失败，THE 系统 SHALL 以纯文字页脚降级，不阻断分享图片渲染。
3. WHEN 渲染分享图片时，THE 系统 SHALL 保持渲染逻辑可通过 `flutter_test` 离线断言。
