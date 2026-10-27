import 'package:url_launcher/url_launcher.dart' as ul;

/// Opens dialer / browser / store links. An interface so widgets can be tested.
abstract class Launcher {
  /// Opens the phone dialer with [number] (`tel:`). Returns false if nothing could open it.
  Future<bool> dial(String number);

  /// Opens [url] in an external app (browser, store, WhatsApp, Maps).
  Future<bool> openUrl(Uri url);
}

class UrlLauncher implements Launcher {
  const UrlLauncher();

  @override
  Future<bool> dial(String number) async {
    try {
      return await ul.launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openUrl(Uri url) async {
    try {
      return await ul.launchUrl(url, mode: ul.LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
