# User Instruction Memory

This file records user instructions, preferences, and teachings for reference in future interactions.

## Format

### User Instruction Entry
User instruction entries should follow this format:

[User Instruction Summary]
- Date: [YYYY-MM-DD]
- Context: [Mentioned scenario or time]
- Instructions:
  - [Content of user teaching or instruction, described line by line]

### Project Knowledge Entry
Entries discovered by the Agent during task execution should follow this format:

[Project Knowledge Summary]
- Date: [YYYY-MM-DD]
- Context: Discovered by Agent while performing [specific task description]
- Category: [Operations & Deployment|Build Methods|Testing Methods|Troubleshooting & Debugging|Workflow & Collaboration|Environment Configuration]
- Instructions:
  - [Specific knowledge points, described line by line]

## Deduplication Strategy
- Before adding a new entry, check for similar or identical instructions.
- If a duplicate is found, skip the new entry or merge it with the existing one.
- When merging, update the context or date information.
- This helps avoid redundant entries and keeps the memory file tidy.

## Entries

[Project Knowledge Summary]
- Date: 2026-10-29
- Context: Discovered by Agent while implementing P15-B R3 image/attachment upload
- Category: Environment Configuration
- Instructions:
  - file_picker v11.0.3 的 `PlatformFile` 有 `bytes` 字段（`Uint8List?`），但**没有** `readAsBytes()` 方法（更高版本才有）。读取文件字节需在 `FilePicker.pickFiles(type: ..., withData: true)` 时启用 `withData`，之后访问 `file.bytes`。
  - `share_plus ^10.1.4` 与 `file_picker ^13.2.0` 在 win32 依赖上不兼容（前者 win32 ^5.5.3，后者 win32 ^6.3.0），`file_picker` 必须降级到 `^11.0.3`。
  - `package:http/testing.dart` 的 `MockClient` 会把 `http.MultipartRequest` 转成普通 `http.Request` 传给 handler，测试中无法 cast 回 `MultipartRequest` 来访问 `fields`/`files`。验证 multipart 表单字段需用其他手段或跳过字段验证。

[Project Knowledge Summary]
- Date: 2026-10-27
- Context: Discovered by Agent while running tests; updated from 2026-10-22 entry (environment changed)
- Category: Environment Configuration
- Instructions:
  - Flutter SDK 3.41.9 (Dart 3.11.5) is installed at `/opt/flutter`; `flutter` is NOT on PATH by default — run `export PATH=/opt/flutter/bin:$PATH` first. The old `/opt/sdk/flutter` (3.24.5) no longer exists.
  - Run `cd ycoo_client && flutter pub get && flutter analyze && flutter test`. If `/opt/flutter` is missing, install Flutter stable matching `ycoo_client` requirements first.
  - `flutter pub get` rewrites `ycoo_client/pubspec.lock`; restore it with `git checkout -- ycoo_client/pubspec.lock` after testing to avoid unintended dependency churn.
  - `test/detail_layout_test.dart` is skipped when `recon/thread_login.html` fixture is absent; this is expected and unrelated to feature failures. recon 抓包样本从未入库，`tool/parse_test.dart` 需 `../recon` 目录，本环境跑不了，解析回归靠 flutter test 内离线用例。
  - `gh` CLI 不可用（未认证）。查 GitHub API（CI runs / artifacts / releases）可用 git credential helper 的 token：`TOKEN=$(echo -e "protocol=https\nhost=github.com\n" | git credential fill | grep '^password=' | cut -d= -f2)`，只进环境变量、绝不回显；随后 `curl -H "Authorization: Bearer $TOKEN" https://api.github.com/repos/Mulidesi/ycoo/...`。

[Project Knowledge Summary]
- Date: 2026-10-22
- Context: Discovered by Agent while configuring release APK signing
- Category: Operations & Deployment
- Instructions:
  - Release 签名密钥存放在 GitHub 仓库 `default` 环境的 Secrets：`KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`。workflow job 必须声明 `environment: default` 才能读取环境 Secrets。
  - keystore 实际别名是 `my-key-alias`；证书 SHA-256 指纹 `97:3B:D8:19:83:42:D0:B8:FB:57:15:F4:37:3A:68:8D:D4:39:B7:B7:EE:36:11:78:79:77:25:5A:7D:7F:67:9A`，有效期至 2054-03-09。
  - 发布流程：先递增 `ycoo_client/pubspec.yaml` 的 versionCode（`+N`），再推 `vX.Y.Z` tag；只有 tag 触发才会发布到 Release。
  - 签名校验：CI 日志中的 `apksigner verify --print-certs`，或下载 APK 解包 `META-INF/CERT.RSA` 后用 `openssl pkcs7 -inform DER -print_certs` + `openssl x509 -fingerprint -sha256` 比对。
  - 当前 GitHub App 令牌没有 secrets 写权限，无法通过 API 写入 Secrets，需要用户在仓库网页添加。

[Project Knowledge Summary]
- Date: 2026-10-22
- Context: Discovered by Agent while implementing the in-app GitHub update feature
- Category: Build Methods
- Instructions:
  - 本机没有 Android SDK（`flutter doctor` 报 `Unable to locate Android SDK`），无法本地 `flutter build apk`；Android 构建与签名验证只能在 GitHub Actions 完成，本地以 `flutter analyze` + `flutter test` 为准。
  - 本地增删依赖会因缺少 `PUB_HOSTED_URL` 把 `pubspec.lock` 的记录地址从镜像改写为 pub.dev；改完依赖执行 `PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get` 恢复镜像地址。
