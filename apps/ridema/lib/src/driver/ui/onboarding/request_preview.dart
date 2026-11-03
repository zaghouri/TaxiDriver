import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../l10n/driver_strings.dart';

/// "While you wait": open requests in the city, area level only, no bidding (D86).
class RequestPreviewSection extends StatefulWidget {
  const RequestPreviewSection({super.key, this.load});

  /// Override for tests; defaults to `GET /v1/driver/preview`.
  final Future<List<RequestPreview>> Function()? load;

  @override
  State<RequestPreviewSection> createState() => _RequestPreviewSectionState();
}

class _RequestPreviewSectionState extends State<RequestPreviewSection> {
  List<RequestPreview>? _items;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items == null && !_failed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final load = widget.load ?? () => CoreServices.of(context).api.driverPreview();
    try {
      final items = await load();
      if (mounted) {
        setState(() {
          _items = items;
          _failed = false;
        });
      }
    } catch (_) {
      // Optional: the review screen works without it.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l = context.l10n;
    final items = _items;
    if (_failed) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('request_preview'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(ds.previewTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            IconButton(key: const ValueKey('preview_refresh'), tooltip: ds.refresh, icon: const Icon(Icons.refresh), onPressed: _refresh),
          ]),
          Text(ds.previewHint, style: TextStyle(color: Colors.grey.shade700)),
          gap8,
          if (items == null)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Text(ds.previewEmpty, textAlign: TextAlign.center)
          else
            for (final r in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text('${r.pickupArea} → ${r.dropoffArea}'),
                subtitle: Text([
                  ds.previewTrip(r.tripKm.toStringAsFixed(1)),
                  if (r.awayKm != null) ds.previewAway(r.awayKm!.toStringAsFixed(1)),
                  ds.previewAgo(r.minutesAgo),
                ].join(' · ')),
                trailing: Text(l.priceDh(r.offeredPrice), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
        ]),
      ),
    );
  }
}
