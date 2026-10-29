import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:ridema_core/ridema_core.dart';

import '../../env.dart';
import '../../l10n/driver_strings.dart';

/// Map with the driver position and optional pickup / destination pins.
///
/// Uses the Google Maps SDK when built with `--dart-define=MAPS_ENABLED=true`
/// (and a key in the manifest / Info.plist); otherwise a simple drawn
/// placeholder so the app is fully usable without a Maps key.
class DriverMap extends StatelessWidget {
  const DriverMap({super.key, this.me, this.pickup, this.dropoff, this.demand = const [], this.enabled = DriverEnv.mapsEnabled});

  final LatLng? me;
  final Place? pickup;
  final Place? dropoff;
  final bool enabled;

  /// Demand cells to shade (D87); empty = layer off.
  final List<DemandCell> demand;

  /// Cell colour by level: saffron, stronger where more riders asked.
  static Color demandColor(int level) => BrandColors.accent.withValues(alpha: 0.18 + 0.14 * (level - 1));

  /// Meknes centre, used before the first GPS fix.
  static const LatLng meknes = LatLng(33.8935, -5.5473);

  @override
  Widget build(BuildContext context) {
    if (!enabled) return _PlaceholderMap(me: me, pickup: pickup, dropoff: dropoff, demand: demand);
    final centre = me ?? pickup?.latLng ?? meknes;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: gm.LatLng(centre.lat, centre.lng), zoom: 14.5),
      myLocationEnabled: me != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      markers: {
        if (pickup != null)
          gm.Marker(
            markerId: const gm.MarkerId('pickup'),
            position: gm.LatLng(pickup!.lat, pickup!.lng),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
          ),
        if (dropoff != null)
          gm.Marker(
            markerId: const gm.MarkerId('dropoff'),
            position: gm.LatLng(dropoff!.lat, dropoff!.lng),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
          ),
      },
      circles: {
        for (final (i, c) in demand.indexed)
          gm.Circle(
            circleId: gm.CircleId('demand-$i'),
            center: gm.LatLng(c.lat, c.lng),
            radius: 280,
            strokeWidth: 0,
            fillColor: DriverMap.demandColor(c.level),
          ),
      },
      polylines: {
        if (pickup != null && dropoff != null)
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            color: BrandColors.primary,
            width: 4,
            points: [gm.LatLng(pickup!.lat, pickup!.lng), gm.LatLng(dropoff!.lat, dropoff!.lng)],
          ),
      },
    );
  }
}

class _PlaceholderMap extends StatelessWidget {
  const _PlaceholderMap({this.me, this.pickup, this.dropoff, this.demand = const []});
  final LatLng? me;
  final Place? pickup;
  final Place? dropoff;
  final List<DemandCell> demand;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.ds.mapPlaceholder,
        child: CustomPaint(
          painter: _GridPainter(me: me, pickup: pickup?.latLng, dropoff: dropoff?.latLng, demand: demand),
          child: const SizedBox.expand(),
        ),
      );
}

class _GridPainter extends CustomPainter {
  _GridPainter({this.me, this.pickup, this.dropoff, this.demand = const []});
  final LatLng? me;
  final LatLng? pickup;
  final LatLng? dropoff;
  final List<DemandCell> demand;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9EFEC));
    final grid = Paint()
      ..color = const Color(0xFFD5DED9)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final pts = [me, pickup, dropoff, ...demand.map((c) => c.latLng)].whereType<LatLng>().toList();
    if (pts.isEmpty) return;
    var minLat = pts.first.lat, maxLat = pts.first.lat, minLng = pts.first.lng, maxLng = pts.first.lng;
    for (final p in pts) {
      minLat = p.lat < minLat ? p.lat : minLat;
      maxLat = p.lat > maxLat ? p.lat : maxLat;
      minLng = p.lng < minLng ? p.lng : minLng;
      maxLng = p.lng > maxLng ? p.lng : maxLng;
    }
    const pad = 0.004;
    Offset at(LatLng p) {
      final w = (maxLng - minLng) + 2 * pad, h = (maxLat - minLat) + 2 * pad;
      return Offset(
        (p.lng - minLng + pad) / w * size.width,
        size.height * 0.15 + (maxLat - p.lat + pad) / h * size.height * 0.55,
      );
    }

    // Demand cells (~500 m) as soft squares under the pins (D87).
    if (demand.isNotEmpty) {
      final w = (maxLng - minLng) + 2 * pad;
      final half = (0.0025 / w * size.width).clamp(6.0, 60.0);
      for (final c in demand) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: at(c.latLng), width: half * 2, height: half * 2), const Radius.circular(6)),
          Paint()..color = DriverMap.demandColor(c.level),
        );
      }
    }
    if (pickup != null && dropoff != null) {
      canvas.drawLine(at(pickup!), at(dropoff!), Paint()
        ..color = BrandColors.primary
        ..strokeWidth = 4);
    }
    void dot(LatLng? p, Color c, double r) {
      if (p == null) return;
      canvas.drawCircle(at(p), r + 3, Paint()..color = Colors.white);
      canvas.drawCircle(at(p), r, Paint()..color = c);
    }

    dot(dropoff, BrandColors.danger, 8);
    dot(pickup, BrandColors.primary, 8);
    dot(me, const Color(0xFF1565C0), 9);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.me != me || old.pickup != pickup || old.dropoff != dropoff || old.demand != demand;
}
