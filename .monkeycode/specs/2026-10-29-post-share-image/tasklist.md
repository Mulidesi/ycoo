# Task List: post-share-image

## 1. 依赖与文档

- [x] 1.1 `pubspec.yaml` 增加 `share_plus`
- [x] 1.2 TODO.md 写入 P15-F；Android FileProvider / queries 补分享路径

## 2. 渲染器

- [x] 2.1 `lib/core/share/share_renderer.dart`：布局 + Canvas 绘制
- [x] 2.2 图片预取（并发/大小/数量上限）与失败占位
- [x] 2.3 超高 / 超行截断

## 3. 保存与分享

- [x] 3.1 `share_platform_io.dart` / `share_platform_web.dart` 条件导出
- [x] 3.2 `share_image_service.dart` 渲染 → 编码 → 保存 → 分享

## 4. UI

- [x] 4.1 分享弹层增加「分享为图片」
- [x] 4.2 进度弹窗、失败降级「复制链接」
- [x] 4.3 锁定/空正文禁用入口

## 5. 测试

- [x] 5.1 `test/share_renderer_test.dart`
- [x] 5.2 `test/share_image_service_test.dart`
- [x] 5.3 弹层入口 widget 测试
- [x] 5.4 `flutter analyze` + `flutter test`

## 验证记录

- `flutter analyze`：0 issue
- `flutter test`：171 通过 + 1 跳过（缺 recon 样本）
- 新增测试：`share_renderer_test`（11 例）/ `share_image_service_test`（3 例）/ `share_sheet_test`（2 例），共 16 例
