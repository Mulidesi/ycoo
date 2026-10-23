#!/usr/bin/env bash
# 修复 Flutter 3.41.9 自带 Gradle 插件的两个构建缺陷（本地与 CI 通用）。
#
# 1. dependency_version_checker.gradle.kts 在编译期引用 com.android.Version，
#    AGP 8.11.1 已不提供该类，改为按类名字符串反射加载。
# 2. src/main/groovy 旧插件与 Kotlin DSL 生成插件都会产出默认包
#    FlutterPlugin.class，:gradle:jar 未设置重复策略导致打包失败。
#
# 升级 Flutter 后如官方已修复，可直接删除本脚本与 CI 中的调用。
set -euo pipefail

FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(dirname "$(command -v flutter)")")}"
PLUGIN_DIR="$FLUTTER_ROOT/packages/flutter_tools/gradle"
CHECKER="$PLUGIN_DIR/src/main/kotlin/dependency_version_checker.gradle.kts"
BUILD_SCRIPT="$PLUGIN_DIR/build.gradle.kts"

if [ ! -f "$CHECKER" ] || [ ! -f "$BUILD_SCRIPT" ]; then
  echo "patch_flutter_gradle_plugin: 未找到 Gradle 插件源码，跳过"
  exit 0
fi

if grep -q 'com\.android\.Version::class\.java\.name' "$CHECKER"; then
  sed -i 's|com\.android\.Version::class\.java\.name|"com.android.Version"|g' "$CHECKER"
  sed -i 's|com\.android\.builder\.model\.Version::class\.java\.name|"com.android.builder.model.Version"|g' "$CHECKER"
  echo "patch_flutter_gradle_plugin: 已改为反射加载 AGP 版本类"
fi

if ! grep -q 'DuplicatesStrategy.EXCLUDE' "$BUILD_SCRIPT"; then
  cat >> "$BUILD_SCRIPT" <<'EOF'

// Legacy Groovy sources coexist with the Kotlin migrations and both produce a
// default-package FlutterPlugin class. Keep the first entry instead of failing.
tasks.withType<Jar> {
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
}
EOF
  echo "patch_flutter_gradle_plugin: 已设置 jar 重复类策略"
fi
