import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../brand.dart';
import '../../api/api_exception.dart';
import '../../auth/auth_controller.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../../models/app_models.dart';
import '../widgets/common.dart';
import 'legal_screens.dart';

/// Step 1 of signup: name, email, password (≥ 10), confirm.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConsentsScreen(fullName: _name.text.trim(), email: _email.text.trim(), password: _password.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FormPage(
      title: l.signUpTitle,
      bottom: PrimaryButton(key: const ValueKey('signup_next'), label: l.next, onPressed: _next),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('signup_name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: l.fullNameLabel),
                  validator: (v) => (v ?? '').trim().length < 2 ? l.errorNameShort : null,
                ),
                gap16,
                TextFormField(
                  key: const ValueKey('signup_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l.emailLabel),
                  validator: (v) => looksLikeEmail(v ?? '') ? null : l.errorEmailInvalid,
                ),
                gap16,
                PasswordField(
                  fieldKey: const ValueKey('signup_password'),
                  controller: _password,
                  label: l.passwordLabel,
                  helperText: l.passwordHint,
                  validator: (v) => (v ?? '').length < 10 ? l.errorPasswordShort : null,
                ),
                gap16,
                PasswordField(
                  fieldKey: const ValueKey('signup_confirm'),
                  controller: _confirm,
                  label: l.confirmPasswordLabel,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _next(),
                  validator: (v) => v != _password.text ? l.errorPasswordMismatch : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 2 of signup: three separate consents (+ background location in the
/// driver app), each with "Read" → full text. Sends the versions shown.
class ConsentsScreen extends StatefulWidget {
  const ConsentsScreen({super.key, required this.fullName, required this.email, required this.password});

  final String fullName;
  final String email;
  final String password;

  @override
  State<ConsentsScreen> createState() => _ConsentsScreenState();
}

class _ConsentsScreenState extends State<ConsentsScreen> {
  Map<String, LegalDoc>? _docs;
  final Map<String, bool> _ticked = {};
  Object? _loadError;
  String? _error;
  String? _locale;

  List<String> get _kinds => [
        LegalKind.terms,
        LegalKind.privacy,
        LegalKind.dataTransfer,
        if (CoreServices.of(context).config.isDriver) LegalKind.backgroundLocation,
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = Localizations.localeOf(context).languageCode;
    if (code != _locale) {
      _locale = code;
      _load();
    }
  }

  Future<void> _load() async {
    final s = CoreServices.of(context);
    setState(() {
      _loadError = null;
    });
    try {
      final list = await s.api.legal(_locale ?? 'fr');
      if (!mounted) return;
      setState(() => _docs = {for (final d in list) d.kind: d});
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  String _label(AppLocalizations l, String kind) => switch (kind) {
        LegalKind.terms => l.consentTerms,
        LegalKind.privacy => l.consentPrivacy,
        LegalKind.dataTransfer => l.consentDataTransfer,
        _ => l.consentBackgroundLocation(kAppName),
      };

  String? _explain(AppLocalizations l, String kind) => switch (kind) {
        LegalKind.dataTransfer => l.consentDataTransferExplain,
        LegalKind.backgroundLocation => l.consentBackgroundExplain,
        _ => null,
      };

  bool get _allTicked => _kinds.every((k) => _ticked[k] == true);

  Future<void> _submit() async {
    final docs = _docs;
    if (docs == null || !_allTicked) return;
    final s = CoreServices.of(context);
    final l = context.l10n;
    setState(() => _error = null);
    try {
      await s.auth.signUp(
        fullName: widget.fullName,
        email: widget.email,
        password: widget.password,
        consents: {for (final k in _kinds) k: docs[k]?.version ?? ''},
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: widget.email)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'CONSENT_OUTDATED') {
        final kind = e.detail('kind')?.toString();
        if (kind != null) _ticked[kind] = false;
        setState(() => _error = l.consentsOutdated);
        await _load();
        return;
      }
      setState(() => _error = errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    final docs = _docs;
    return FormPage(
      title: l.consentsTitle,
      bottom: PrimaryButton(
        key: const ValueKey('consents_accept'),
        label: l.consentsAccept,
        busy: busy,
        onPressed: docs != null && _allTicked ? _submit : null,
      ),
      children: [
        Text(l.consentsIntro, style: const TextStyle(fontSize: 16)),
        gap16,
        if (_loadError != null) ...[
          ErrorBanner(l.consentsLoadFailed),
          gap8,
          SecondaryButton(label: l.retry, onPressed: _load),
        ] else if (docs == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          for (final kind in _kinds) _consentTile(l, kind, docs[kind]),
        gap8,
        Text(l.consentsAllRequired, style: TextStyle(color: Colors.grey.shade700)),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }

  Widget _consentTile(AppLocalizations l, String kind, LegalDoc? doc) {
    final explain = _explain(l, kind);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              key: ValueKey('consent_$kind'),
              value: _ticked[kind] ?? false,
              onChanged: doc == null ? null : (v) => setState(() => _ticked[kind] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(_label(l, kind), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: explain == null ? null : Padding(padding: const EdgeInsets.only(top: 6), child: Text(explain)),
            ),
            Row(
              children: [
                const SizedBox(width: 16),
                if (doc != null)
                  Text(l.consentVersion(doc.version), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                TextButton.icon(
                  key: ValueKey('consent_read_$kind'),
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l.read),
                  onPressed: doc == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalDocScreen(doc: doc))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Enter the 6-digit email code; resend after 60 s.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.resendDelay = const Duration(seconds: 60)});
  final String email;
  final Duration resendDelay;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  Timer? _timer;
  late int _left;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _left = widget.resendDelay.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _afterVerified(LoginStep? step) async {
    if (!mounted) return;
    showInfoSnack(context, context.l10n.emailVerified);
    if (step == LoginStep.twoFactorRequired) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TwoFactorScreen()));
    } else if (step == null) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(email: widget.email)));
    }
    // LoginStep.signedIn: the root gate shows the home screen.
  }

  Future<void> _verify() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      final step = await auth.verifyEmail(_code.text, email: widget.email);
      await _afterVerified(step);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  Future<void> _usedLink() async {
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      await _afterVerified(await auth.continueAfterEmailLink());
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  Future<void> _resend() async {
    final auth = CoreServices.of(context).auth;
    try {
      await auth.resendEmailCode(email: widget.email);
      if (!mounted) return;
      showInfoSnack(context, context.l10n.codeSent);
      setState(_startTimer);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    return FormPage(
      title: l.verifyEmailTitle,
      bottom: PrimaryButton(key: const ValueKey('verify_email_submit'), label: l.verifyButton, busy: busy, onPressed: _verify),
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 64, color: BrandColors.primary),
        gap16,
        Text(l.verifyEmailBody(widget.email), style: const TextStyle(fontSize: 17)),
        gap8,
        Text(l.verifyEmailSpam, style: TextStyle(color: Colors.grey.shade700)),
        gap24,
        Form(key: _form, child: CodeField(fieldKey: const ValueKey('verify_email_code'), controller: _code, onCompleted: (_) => _verify())),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
        gap16,
        TextButton(
          key: const ValueKey('verify_email_resend'),
          onPressed: _left > 0 || busy ? null : _resend,
          child: Text(_left > 0 ? l.resendIn(_left) : l.resendCode),
        ),
        TextButton(onPressed: busy ? null : _usedLink, child: Text(l.iVerifiedWithLink)),
      ],
    );
  }
}

/// Email + password. Continues to 2FA or email verification when needed.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.email});
  final String? email;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email ?? '');
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final s = CoreServices.of(context);
    final l = context.l10n;
    setState(() => _error = null);
    try {
      final step = await s.auth.login(_email.text, _password.text);
      if (!mounted) return;
      if (step == LoginStep.twoFactorRequired) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TwoFactorScreen()));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: _email.text.trim())));
        return;
      }
      if (e.code == 'WRONG_ROLE') {
        setState(() => _error = s.config.isDriver ? l.wrongAppDriver : l.wrongAppRider(kAppName));
        return;
      }
      setState(() => _error = errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    return FormPage(
      title: l.loginTitle,
      bottom: PrimaryButton(key: const ValueKey('login_submit'), label: l.loginButton, busy: busy, onPressed: _login),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('login_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: l.emailLabel),
                  validator: (v) => looksLikeEmail(v ?? '') ? null : l.errorEmailInvalid,
                ),
                gap16,
                PasswordField(
                  fieldKey: const ValueKey('login_password'),
                  controller: _password,
                  label: l.passwordLabel,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  validator: (v) => (v ?? '').isEmpty ? l.required : null,
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
        gap8,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('login_forgot'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: _email.text.trim())),
            ),
            child: Text(l.forgotPasswordLink),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignUpScreen())),
            child: Text(l.noAccountLink),
          ),
        ),
      ],
    );
  }
}

