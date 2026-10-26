import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../brand.dart';
import '../../auth/auth_controller.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../widgets/common.dart';

/// Phone verification by WhatsApp code (SPEC §3.1.9, D7).
///
/// `+212` is fixed; the user types 9 digits (a leading 0 is accepted).
/// Pops `true` once verified. Show it before the first ride (rider) or before
/// first going online (driver), and from Profile.
class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _phoneForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_phoneForm.currentState?.validate() ?? false)) return;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      final r = await auth.startPhoneVerification(_phone.text);
      if (mounted) setState(() => _sentTo = r.phone.isNotEmpty ? r.phone : auth.pendingPhone);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  Future<void> _verify() async {
    if (!(_codeForm.currentState?.validate() ?? false)) return;
    final auth = CoreServices.of(context).auth;
    setState(() => _error = null);
    try {
      await auth.verifyPhone(_code.text);
      if (!mounted) return;
      showInfoSnack(context, context.l10n.phoneVerified);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthController>();
    final driver = CoreServices.of(context).config.isDriver;
    final sent = _sentTo != null;
    return FormPage(
      title: l.verifyPhoneTitle,
      bottom: sent
          ? PrimaryButton(key: const ValueKey('phone_verify'), label: l.verifyButton, busy: auth.busy, onPressed: _verify)
          : PrimaryButton(
              key: const ValueKey('phone_send'),
              label: l.sendCodeWhatsapp,
              icon: Icons.chat,
              busy: auth.busy,
              onPressed: _send,
            ),
      children: [
        const Icon(Icons.verified_user_outlined, size: 56, color: BrandColors.primary),
        gap16,
        Text(driver ? l.verifyPhoneWhyDriver : l.verifyPhoneWhyRider, style: const TextStyle(fontSize: 17)),
        gap16,
        if (!sent) ...[
          Text(l.verifyPhoneBody, style: const TextStyle(fontSize: 16)),
          gap16,
          Form(
            key: _phoneForm,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextFormField(
                key: const ValueKey('phone_number'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(12)],
                style: const TextStyle(fontSize: 22, letterSpacing: 1.5),
                decoration: InputDecoration(
                  labelText: l.phoneLabel,
                  hintText: l.phoneHint,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('🇲🇦 +212', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                validator: (v) => AuthController.normalizeMoroccanPhone(v ?? '') == null ? l.errorPhoneInvalid : null,
              ),
            ),
          ),
          gap16,
          InfoBox(l.phoneCodesLimit),
          gap8,
          InfoBox(l.phonePrivacy, icon: Icons.lock_outline),
        ] else ...[
          Text(l.phoneCodeSentTo(_sentTo!), style: const TextStyle(fontSize: 17)),
          gap16,
          Form(key: _codeForm, child: CodeField(fieldKey: const ValueKey('phone_code'), controller: _code, onCompleted: (_) => _verify())),
          gap8,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() {
                _sentTo = null;
                _code.clear();
                _error = null;
              }),
              child: Text(l.changeNumber),
            ),
          ),
          InfoBox(l.phoneCodesLimit),
        ],
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
      ],
    );
  }
}
