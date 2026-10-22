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
- Date: 2026-10-22
- Context: Discovered by Agent while running tests for the view-user feature
- Category: Environment Configuration
- Instructions:
  - Flutter SDK 3.24.5 (Dart 3.5.4) is not preinstalled in this environment; it was installed to `/opt/sdk/flutter` because `ycoo_client` requires `sdk: ^3.5.4`.
  - Run `export PATH=/opt/sdk/flutter/bin:$PATH`, then `cd ycoo_client && flutter pub get && flutter analyze && flutter test`. If `/opt/sdk/flutter` is missing, install the same stable version first.
  - `flutter pub get` rewrites `ycoo_client/pubspec.lock`; restore it with `git checkout -- ycoo_client/pubspec.lock` after testing to avoid unintended dependency churn.
  - `test/detail_layout_test.dart` is skipped when `recon/thread_login.html` fixture is absent; this is expected and unrelated to feature failures.

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
