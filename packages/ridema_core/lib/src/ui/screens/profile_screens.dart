import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../brand.dart';
import '../../api/api_exception.dart';
import '../../auth/auth_controller.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../../models/user.dart';
import '../widgets/common.dart';
import 'boot_screens.dart';
import 'legal_screens.dart';
import 'phone_screen.dart';
import 'trips_screens.dart';

/// Profile (SPEC §3.1.12). [extraTiles] lets each app add its own entries
/// (driver: documents, battery guide, subscription, earnings).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.extraTiles = const [], this.showTrips = true});

  final List<Widget> extraTiles;
  final bool showTrips;

  Future<void> _editName(BuildContext context, Me me) async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: me.fullName);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.editName),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.length < 2 || !context.mounted) return;
    try {
      await CoreServices.of(context).auth.updateProfile(fullName: name);
      if (context.mounted) showInfoSnack(context, l.saved);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = CoreServices.of(context);
    final auth = context.watch<AuthController>();
    final me = auth.me;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final langName = switch (s.locale.languageCode) {
      'ar' => l.languageArabic,
      'en' => l.languageEnglish,
      _ => l.languageFrench,
    };
    final method = switch (me?.twofaMethod) {
      TwoFactorMethod.email => l.twoFactorEmail,
      TwoFactorMethod.totp => l.twoFactorTotp,
      _ => l.twoFactorOff,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: SafeArea(
        child: me == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SecondaryButton(label: l.retry, onPressed: () => auth.refreshMe().catchError((_) => null)),
                ),
              )
            : ListView(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: BrandColors.primary,
                      child: Text(me.firstName.isEmpty ? '?' : me.firstName.characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 22)),
                    ),
                    title: Text(me.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    subtitle: me.rating == null ? null : Text('${l.profileRating}: ${me.rating!.toStringAsFixed(1)} ★'),
                    trailing: IconButton(tooltip: l.editName, icon: const Icon(Icons.edit), onPressed: () => _editName(context, me)),
                  ),
                  const Divider(),
                  ListTile(leading: const Icon(Icons.email_outlined), title: Text(l.profileEmail), subtitle: Text(me.email)),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(l.profilePhone),
                    subtitle: Text(me.phone ?? l.phoneNotVerified, textDirection: TextDirection.ltr),
                    trailing: me.phoneVerified
                        ? Chip(
                            avatar: const Icon(Icons.verified, color: BrandColors.success, size: 18),
                            label: Text(l.phoneVerifiedBadge),
                          )
                        : TextButton(onPressed: () => push(const VerifyPhoneScreen()), child: Text(l.verifyNow)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(l.languageLabel),
                    subtitle: Text(langName),
                    onTap: () => showLanguageSheet(context),
                  ),
                  if (showTrips)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(l.profileTrips),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => push(const TripHistoryScreen()),
                    ),
                  ...extraTiles,
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: Text(l.profileSecurity),
                    subtitle: Text(method),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => push(const TwoFactorSettingsScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: Text(l.profileChangePassword),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => push(const ChangePasswordScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_shared_outlined),
                    title: Text(l.profileMyData),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => push(const MyDataScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(l.profileLegal),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => push(const LegalInfoScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: BrandColors.danger),
                    title: Text(l.profileDeleteAccount, style: const TextStyle(color: BrandColors.danger)),
                    onTap: () => push(const DeleteAccountScreen()),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(l.logout),
                    onTap: () async {
                      if (await confirmDialog(context, message: l.logoutConfirm, confirmLabel: l.logout)) {
                        await s.auth.logout();
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.profileAppVersion(s.config.version),
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Two-step login: off / email code / authenticator app (otpauth secret shown & copyable).
class TwoFactorSettingsScreen extends StatefulWidget {
  const TwoFactorSettingsScreen({super.key});

  @override
  State<TwoFactorSettingsScreen> createState() => _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState extends State<TwoFactorSettingsScreen> {
  TotpSetup? _setup;
  final _code = TextEditingController();
  final _codeForm = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<String?> _askPassword() async {
    final l = context.l10n;
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.passwordConfirmPrompt),
        content: TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: l.passwordLabel)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(l.confirm)),
        ],
      ),
    );
    ctrl.dispose();
    return (pw == null || pw.isEmpty) ? null : pw;
  }

  Future<void> _guard(Future<void> Function() f, String? success) async {
    setState(() => _error = null);
    try {
      await f();
      if (mounted && success != null) showInfoSnack(context, success);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthController>();
    final s = CoreServices.of(context);
    final method = auth.me?.twofaMethod ?? TwoFactorMethod.none;
    final current = switch (method) {
      TwoFactorMethod.email => l.twoFactorEmail,
      TwoFactorMethod.totp => l.twoFactorTotp,
      TwoFactorMethod.none => l.twoFactorOff,
    };
    final setup = _setup;
    return FormPage(
      title: l.twoFactorSettingsTitle,
      children: [
        Text(l.twoFactorExplain, style: const TextStyle(fontSize: 16)),
        gap16,
        InfoBox(l.twoFactorCurrent(current), icon: method == TwoFactorMethod.none ? Icons.lock_open : Icons.lock),
        gap24,
        if (setup == null) ...[
          if (method != TwoFactorMethod.email)
            SecondaryButton(
              label: l.twoFactorUseEmail,
              icon: Icons.email_outlined,
              onPressed: auth.busy
                  ? null
                  : () async {
                      final pw = await _askPassword();
                      if (pw != null) await _guard(() => auth.enableEmailTwoFactor(pw), l.twoFactorEnabled);
                    },
            ),
          gap16,
          if (method != TwoFactorMethod.totp)
            SecondaryButton(
              label: l.twoFactorUseTotp,
              icon: Icons.phonelink_lock,
              onPressed: auth.busy
                  ? null
                  : () => _guard(() async {
                        final st = await auth.startTotpSetup();
                        if (mounted) setState(() => _setup = st);
                      }, null),
            ),
          gap16,
          if (method != TwoFactorMethod.none)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
              onPressed: auth.busy
                  ? null
                  : () async {
                      final pw = await _askPassword();
                      if (pw != null) await _guard(() => auth.disableTwoFactor(pw), l.twoFactorDisabled);
                    },
              child: Text(l.twoFactorTurnOff),
            ),
        ] else ...[
          Text(l.twoFactorTotpStep1, style: const TextStyle(fontSize: 16)),
          gap8,
          Card(
            child: ListTile(
              title: Text(l.twoFactorSecret),
              subtitle: SelectableText(setup.secret,
                  textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 18, fontFamily: 'monospace', letterSpacing: 1.5)),
              trailing: IconButton(
                tooltip: l.copy,
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: setup.secret));
                  if (context.mounted) showInfoSnack(context, l.copied);
                },
              ),
            ),
          ),
          gap8,
          SecondaryButton(
            label: l.twoFactorOpenApp,
            icon: Icons.open_in_new,
            onPressed: () => s.launcher.openUrl(Uri.parse(setup.otpauthUrl)),
          ),
          gap24,
          Text(l.twoFactorTotpStep2, style: const TextStyle(fontSize: 16)),
          gap8,
          Form(key: _codeForm, child: CodeField(controller: _code)),
          gap16,
          PrimaryButton(
            label: l.confirm,
            busy: auth.busy,
            onPressed: () async {
              if (!(_codeForm.currentState?.validate() ?? false)) return;
              await _guard(() async {
                await auth.enableTotp(_code.text);
                if (mounted) setState(() => _setup = null);
              }, l.twoFactorEnabled);
            },
          ),
          TextButton(onPressed: () => setState(() => _setup = null), child: Text(l.cancel)),
        ],
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthController>();
    return FormPage(
      title: l.changePasswordTitle,
      bottom: PrimaryButton(
        label: l.save,
        busy: auth.busy,
        onPressed: () async {
          if (!(_form.currentState?.validate() ?? false)) return;
          setState(() => _error = null);
          try {
            await auth.changePassword(_current.text, _next.text);
            if (!context.mounted) return;
            showInfoSnack(context, l.passwordChanged);
            Navigator.of(context).pop();
          } catch (e) {
            if (mounted) setState(() => _error = errorText(l, e));
          }
        },
      ),
      children: [
        Form(
          key: _form,
          child: Column(children: [
            PasswordField(controller: _current, label: l.currentPasswordLabel, validator: (v) => (v ?? '').isEmpty ? l.required : null),
            gap16,
            PasswordField(
              controller: _next,
              label: l.newPasswordLabel,
              helperText: l.passwordHint,
              validator: (v) => (v ?? '').length < 10 ? l.errorPasswordShort : null,
            ),
            gap16,
            PasswordField(
              controller: _confirm,
              label: l.confirmPasswordLabel,
              textInputAction: TextInputAction.done,
              validator: (v) => v != _next.text ? l.errorPasswordMismatch : null,
            ),
          ]),
        ),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}

/// Download my data (JSON, saved then shared) + data requests (law 09-08).
class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key, this.shareFile});

  /// Shares the exported file; defaults to the system share sheet. Injected in tests.
  final Future<void> Function(String path)? shareFile;

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  Future<List<DataRequest>>? _requests;
  bool _exporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requests ??= CoreServices.of(context).api.dataRequests();
  }

  void _reload() => setState(() => _requests = CoreServices.of(context).api.dataRequests());

  Future<void> _export() async {
    final s = CoreServices.of(context);
    final l = context.l10n;
    setState(() => _exporting = true);
    try {
      final data = await s.api.dataExport();
      final dir = await getTemporaryDirectory();
      final name = '${kAppName.toLowerCase()}-my-data.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      if (!mounted) return;
      showInfoSnack(context, l.myDataReady);
      final share = widget.shareFile ??
          (p) => SharePlus.instance.share(ShareParams(files: [XFile(p, mimeType: 'application/json')], subject: name));
      await share(file.path);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _newRequest() async {
    final l = context.l10n;
    final s = CoreServices.of(context);
    var kind = 'correction';
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.newDataRequest),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<String>(
                  groupValue: kind,
                  onChanged: (v) => set(() => kind = v ?? kind),
                  child: Column(children: [
                    RadioListTile<String>(value: 'correction', title: Text(l.dataRequestCorrection)),
                    RadioListTile<String>(value: 'access', title: Text(l.dataRequestAccess)),
                  ]),
                ),
                TextField(
                  controller: details,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l.dataRequestDetails, hintText: l.dataRequestDetailsHint),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.send)),
          ],
        ),
      ),
    );
    final text = details.text.trim();
    details.dispose();
    if (ok != true || text.length < 3 || !mounted) return;
    try {
      await s.api.createDataRequest(kind, text);
      if (!mounted) return;
      showInfoSnack(context, l.dataRequestSent);
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  String _kind(AppLocalizations l, String k) => switch (k) {
        'access' => l.dataRequestAccess,
        'deletion' => l.dataRequestDeletion,
        _ => l.dataRequestCorrection,
      };

  String _status(AppLocalizations l, String st) => switch (st) {
        'done' => l.dataRequestDone,
        'rejected' => l.dataRequestRejected,
        _ => l.dataRequestOpen,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.myDataTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.add),
        label: Text(l.newDataRequest),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(l.myDataIntro, style: const TextStyle(fontSize: 16)),
              gap16,
              PrimaryButton(label: l.downloadMyData, icon: Icons.download, busy: _exporting, onPressed: _export),
              gap24,
              Text(l.dataRequestsTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              gap8,
              FutureBuilder<List<DataRequest>>(
                future: _requests,
                builder: (context, snap) {
                  if (snap.hasError) return ErrorBanner(errorText(l, snap.error!));
                  if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  final items = snap.data!;
                  if (items.isEmpty) return Text(l.dataRequestsEmpty);
                  return Column(children: [
                    for (final r in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(_kind(l, r.kind)),
                          subtitle: Text([
                            formatDateTime(locale, r.createdAt),
                            if (r.details != null) r.details!,
                            if (r.response != null) l.dataRequestResponse(r.response!),
                          ].join('\n')),
                          trailing: Text(_status(l, r.status)),
                          isThreeLine: true,
                        ),
                      ),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delete my account (D21): explains what is deleted, password confirm, handles ACTIVE_RIDE.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _understood = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      await auth.deleteAccount(_password.text);
      // The root gate now shows Welcome and removes this route.
      messenger?.showSnackBar(SnackBar(content: Text(l.deleteDone)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    return FormPage(
      title: l.deleteTitle,
      bottom: PrimaryButton(
        key: const ValueKey('delete_confirm'),
        label: l.deleteButton,
        color: BrandColors.danger,
        busy: busy,
        onPressed: _understood && _password.text.isNotEmpty ? _delete : null,
      ),
      children: [
        ErrorBanner(l.deleteIntro),
        gap16,
        InfoBox(l.deleteWhatGoes, icon: Icons.delete_outline, color: BrandColors.danger),
        gap8,
        InfoBox(l.deleteWhatStays, icon: Icons.receipt_long_outlined),
        gap24,
        PasswordField(controller: _password, label: l.passwordLabel, textInputAction: TextInputAction.done, onSubmitted: (_) => setState(() {})),
        gap8,
        CheckboxListTile(
          value: _understood,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() => _understood = v ?? false),
          title: Text(l.deleteConfirmCheck),
        ),
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}
