import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../geo/places.dart';
import '../geo/saved_places.dart';
import '../l10n/rider_strings.dart';

/// Address search (Google Places, or `GET /v1/geo/search`). Pops a [Place].
///
/// With [saved], an empty query shows Home / Work (tap to use, or to add) and the
/// rider's recent places (D81).
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({
    super.key,
    required this.places,
    required this.title,
    this.near,
    this.onUseMyLocation,
    this.saved,
  });

  final PlacesService places;
  final String title;
  final LatLng? near;

  /// "My current location" row (From field only, when location is allowed).
  final Future<Place?> Function()? onUseMyLocation;

  /// Home / Work / recent shortcuts (null = none, e.g. when moving the pickup).
  final SavedPlacesStore? saved;

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
  SavedPlaces _saved = SavedPlaces.empty;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSaved());
  }

  Future<void> _loadSaved() async {
    final store = widget.saved;
    if (store == null) return;
    try {
      final s = await store.load();
      if (mounted) setState(() => _saved = s);
    } catch (_) {
      // Shortcuts are a convenience: search still works without them.
    }
  }

  /// Picks an address for [kind] (`home` / `work`) and saves it; stays on this screen.
  Future<void> _setSaved(String kind) async {
    final rs = RiderStrings.of(context);
    final p = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => AddressSearchScreen(
          places: widget.places,
          title: kind == 'home' ? rs.setHomeTitle : rs.setWorkTitle,
          near: widget.near,
          onUseMyLocation: widget.onUseMyLocation,
        ),
      ),
    );
    if (p == null || !mounted) return;
    await _savedAction(() => widget.saved!.save(kind, p), rs.placeSaved);
  }

  Future<void> _savedAction(Future<SavedPlaces> Function() run, String done) async {
    try {
      final s = await run();
      if (!mounted) return;
      setState(() => _saved = s);
      showInfoSnack(context, done);
    } catch (e) {
      if (mounted) showInfoSnack(context, riderErrorText(context, e));
    }
  }

  List<Widget> _shortcuts(BuildContext context) {
    final rs = RiderStrings.of(context);
    Widget savedTile(String kind) {
      final p = _saved.of(kind);
      final home = kind == 'home';
      if (p == null) {
        return ListTile(
          key: ValueKey('saved_add_$kind'),
          leading: Icon(home ? Icons.home_outlined : Icons.work_outline),
          title: Text(home ? rs.addHome : rs.addWork),
          onTap: () => _setSaved(kind),
        );
      }
      return ListTile(
        key: ValueKey('saved_$kind'),
        leading: Icon(home ? Icons.home : Icons.work, color: BrandColors.primary),
        title: Text(home ? rs.placeHome : rs.placeWork),
        subtitle: Text(p.address ?? ''),
        onTap: () => Navigator.of(context).pop(p),
        trailing: PopupMenuButton<String>(
          key: ValueKey('saved_menu_$kind'),
          onSelected: (v) =>
              v == 'change' ? _setSaved(kind) : _savedAction(() => widget.saved!.remove(kind), rs.placeRemoved),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'change', child: Text(rs.changePlace)),
            PopupMenuItem(value: 'remove', child: Text(rs.removePlace)),
          ],
        ),
      );
    }

    return [
      savedTile('home'),
      savedTile('work'),
      if (_saved.recent.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(rs.recentPlaces, style: Theme.of(context).textTheme.titleSmall),
        ),
      for (final p in _saved.recent)
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(p.address ?? ''),
          onTap: () => Navigator.of(context).pop(p),
        ),
    ];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {}); // Shortcuts show only while the query is empty.
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
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: ErrorBanner(riderErrorText(context, _error!))),
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
                if (widget.saved != null && _q.text.trim().isEmpty) ..._shortcuts(context),
                if (_q.text.trim().isNotEmpty)
                  for (final s in _items)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(s.title),
                      subtitle: s.subtitle == null ? null : Text(s.subtitle!),
                      onTap: () => _choose(s),
                    ),
                if (!_loading && _items.isEmpty && _q.text.trim().length >= 2 && _error == null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(rs.noAddressFound, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
