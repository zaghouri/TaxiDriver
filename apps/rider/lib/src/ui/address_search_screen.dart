import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../geo/places.dart';
import '../l10n/rider_strings.dart';

/// Address search (Google Places, or `GET /v1/geo/search`). Pops a [Place].
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key, required this.places, required this.title, this.near, this.onUseMyLocation});

  final PlacesService places;
  final String title;
  final LatLng? near;

  /// "My current location" row (From field only, when location is allowed).
  final Future<Place?> Function()? onUseMyLocation;

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _items = const [];
  bool _loading = false;
  Object? _error;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String v) async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final res = await widget.places.search(v, near: widget.near, language: lang);
      if (mounted && seq == _seq) setState(() => _items = res);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e);
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  Future<void> _choose(PlaceSuggestion s) async {
    final lang = Localizations.localeOf(context).languageCode;
    setState(() => _loading = true);
    final p = await widget.places.resolve(s, language: lang);
    if (!mounted) return;
    setState(() => _loading = false);
    if (p != null) Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const ValueKey('address_query'),
              controller: _q,
              autofocus: true,
              onChanged: _changed,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.homeSearchAddress),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: ErrorBanner(riderErrorText(context, _error!))),
          Expanded(
            child: ListView(
              children: [
                if (widget.onUseMyLocation != null)
                  ListTile(
                    key: const ValueKey('address_my_location'),
                    leading: const Icon(Icons.my_location, color: BrandColors.primary),
                    title: Text(l.homeCurrentLocation),
                    onTap: () async {
                      final p = await widget.onUseMyLocation!();
                      if (p != null && context.mounted) Navigator.of(context).pop(p);
                    },
                  ),
                for (final s in _items)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(s.title),
                    subtitle: s.subtitle == null ? null : Text(s.subtitle!),
                    onTap: () => _choose(s),
                  ),
                if (!_loading && _items.isEmpty && _q.text.trim().length >= 2 && _error == null)
                  Padding(padding: const EdgeInsets.all(24), child: Text(rs.noAddressFound, textAlign: TextAlign.center)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
