import 'package:ridema_core/ridema_core.dart';

/// Store flavor: apps are updated by the store, never by downloading an APK.
class StoreApkInstaller implements ApkInstaller {
  const StoreApkInstaller();
  @override
  Future<bool> canInstall() async => false;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<bool> install(String path) async => false;
}