/// Second login step (email code or authenticator app).
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      await auth.submitTwoFactor(_code.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(context.l10n, e));
      if (!auth.awaitingTwoFactor) {
        // Step expired: back to the password.
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthController>();
    final totp = auth.mfaMethod?.name == 'totp';
    return FormPage(
      title: l.twoFactorTitle,
      bottom: PrimaryButton(key: const ValueKey('twofa_submit'), label: l.verifyButton, busy: auth.busy, onPressed: _submit),
      children: [
        Icon(totp ? Icons.phonelink_lock : Icons.mark_email_read_outlined, size: 64, color: BrandColors.primary),
        gap16,
        Text(totp ? l.twoFactorTotpBody(kAppName) : l.twoFactorEmailBody, style: const TextStyle(fontSize: 17)),
        gap24,
        Form(key: _form, child: CodeField(fieldKey: const ValueKey('twofa_code'), controller: _code, onCompleted: (_) => _submit())),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}

/// Ask for a reset code by email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});
  final String? email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email ?? '');
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      await auth.forgotPassword(_email.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: _email.text.trim())));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    return FormPage(
      title: l.forgotTitle,
      bottom: PrimaryButton(label: l.forgotSend, busy: busy, onPressed: _send),
      children: [
        Text(l.forgotBody, style: const TextStyle(fontSize: 17)),
        gap16,
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: InputDecoration(labelText: l.emailLabel),
            validator: (v) => looksLikeEmail(v ?? '') ? null : l.errorEmailInvalid,
          ),
        ),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}

/// Code from the email + new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reset() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      await auth.resetPassword(code: _code.text, newPassword: _password.text, email: widget.email);
      if (!mounted) return;
      showInfoSnack(context, context.l10n.resetDone);
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(email: widget.email)));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    return FormPage(
      title: l.resetTitle,
      bottom: PrimaryButton(label: l.resetButton, busy: busy, onPressed: _reset),
      children: [
        Text(l.resetBody(widget.email), style: const TextStyle(fontSize: 17)),
        gap16,
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CodeField(controller: _code),
              gap16,
              PasswordField(
                controller: _password,
                label: l.newPasswordLabel,
                helperText: l.passwordHint,
                validator: (v) => (v ?? '').length < 10 ? l.errorPasswordShort : null,
              ),
              gap16,
              PasswordField(
                controller: _confirm,
                label: l.confirmPasswordLabel,
                textInputAction: TextInputAction.done,
                validator: (v) => v != _password.text ? l.errorPasswordMismatch : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}
