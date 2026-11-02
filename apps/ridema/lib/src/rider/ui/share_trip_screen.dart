import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:ridema_core/ridema_core.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/rider_strings.dart';
import '../ride/ride_controller.dart';
import '../ride/share_contacts.dart';

/// Thrown when the user refused access to contacts.
class ContactsDenied implements Exception {}

/// Picks one contact (name + phone) from the phone book.
abstract class ContactPicker {
  /// Null when the user closed the picker. Throws [ContactsDenied].
  Future<({String name, String? phone})?> pick();
}

/// System contact picker via flutter_contacts. Android needs READ_CONTACTS to
/// read the picked phone number, so it is asked only when the rider taps
/// "From my contacts"; typing a number never needs it.
class FlutterContactsPicker implements ContactPicker {
  const FlutterContactsPicker();

  @override
  Future<({String name, String? phone})?> pick() async {
    if (Platform.isAndroid) {
      final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) throw ContactsDenied();
    }
    final c = await fc.FlutterContacts.native.showPicker(properties: {fc.ContactProperty.phone});
    if (c == null) return null;
    return (name: c.displayName ?? '', phone: c.phones.isEmpty ? null : c.phones.first.number);
  }
}

/// Opens the system share sheet (WhatsApp, SMS…).
typedef ShareText = Future<void> Function(String text);

Future<void> systemShare(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

/// Share trip: up to 5 contacts (phone book or typed) → link → share sheet.
class ShareTripScreen extends StatefulWidget {
  const ShareTripScreen({
    super.key,
    required this.controller,
    this.picker = const FlutterContactsPicker(),
    this.share = systemShare,
  });

  final RideController controller;
  final ContactPicker picker;
  final ShareText share;

  @override
  State<ShareTripScreen> createState() => _ShareTripScreenState();
}

class _ShareTripScreenState extends State<ShareTripScreen> {
  final _contacts = ShareContactsModel();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _contacts.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _resultText(AddContactResult r) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    return switch (r) {
      AddContactResult.added || AddContactResult.duplicate => null,
      AddContactResult.full => l.shareMaxContacts,
      AddContactResult.invalidName => '${l.contactName}: ${l.required}',
      AddContactResult.invalidPhone => rs.contactPhoneInvalid,
    };
  }

  void _addTyped() {
    final r = _contacts.add(_name.text, _phone.text);
    setState(() => _formError = _resultText(r));
    if (r == AddContactResult.added) {
      _name.clear();
      _phone.clear();
    }
  }

  Future<void> _pick() async {
    final rs = RiderStrings.of(context);
    try {
      final c = await widget.picker.pick();
      if (c == null || !mounted) return;
      if (c.phone == null) {
        setState(() => _formError = rs.contactNoPhone);
        return;
      }
      final r = _contacts.add(c.name.isEmpty ? c.phone! : c.name, c.phone!);
      setState(() => _formError = _resultText(r));
    } on ContactsDenied {
      if (mounted) setState(() => _formError = rs.contactsPermissionDenied);
    } on PlatformException {
      if (mounted) setState(() => _formError = rs.contactsPermissionDenied);
    }
  }

  Future<void> _create() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final res = await widget.controller.shareTrip(_contacts.toRecords());
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) {
      final e = widget.controller.error;
      if (e != null) showErrorSnack(context, e);
      return;
    }
    await widget.share(l.shareMessage(kAppName, res.url));
    if (mounted) Navigator.of(context).pop(res.url);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    return ListenableBuilder(
      listenable: _contacts,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(l.shareTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.shareBody, style: const TextStyle(fontSize: 16)),
              gap16,
              for (var i = 0; i < _contacts.items.length; i++)
                Card(
                  child: ListTile(
                    key: ValueKey('share_contact_$i'),
                    leading: InitialsAvatar(name: _contacts.items[i].name, radius: 20),
                    title: Text(_contacts.items[i].name),
                    subtitle: Directionality(textDirection: TextDirection.ltr, child: Text(_contacts.items[i].phone)),
                    trailing: IconButton(
                      tooltip: rs.removeContact,
                      icon: const Icon(Icons.close),
                      onPressed: () => _contacts.removeAt(i),
                    ),
                  ),
                ),
              if (_contacts.isFull)
                InfoBox(l.shareMaxContacts)
              else ...[
                SecondaryButton(
                  key: const ValueKey('share_pick_contact'),
                  label: rs.pickFromContacts,
                  icon: Icons.contacts,
                  onPressed: _pick,
                ),
                gap16,
                TextField(
                  key: const ValueKey('share_name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.contactName),
                ),
                gap8,
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    key: const ValueKey('share_phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(18)],
                    decoration: InputDecoration(labelText: l.contactPhone, hintText: '06 12 34 56 78'),
                  ),
                ),
                gap8,
                OutlinedButton.icon(
                  key: const ValueKey('share_add'),
                  onPressed: _addTyped,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(l.addContact),
                ),
              ],
              if (_formError != null) ...[gap8, ErrorBanner(_formError!)],
              gap24,
              PrimaryButton(
                key: const ValueKey('share_create'),
                label: l.shareCreate,
                icon: Icons.share,
                busy: _busy,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
