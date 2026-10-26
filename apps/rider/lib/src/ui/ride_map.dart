import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:ridema_core/ridema_core.dart';

import '../env.dart';
import '../geo/places.dart';
import '../l10n/rider_strings.dart';

/// Full-screen map behind the rider sheets: Google Maps when enabled
/// (`MAPS_ENABLED`), otherwise a drawn placeholder that still shows the pins
/// and the moving car.
class RideMap extends StatelessWidget {
  const RideMap({
    super.key,
    this.me,
    this.pickup,
    this.dropoff,
    this.driver,
    this.driverHeading,
    this.pulse = false,
    this.bottomPadding = 0,
    this.mapsEnabled = RiderEnv.mapsEnabled,
  });

  final LatLng? me;
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final double? driverHeading;

  /// Pulsing circle on the pickup (searching).
  final bool pulse;
  final double bottomPadding;
  final bool mapsEnabled;

  LatLng get _focus => driver ?? pickup ?? me ?? kMeknesCenter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (mapsEnabled)
          _GoogleRideMap(
            focus: _focus,
            me: me,
            pickup: pickup,
            dropoff: dropoff,
            driver: driver,
            driverHeading: driverHeading,
            bottomPadding: bottomPadding,
          )
        else
          PlaceholderMap(focus: _focus, pickup: pickup, dropoff: dropoff, driver: driver, me: me, bottomPadding: bottomPadding),
        if (pulse)
          Positioned.fill(
            bottom: bottomPadding,
            child: const IgnorePointer(child: Center(child: PulsingCircle())),
          ),
      ],
    );
  }
}

class _GoogleRideMap extends StatefulWidget {
  const _GoogleRideMap({
    required this.focus,
    required this.me,
    required this.pickup,
    required this.dropoff,
    required this.driver,
    required this.driverHeading,
    required this.bottomPadding,
  });

  final LatLng focus;
  final LatLng? me;
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final double? driverHeading;
  final double bottomPadding;

  @override
  State<_GoogleRideMap> createState() => _GoogleRideMapState();
}

class _GoogleRideMapState extends State<_GoogleRideMap> {
  gm.GoogleMapController? _c;

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.lat, p.lng);

  @override
  void didUpdateWidget(covariant _GoogleRideMap old) {
    super.didUpdateWidget(old);
    if (old.focus != widget.focus) {
      _c?.animateCamera(gm.CameraUpdate.newLatLng(_g(widget.focus)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final markers = <gm.Marker>{
      if (widget.pickup != null)
        gm.Marker(
          markerId: const gm.MarkerId('pickup'),
          position: _g(widget.pickup!),
          infoWindow: gm.InfoWindow(title: l.pickupLabel),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
        ),
      if (widget.dropoff != null)
        gm.Marker(
          markerId: const gm.MarkerId('dropoff'),
          position: _g(widget.dropoff!),
          infoWindow: gm.InfoWindow(title: l.destinationLabel),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
        ),
      if (widget.driver != null)
        gm.Marker(
          markerId: const gm.MarkerId('driver'),
          position: _g(widget.driver!),
          rotation: widget.driverHeading ?? 0,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueOrange),
        ),
    };
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: _g(widget.focus), zoom: 15),
      onMapCreated: (c) => _c = c,
      markers: markers,
      myLocationEnabled: widget.me != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
    );
  }
}

/// Drawn stand-in for the map (no key / tests): streets grid + pins around [focus].
class PlaceholderMap extends StatelessWidget {
  const PlaceholderMap({super.key, required this.focus, this.pickup, this.dropoff, this.driver, this.me, this.bottomPadding = 0});

  final LatLng focus;
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final LatLng? me;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final h = math.max(1.0, box.maxHeight - bottomPadding);
      final w = box.maxWidth;
      // ~3 km across the visible width.
      const metresAcross = 3000.0;
      final pxPerM = w / metresAcross;
      Offset? pos(LatLng? p) {
        if (p == null) return null;
        final dx = (p.lng - focus.lng) * 111320 * math.cos(focus.lat * math.pi / 180) * pxPerM;
        final dy = -(p.lat - focus.lat) * 110540 * pxPerM;
        return Offset(w / 2 + dx, h / 2 + dy);
      }

      Widget pin(Offset? o, Widget child, {double size = 36}) => o == null
          ? const SizedBox.shrink()
          : Positioned(left: o.dx - size / 2, top: o.dy - size, width: size, height: size, child: child);

      return Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: 0,
            right: 0,
            child: Center(
              child: Text(RiderStrings.of(context).mapUnavailable, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          ),
          pin(pos(me), const Icon(Icons.my_location, color: Colors.blue, size: 24), size: 24),
          pin(pos(pickup), const Icon(Icons.location_on, color: BrandColors.primary, size: 36)),
          pin(pos(dropoff), const Icon(Icons.flag, color: BrandColors.danger, size: 36)),
          pin(
            pos(driver),
            const DecoratedBox(
              decoration: BoxDecoration(color: BrandColors.accent, shape: BoxShape.circle),
              child: Icon(Icons.local_taxi, color: BrandColors.ink, size: 26),
            ),
          ),
        ],
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFF3F1));
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10;
    final minor = Paint()
      ..color = const Color(0xFFE0E7E3)
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (var y = 0.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.42), road);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.6, size.height), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pulsing circle around the pickup while looking for drivers.
class PulsingCircle extends StatefulWidget {
  const PulsingCircle({super.key, this.size = 220});
  final double size;

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final t = _a.value;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Container(
                width: widget.size * (0.2 + 0.8 * t),
                height: widget.size * (0.2 + 0.8 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BrandColors.primary.withValues(alpha: 0.30 * (1 - t)),
                  border: Border.all(color: BrandColors.primary.withValues(alpha: 0.6 * (1 - t)), width: 2),
                ),
              ),
            ),
          );
        },
      );
}
