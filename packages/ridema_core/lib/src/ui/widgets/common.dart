import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../brand.dart';
import '../../l10n/l10n.dart';
import '../../theme.dart';

/// Logo mark + product name.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      BrandAssets.markSvg,
      package: BrandAssets.package,
      width: size,
      height: size,
      semanticsLabel: kAppName,
    );
    if (!showName) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 12),
        // Keep the Latin name left-to-right even in Arabic.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            kAppName,
            style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w800, color: BrandColors.ink, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Full-width primary button with a busy spinner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon, this.color});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
        onPressed: busy ? null : onPressed,
        child: child,
      ),
    );
  }
}

/// Full-width secondary button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: icon == null
            ? OutlinedButton(onPressed: onPressed, child: Text(label, textAlign: TextAlign.center))
            : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label, textAlign: TextAlign.center)),
      );
}

/// Red inline message.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BrandColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.danger.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: BrandColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: BrandColors.danger, fontSize: 16))),
            ],
          ),
        ),
      );
}

/// Neutral information box.
class InfoBox extends StatelessWidget {
  const InfoBox(this.message, {super.key, this.icon = Icons.info_outline, this.color = BrandColors.primary});
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
          ],
        ),
      );
}

/// Scrollable page body with standard padding, safe on small screens.
class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.children, this.title, this.bottom});
  final String? title;
  final List<Widget> children;

  /// Pinned button area at the bottom.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: title == null ? null : Text(title!)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
            if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: bottom),
          ],
        ),
      ),
    );
  }
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.helperText,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: widget.fieldKey,
        controller: widget.controller,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          suffixIcon: IconButton(
            tooltip: context.l10n.showPassword,
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}

/// Big numeric code input (6 digits by default), always left-to-right.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.length = 6, this.label, this.onCompleted, this.fieldKey});
  final TextEditingController controller;
  final int length;
  final String? label;
  final ValueChanged<String>? onCompleted;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: length,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
          style: const TextStyle(fontSize: 30, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: InputDecoration(labelText: label ?? context.l10n.codeLabel, counterText: ''),
          onChanged: (v) {
            if (v.length == length) onCompleted?.call(v);
          },
          validator: (v) => (v ?? '').length == length ? null : context.l10n.errorCodeFormat,
        ),
      );
}

/// Label/value line used in receipts and profile.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 15))),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
            ),
          ],
        ),
      );
}

/// Shows a translated error in a snackbar.
void showErrorSnack(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(SnackBar(content: Text(errorText(context.l10n, error)), backgroundColor: BrandColors.danger));
}

void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
}

/// Yes/No dialog. Returns true on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String message,
  String? title,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(message, style: const TextStyle(fontSize: 17)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: BrandColors.danger, minimumSize: const Size(64, 48)) : FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel ?? l.confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Simple email check (the server validates for real).
bool looksLikeEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// Gap helper.
const gap8 = SizedBox(height: 8);
const gap16 = SizedBox(height: 16);
const gap24 = SizedBox(height: 24);

/// Height of the main tap targets (re-exported for apps).
const double tapTarget = kTapTarget;
