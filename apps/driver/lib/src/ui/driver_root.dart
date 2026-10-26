import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../controller/driver_controller.dart';
import '../controller/profile_controller.dart';
import '../l10n/driver_strings.dart';
import 'documents_screen.dart';
import 'home/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Signed-in root: phone verification → onboarding / under review / home by
/// driver status. Starts the DriverController (active ride restore + socket
/// listeners) as soon as the driver is signed in.
class DriverRoot extends StatefulWidget {
  const DriverRoot({super.key});

  @override
  State<DriverRoot> createState() => _DriverRootState();
}

class _DriverRootState extends State<DriverRoot> {
  DriverController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<DriverController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_controller!.start());
      unawaited(context.read<DriverProfileController>().load());
    });
  }

  @override
  void dispose() {
    // Signed out: stop location and forget this driver's state.
    unawaited(_controller?.reset());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthController>();
    final pc = context.watch<DriverProfileController>();
    final me = auth.me;

    if (me == null) {
      return _Waiting(onRetry: () => auth.refreshMe().catchError((_) => null));
    }
    if (!me.phoneVerified) return const _PhoneGate();

    final p = pc.profile;
    if (p == null) {
      if (pc.error != null) return _Waiting(error: errorText(l, pc.error!), onRetry: pc.load);
      return const _Waiting();
    }
    return switch (p.status) {
      DriverStatus.draft || DriverStatus.rejected => const OnboardingScreen(),
      DriverStatus.pending => const UnderReviewScreen(),
      DriverStatus.suspended => const SuspendedScreen(),
      DriverStatus.approved => HomeScreen(restoreOnline: p.online),
    };
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandLogo(size: 72),
                gap24,
                if (error == null) const CircularProgressIndicator() else ErrorBanner(error!),
                if (onRetry != null && error != null) ...[gap16, SecondaryButton(label: context.l10n.retry, onPressed: onRetry)],
              ]),
            ),
          ),
        ),
      );
}

/// "We need a verified number before you go online" (SPEC §3.1.9).
class _PhoneGate extends StatelessWidget {
  const _PhoneGate();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FormPage(
      title: l.verifyPhoneTitle,
      bottom: PrimaryButton(
        key: const ValueKey('verify_phone_button'),
        label: l.verifyNow,
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const VerifyPhoneScreen()));
          if (ok == true && context.mounted) await context.read<AuthController>().refreshMe().catchError((_) => null);
        },
      ),
      children: [
        const Icon(Icons.phone_iphone, size: 72, color: BrandColors.primary),
        gap16,
        Text(l.verifyPhoneWhyDriver, style: const TextStyle(fontSize: 18)),
        gap8,
        Text(l.phonePrivacy),
      ],
    );
  }
}

/// Application submitted: waiting for the admin review.
class UnderReviewScreen extends StatelessWidget {
  const UnderReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pc = context.watch<DriverProfileController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.underReviewTitle),
        actions: [
          IconButton(
            tooltip: l.profileTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen(showTrips: false))),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: pc.load,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.hourglass_top, size: 80, color: BrandColors.accent),
          gap16,
          Text(l.underReviewTitle, key: const ValueKey('under_review'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          gap8,
          Text(l.underReviewBody, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          gap16,
          SecondaryButton(label: context.ds.refresh, icon: Icons.refresh, onPressed: pc.load),
          if (pc.profile != null) DocumentList(profile: pc.profile!, onChanged: pc.load),
        ]),
      ),
    );
  }
}

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pc = context.watch<DriverProfileController>();
    final support = context.watch<BootController>().appConfigOrDefault.company.supportPhone;
    final reason = pc.profile?.statusReason;
    return FormPage(
      title: l.suspendedTitle,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (support != null && support.isNotEmpty)
          PrimaryButton(
            label: '${context.ds.supportLabel} $support',
            icon: Icons.call,
            onPressed: () => CoreServices.of(context).launcher.dial(support),
          ),
        gap8,
        SecondaryButton(
          label: l.profileTitle,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
        ),
      ]),
      children: [
        const Icon(Icons.pause_circle_outline, size: 80, color: BrandColors.danger),
        gap16,
        Text(l.suspendedBody, style: const TextStyle(fontSize: 17)),
        if (reason != null && reason.isNotEmpty) ...[gap8, ErrorBanner(reason)],
        gap16,
        SecondaryButton(label: context.ds.refresh, icon: Icons.refresh, onPressed: pc.load),
      ],
    );
  }
}
