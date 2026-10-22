import 'dart:io';

import 'package:flutter/services.dart';

/// 调用 Android 原生安装器安装已下载的 APK。
class ApkInstaller {
  static const _channel = MethodChannel('net.ycoo.ycoo_client/updater');

  /// 当前安装包版本号（Android 从 PackageManager 读取）；其他平台返回 `—`。
  Future<String> currentVersion() async {
    if (!Platform.isAndroid) return '—';
    try {
      final version = await _channel.invokeMethod<String>('versionName');
      return version?.isNotEmpty == true ? version! : '—';
    } on PlatformException {
      return '—';
    } on MissingPluginException {
      return '—';
    }
  }

  /// Android 8+ 需要「安装未知应用」权限；其他平台返回 false。
  Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> install(File apk) async {
    await _channel.invokeMethod<void>('installApk', {'path': apk.path});
  }

  Future<void> openInstallSettings() async {
    await _channel.invokeMethod<void>('openInstallSettings');
  }
}
