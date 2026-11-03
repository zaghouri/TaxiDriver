import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

/// 4-digit PIN entry with a large on-screen keypad (no system keyboard).
/// Calls [onSubmit] with the 4 digits when the driver taps the start button.
class PinKeypad extends StatefulWidget {
  const PinKeypad({super.key, required this.onSubmit, required this.submitLabel, this.busy = false, this.error, this.length = 4});

  final Future<bool> Function(String pin) onSubmit;
  final String submitLabel;
  final bool busy;
  final String? error;
  final int length;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  String _pin = '';

  void _tap(String d) {
    if (_pin.length >= widget.length || widget.busy) return;
    setState(() => _pin += d);
  }

  void _back() {
    if (_pin.isEmpty || widget.busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final ok = await widget.onSubmit(_pin);
    if (!ok && mounted) setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget key(String d) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                key: ValueKey('pin_key_$d'),
                onPressed: () => _tap(d),
                child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.enterPinTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      Text(l.enterPinHint, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade800)),
      const SizedBox(height: 8),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          key: const ValueKey('pin_boxes'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: i < _pin.length ? BrandColors.primary : const Color(0xFFD0D7D4), width: 2),
                ),
                child: Text(i < _pin.length ? _pin[i] : '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
      if (widget.error != null) ...[const SizedBox(height: 8), ErrorBanner(widget.error!)],
      const SizedBox(height: 8),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          Row(children: [key('1'), key('2'), key('3')]),
          Row(children: [key('4'), key('5'), key('6')]),
          Row(children: [key('7'), key('8'), key('9')]),
          Row(children: [
            const Expanded(child: SizedBox()),
            key('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  height: 56,
                  child: IconButton(
                    key: const ValueKey('pin_backspace'),
                    tooltip: l.delete,
                    onPressed: _back,
                    icon: const Icon(Icons.backspace_outlined),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
      PrimaryButton(
        key: const ValueKey('pin_submit'),
        label: widget.submitLabel,
        busy: widget.busy,
        onPressed: _pin.length == widget.length ? _submit : null,
      ),
    ]);
  }
}
