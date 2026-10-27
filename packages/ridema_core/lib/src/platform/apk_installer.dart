import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Installs a downloaded APK (sideload flavor force-update).
///
/// The Android side is implemented in each app on the MethodChannel
/// `ma.ridema/apk_installer`:
///
/// | method | arguments | returns |
/// |---|---|---|
/// | `canInstall` | – | `bool` — `PackageManager.canRequestPackageInstalls()` (true below Android 8) |
/// | `openInstallSettings` | – | `null` — opens `ACTION_MANAGE_UNKNOWN_APP_SOURCES` for this package |
/// | `install` | `{path: String}` | `bool` — starts `ACTION_VIEW` / `ACTION_INSTALL_PACKAGE` with a FileProvider URI |
///
/// The app manifest needs `REQUEST_INSTALL_PACKAGES` (sideload flavor only)
/// and a FileProvider covering `getApplicationCacheDirectory()/updates/`.
abstract class ApkInstaller {
  Future<bool> canInstall();
  Future<void> openInstallSettings();

  /// Opens the system installer for the APK at [path]. Returns false when not possible.
  Future<bool> install(String path);
}

class MethodChannelApkInstaller implements ApkInstaller {
  const MethodChannelApkInstaller([this.channel = const MethodChannel('ma.ridema/apk_installer')]);

  final MethodChannel channel;

  @override
  Future<bool> canInstall() async {
    try {
      return await channel.invokeMethod<bool>('canInstall') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<void> openInstallSettings() async {
    try {
      await channel.invokeMethod<void>('openInstallSettings');
    } on MissingPluginException {
      // Not implemented by the host app.
    } on PlatformException {
      // Ignore.
    }
  }

  @override
  Future<bool> install(String path) async {
    try {
      return await channel.invokeMethod<bool>('install', {'path': path}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Downloads the update APK to the app cache (`updates/`), reporting progress 0..1.
class ApkDownloader {
  ApkDownloader({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  Future<String> download(String url, {void Function(double progress)? onProgress, CancelToken? cancel}) async {
    final dir = Directory('${(await getApplicationCacheDirectory()).path}/updates');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final f in dir.listSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    final name = Uri.parse(url).pathSegments.isNotEmpty ? Uri.parse(url).pathSegments.last : 'update.apk';
    final path = '${dir.path}/${name.endsWith('.apk') ? name : 'update.apk'}';
    await _dio.download(
      url,
      path,
      cancelToken: cancel,
      onReceiveProgress: (got, total) {
        if (total > 0) onProgress?.call(got / total);
      },
    );
    return path;
  }
}
