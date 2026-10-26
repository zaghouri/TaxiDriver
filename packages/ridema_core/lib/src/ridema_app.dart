import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../brand.dart';
import 'auth/auth_controller.dart';
import 'config/app_config.dart';
import 'core_services.dart';
import 'l10n/l10n.dart';
import 'l10n/locale_controller.dart';
import 'theme.dart';
import 'ui/screens/boot_screens.dart';

/// Builds [CoreServices] for an app (default: [CoreServices.create]).
typedef CoreServicesFactory = Future<CoreServices> Function(AppConfig config);

/// Root widget of both apps.
///
/// Boot sequence (SPEC §3.1): splash → services (Firebase optional, remote
/// config `api_base_url`) → `GET /v1/app/config` (+ restore session) →
/// force-update screen if needed → language picker on first launch →
/// Welcome (signed out) or [homeBuilder] (signed in).
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(RideMaApp(app: AppKind.rider, homeBuilder: (_) => const RiderHome()));
/// }
/// ```
class RideMaApp extends StatefulWidget {
  const RideMaApp({
    super.key,
    required this.app,
    required this.homeBuilder,
    this.config,
    this.servicesFactory,
    this.services,
    this.providers,
    this.theme,
    this.navigatorKey,
    this.onReady,
  });

  /// rider or driver.
  final AppKind app;

  /// Signed-in home of the app (map, requests, ...).
  final WidgetBuilder homeBuilder;

  /// Defaults to [AppConfig.load] (version from the platform, FLAVOR dart-define).
  final AppConfig? config;

  /// Override how services are built (e.g. to pass a custom [ApkInstaller]).
  final CoreServicesFactory? servicesFactory;

  /// Ready-made services (tests). Skips [servicesFactory].
  final CoreServices? services;

  /// Extra app-level providers, created once services exist.
  final List<SingleChildWidget> Function(CoreServices services)? providers;
  final ThemeData? theme;
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Called once after boot (config loaded, session restored).
  final void Function(CoreServices services)? onReady;

  @override
  State<RideMaApp> createState() => _RideMaAppState();
}

class _RideMaAppState extends State<RideMaApp> {
  CoreServices? _services;
  Object? _bootError;
  late final GlobalKey<NavigatorState> _navKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      final s = widget.services ??
          await (widget.servicesFactory ?? ((c) => CoreServices.create(config: c)))(
            widget.config ?? await AppConfig.load(app: widget.app),
          );
      if (!mounted) return;
      setState(() => _services = s);
      await s.start();
      widget.onReady?.call(s);
    } catch (e) {
      if (mounted) setState(() => _bootError = e);
    }
  }

  @override
  void dispose() {
    if (widget.services == null) _services?.dispose();
    super.dispose();
  }

  MaterialApp _material({required Locale? locale, required Widget home}) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: widget.theme ?? buildRideMaTheme(),
        navigatorKey: _navKey,
        scaffoldMessengerKey: _messengerKey,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (device, supported) =>
            Locale(LocaleController.defaultFor(device?.languageCode ?? 'fr')),
        home: home,
      );

  @override
  Widget build(BuildContext context) {
    final s = _services;
    if (s == null) {
      return _material(
        locale: null,
        home: _bootError == null
            ? const SplashScreen()
            : Builder(builder: (c) => SplashScreen(message: errorText(c.l10n, _bootError!))),
      );
    }
    return MultiProvider(
      providers: [
        Provider<CoreServices>.value(value: s),
        ChangeNotifierProvider<AuthController>.value(value: s.auth),
        ChangeNotifierProvider<LocaleController>.value(value: s.locale),
        ChangeNotifierProvider<BootController>.value(value: s.boot),
        ...?widget.providers?.call(s),
      ],
      child: Consumer<LocaleController>(
        builder: (context, locale, _) => _material(
          locale: locale.locale,
          home: _RootGate(navigatorKey: _navKey, messengerKey: _messengerKey, homeBuilder: widget.homeBuilder),
        ),
      ),
    );
  }
}

/// Chooses the root screen from boot / locale / auth state and clears the
/// navigation stack whenever the session starts or ends.
class _RootGate extends StatefulWidget {
  const _RootGate({required this.navigatorKey, required this.messengerKey, required this.homeBuilder});

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final WidgetBuilder homeBuilder;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  AuthStatus? _lastStatus;
  bool _lastForce = false;

  void _popToRoot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final boot = context.watch<BootController>();
    final locale = context.watch<LocaleController>();
    final auth = context.watch<AuthController>();
    final l = context.l10n;

    if (_lastStatus != null && _lastStatus != auth.status) {
      _popToRoot();
      if (auth.status == AuthStatus.signedOut && auth.lastEndReason != null && auth.lastEndReason != 'ACCOUNT_DELETED') {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.messengerKey.currentState?.showSnackBar(SnackBar(content: Text(l.sessionEnded))),
        );
      }
    }
    _lastStatus = auth.status;
    if (boot.forceUpdate && !_lastForce) _popToRoot();
    _lastForce = boot.forceUpdate;

    if (boot.forceUpdate) return const ForceUpdateScreen();
    if (!boot.loaded) return const SplashScreen();
    if (!locale.hasChosen) return const LanguagePickerScreen();
    return switch (auth.status) {
      AuthStatus.unknown => const SplashScreen(),
      AuthStatus.signedOut => const WelcomeScreen(),
      AuthStatus.signedIn => Builder(builder: widget.homeBuilder),
    };
  }
}
