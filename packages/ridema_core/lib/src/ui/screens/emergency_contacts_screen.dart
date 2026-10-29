import 'package:flutter/material.dart';

import '../../../brand.dart';
import '../../api/ridema_api.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../../models/app_models.dart';
import '../widgets/common.dart';

/// Profile › Emergency contacts (D71): up to [max] people who get the live trip link when the user presses SOS.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key, this.api});

  /// Defaults to [CoreServices]; tests inject a fake.
  final RideMaApi? api;

  static const max = 5;

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late final RideMaApi _api = widget.api ?? CoreServices.of(context).api;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  List<EmergencyContact>? _items;
  Object? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items == null && _error == null && !_busy) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
        final items = await _api.emergencyContacts();
        if (mounted) setState(() => _items = items);
      });

  Future<void> _add() => _run(() async {
        final c = await _api.addEmergencyContact(_name.text.trim(), _phone.text.trim());
        if (!mounted) return;
        _name.clear();
        _phone.clear();
        setState(() => _items = [...?_items, c]);
      });

  Future<void> _remove(EmergencyContact c) => _run(() async {
        await _api.deleteEmergencyContact(c.id);
        if (mounted) setState(() => _items = _items?.where((x) => x.id != c.id).toList());
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items ?? const <EmergencyContact>[];
    final full = items.length >= EmergencyContactsScreen.max;
    final canAdd = !_busy && !full && _name.text.trim().isNotEmpty && _phone.text.trim().length >= 6;
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyContactsTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          InfoBox(l.emergencyContactsInfo(EmergencyContactsScreen.max), icon: Icons.sos, color: BrandColors.danger),
          gap16,
          if (_items == null && _busy) const Center(child: CircularProgressIndicator()),
          if (_items != null && items.isEmpty) Text(l.emergencyContactsEmpty, key: const ValueKey('ec_empty')),
          for (final c in items)
            Card(
              child: ListTile(
                key: ValueKey('ec_${c.id}'),
                leading: const Icon(Icons.person_outline),
                title: Text(c.name),
                subtitle: Text(c.phone, textDirection: TextDirection.ltr),
                trailing: IconButton(
                  key: ValueKey('ec_remove_${c.id}'),
                  tooltip: l.emergencyContactRemove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : () => _remove(c),
                ),
              ),
            ),
          if (_error != null) ...[gap8, ErrorBanner(errorText(l, _error!))],
          if (!full && _items != null) ...[
            gap16,
            Text(l.emergencyContactAdd, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            gap8,
            TextField(
              key: const ValueKey('ec_name'),
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.emergencyContactName, counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            gap8,
            TextField(
              key: const ValueKey('ec_phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 20,
              decoration: InputDecoration(labelText: l.emergencyContactPhone, hintText: '06… / +…', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            gap16,
            PrimaryButton(key: const ValueKey('ec_add'), label: l.emergencyContactAdd, icon: Icons.person_add_alt, busy: _busy, onPressed: canAdd ? _add : null),
          ],
        ]),
      ),
    );
  }
}
