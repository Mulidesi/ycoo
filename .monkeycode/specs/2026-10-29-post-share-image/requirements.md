# Requirements Document: 帖子正文分享为图片

## Introduction

用户希望将帖子标题与正文渲染为一张分享图片，保存到本地并用于分享（微信、QQ、系统相册等）。该功能面向帖子详情页，作为现有「复制链接 / 浏览器打开」之外的第三种分享方式，降低站外用户阅读门槛。

## Glossary

- **分享图片**：由帖子标题、正文内容与页脚信息渲染生成的单张长图（PNG）。
- **正文**：帖子楼主（首帖）的正文 HTML（`Post.contentHtml`），已通过 `parsePostContent` 解析为内容块。
- **本地保存**：图片写入本机文件系统（如相册目录或应用目录）。
- **分享面板**：系统级分享入口（iOS 分享面板 / Android Intent.ACTION_SEND / Web 下载）。

## Requirements

### Requirement 1: 分享入口

**User Story:** AS 帖子详情页用户，我希望在帖子详情页提供「分享为图片」入口，以便将帖子正文以图片形式分享给他人。

#### Acceptance Criteria

1. WHEN 用户在帖子详情页点击「分享」操作按钮时，THE 系统 SHALL 展示包含「分享为图片」选项的分享面板。
2. WHEN 用户选择「分享为图片」时，THE 系统 SHALL 开始渲染帖子为图片。
3. IF 帖子正文为空或正文仅包含锁定提示（付费/登录锁定且无权限），THE 系统 SHALL 禁用「分享为图片」入口并提示原因。
4. IF 渲染失败（图片解码失败、网络异常、存储权限拒绝），THE 系统 SHALL 向用户展示失败提示，并保留「复制链接」作为降级分享方式。

### Requirement 2: 分享内容范围

**User Story:** AS 用户，我希望分享图片包含帖子标题、正文内容与来源信息，以便接收者了解帖子概况。

#### Acceptance Criteria

1. WHEN 渲染分享图片时，THE 系统 SHALL 包含以下元素：帖子标题、楼主昵称与头像、楼主正文文本块（含引用块、代码块）、页脚（站点名 + 帖子链接 + App 标识）。
2. IF 正文包含图片附件，THE 系统 SHALL 将附件图片下载后嵌入分享图片；下载失败的图片 SHALL 以占位符（「图片加载失败」灰色块）替代。
3. IF 正文包含视频、音频或 iframe 等富媒体，THE 系统 SHALL 以文本占位符（如「[视频]」「[iframe]」）替代，不嵌入富媒体内容。
4. IF 正文超过最大行数限制（默认 100 行），THE 系统 SHALL 截断并在图片底部显示「内容过长，仅展示部分内容」。
5. IF 正文包含表情图片（论坛表情），THE 系统 SHALL 将表情图片渲染为对应图片或文本占位符。

### Requirement 3: 图片尺寸与渲染

**User Story:** AS 用户，我希望分享图片宽度固定、内容完整清晰，以便在社交平台正常展示。

#### Acceptance Criteria

1. WHEN 渲染分享图片时，THE 系统 SHALL 使用固定宽度（默认 1080px，2 倍图输出）渲染长图，高度按内容自适应。
2. WHEN 渲染分享图片时，THE 系统 SHALL 使用浅色背景（#FFFFFF）与深色文字（#1A1A1A）的固定排版，不跟随 App 主题模式。
3. WHEN 渲染分享图片时，THE 系统 SHALL 使用中文字体（系统默认中文字体，如 PingFang / Roboto + 中文回退）。
4. WHEN 渲染分享图片时，THE 系统 SHALL 将正文 HTML 内容块（文本/引用/代码/图片/分割线）逐块排版，保持与详情页一致的层级关系。
5. IF 正文内容块超过图片高度上限（默认 8000px），THE 系统 SHALL 截断并显示截断提示。

### Requirement 4: 本地保存与分享

**User Story:** AS 用户，我希望图片生成后保存到本地并可调用系统分享，以便发送给好友或保存到相册。

#### Acceptance Criteria

1. WHEN 图片渲染成功后，THE 系统 SHALL 将 PNG 文件写入本机存储（优先相册目录，其次应用目录）。
2. WHEN 图片保存成功后，THE 系统 SHALL 调用系统分享面板，并提供图片文件供分享。
3. WHEN 保存失败（存储权限拒绝、磁盘空间不足），THE 系统 SHALL 展示失败提示，并提供「复制链接」降级选项。
4. IF 用户取消系统分享面板，THE 系统 SHALL 保留已保存的图片文件，不删除。
5. WHEN 渲染过程中，THE 系统 SHALL 展示加载进度（如「正在生成分享图片」），渲染时间超过 3 秒 SHALL 保持进度可见。

### Requirement 5: 性能与资源约束

**User Story:** AS 用户，我希望生成分享图片过程流畅，不卡顿、不崩溃。

#### Acceptance Criteria

1. WHEN 渲染分享图片时，THE 系统 SHALL 在后台线程执行渲染，不阻塞 UI 线程。
2. WHEN 渲染分享图片时，THE 系统 SHALL 限制同时下载的附件图片数量（默认 4 张并发）。
3. IF 正文包含超过 20 张图片，THE 系统 SHALL 仅下载前 20 张，其余以占位符替代。
4. WHEN 渲染分享图片时，THE 系统 SHALL 限制图片最大尺寸（单张附件图片超过 4MB 时 SHALL 跳过下载并使用占位符）。
5. WHEN 渲染分享图片时，THE 系统 SHALL 在渲染完成后释放所有图片解码资源。

### Requirement 6: 多平台支持

**User Story:** AS 用户，我希望该功能在 Android / iOS / Windows / macOS / Linux / Web 均可使用。

#### Acceptance Criteria

1. WHEN 运行在 Android 时，THE 系统 SHALL 通过相册目录保存并通过 Intent 分享。
2. WHEN 运行在 iOS 时，THE 系统 SHALL 通过相册保存并通过 UIActivityViewController 分享。
3. WHEN 运行在桌面端（Windows / macOS / Linux）时，THE 系统 SHALL 保存到用户可访问的目录并通过系统分享或文件管理器展示路径。
4. WHEN 运行在 Web 时，THE 系统 SHALL 触发浏览器下载 PNG 文件（Web 不提供系统分享面板）。
5. IF 平台不支持系统分享面板，THE 系统 SHALL 展示图片保存路径供用户手动分享。

### Requirement 7: 可访问性与降级

**User Story:** AS 用户，我希望分享图片失败时仍可分享帖子链接。

#### Acceptance Criteria

1. WHEN 渲染或保存失败时，THE 系统 SHALL 在错误提示中提供「复制链接」按钮。
2. WHEN 网络不可用且正文包含图片附件时，THE 系统 SHALL 使用纯文本渲染正文（图片以占位符替代）。
3. IF 用户未登录，THE 系统 SHALL 允许渲染可见的帖子内容（不请求未授权内容）。
