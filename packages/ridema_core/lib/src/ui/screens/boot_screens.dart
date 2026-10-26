import 'dart:async';

import 'package:flutter/material.dart';

import '../../../brand.dart';
import '../../config/app_config.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../../platform/apk_installer.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';

/// Logo + spinner while the app starts.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 96),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              if (message != null) ...[gap16, Text(message!, textAlign: TextAlign.center)],
            ],
          ),
        ),
      );
}

/// Blocks the app until it is updated (SPEC §3.1.1).
///
/// Sideload flavor: downloads `apk_url` and opens the installer through
/// [ApkInstaller]. Store flavor: opens `store_url`.
class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({super.key, this.downloader});

  /// Injected in tests.
  final ApkDownloader? downloader;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  double? _progress;
  String? _apkPath;
  String? _error;
  bool _needsPermission = false;

  Future<void> _download(CoreServices s) async {
    final url = s.boot.appConfig?.apkUrl;
    if (url == null) return;
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final path = await (widget.downloader ?? ApkDownloader()).download(url, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _apkPath = path;
        _progress = null;
      });
      await _install(s);
    } catch (_) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = context.l10n.updateFailed;
        });
      }
    }
  }

  Future<void> _install(CoreServices s) async {
    final path = _apkPath;
    if (path == null) return;
    if (!await s.apkInstaller.canInstall()) {
      setState(() => _needsPermission = true);
      await s.apkInstaller.openInstallSettings();
      return;
    }
    setState(() => _needsPermission = false);
    final ok = await s.apkInstaller.install(path);
    if (!ok && mounted) setState(() => _error = context.l10n.updateFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = CoreServices.of(context);
    final cfg = s.boot.appConfig;
    final version = (cfg?.latestVersion.isNotEmpty ?? false) && cfg!.latestVersion != '0.0.0'
        ? cfg.latestVersion
        : (s.boot.forceUpdateMinVersion ?? '');
    final store = s.config.isStore;
    final storeUrl = cfg?.storeUrl;
    final apkUrl = cfg?.apkUrl;

    Widget action;
    if (store) {
      action = storeUrl == null
          ? InfoBox(l.updateNoLink)
          : PrimaryButton(
              label: l.updateOpenStore,
              icon: Icons.shop,
              onPressed: () => s.launcher.openUrl(Uri.parse(storeUrl)),
            );
    } else if (_apkPath != null) {
      action = PrimaryButton(label: l.updateInstall, icon: Icons.install_mobile, onPressed: () => _install(s));
    } else if (_progress != null) {
      action = Column(children: [
        LinearProgressIndicator(value: _progress, minHeight: 10),
        gap8,
        Text(l.updateDownloading(((_progress ?? 0) * 100).round())),
      ]);
    } else {
      action = apkUrl == null
          ? InfoBox(l.updateNoLink)
          : PrimaryButton(label: l.updateDownload, icon: Icons.download, onPressed: () => _download(s));
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: BrandLogo(size: 80)),
                gap24,
                Text(l.updateTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                gap16,
                Text(l.updateBody(kAppName, version), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                const Spacer(),
                if (_needsPermission) ...[InfoBox(l.updateAllowInstall(kAppName)), gap16],
                if (_error != null) ...[ErrorBanner(_error!), gap16],
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First-launch language choice (العربية / Français / English).
class LanguagePickerScreen extends StatelessWidget {
  const LanguagePickerScreen({super.key, this.onChosen});

  /// Called after the choice is saved (default: nothing, the root gate moves on).
  final VoidCallback? onChosen;

  @override
  Widget build(BuildContext context) {
    final s = CoreServices.of(context);
    final l = context.l10n;
    Widget option(String code, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: ValueKey('lang_$code'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 64),
                backgroundColor: s.locale.languageCode == code ? BrandColors.primary.withValues(alpha: 0.08) : null,
              ),
              onPressed: () async {
                await s.locale.setLanguage(code);
                onChosen?.call();
              },
              child: Text(label, style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: BrandLogo(size: 80)),
              gap24,
              Text(l.languageTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              gap24,
              option('ar', l.languageArabic),
              option('fr', l.languageFrench),
              option('en', l.languageEnglish),
              gap8,
              Text(l.languageChangeLater, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign up / Log in choice.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = CoreServices.of(context);
    final driver = s.config.app == AppKind.driver;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.language),
                  label: Text(l.languageLabel),
                  onPressed: () => showLanguageSheet(context),
                ),
              ),
              const Spacer(),
              const Center(child: BrandLogo(size: 110)),
              gap24,
              Text(l.welcomeTitle(kAppName), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              gap16,
              Text(
                driver ? l.welcomeDriverTagline : l.welcomeRiderTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              gap8,
              Text(l.welcomeCash, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
              const Spacer(),
              PrimaryButton(
                key: const ValueKey('welcome_signup'),
                label: l.welcomeSignUp,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
              ),
              gap16,
              SecondaryButton(
                key: const ValueKey('welcome_login'),
                label: l.welcomeLogIn,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to change the language anywhere. Also updates the server
/// profile when signed in (emails, WhatsApp template language).
Future<void> showLanguageSheet(BuildContext context) async {
  final s = CoreServices.of(context);
  final l = context.l10n;
  final code = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in {'ar': l.languageArabic, 'fr': l.languageFrench, 'en': l.languageEnglish}.entries)
            ListTile(
              title: Text(e.value, style: const TextStyle(fontSize: 20)),
              trailing: s.locale.languageCode == e.key ? const Icon(Icons.check, color: BrandColors.primary) : null,
              onTap: () => Navigator.pop(c, e.key),
            ),
          gap8,
        ],
      ),
    ),
  );
  if (code == null) return;
  await s.locale.setLanguage(code);
  if (s.auth.isSignedIn) unawaited(s.auth.updateProfile(locale: code).catchError((_) {}));
}
