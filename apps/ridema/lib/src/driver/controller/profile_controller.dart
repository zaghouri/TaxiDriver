import 'package:flutter/foundation.dart';
import 'package:ridema_core/ridema_core.dart' show DriverDocument, DriverProfile, DocumentType;

import 'ports.dart';

/// `GET /v1/driver/profile` state: application status, vehicle, documents.
class DriverProfileController extends ChangeNotifier {
  DriverProfileController(this.api, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DriverBackend api;
  final DateTime Function() _now;

  DriverProfile? _profile;
  Object? _error;
  bool _loading = false;
  bool _disposed = false;

  DriverProfile? get profile => _profile;
  Object? get error => _error;
  bool get loading => _loading;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _profile = await api.profile();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Replaces the profile with a fresh server answer (after PUT / submit).
  void set(DriverProfile p) {
    _profile = p;
    _error = null;
    _notify();
  }

  /// Latest document of each type that expires within [days] (not yet expired).
  List<DriverDocument> expiringWithin([int days = 30]) => documentsWhere((d) {
        final left = d.daysLeft(_now());
        return left != null && left >= 0 && left <= days;
      });

  /// Latest documents that are expired (by date or status).
  List<DriverDocument> expired() => documentsWhere((d) {
        final left = d.daysLeft(_now());
        return d.status == 'expired' || (left != null && left < 0);
      });

  List<DriverDocument> documentsWhere(bool Function(DriverDocument) test) {
    final p = _profile;
    if (p == null) return const [];
    return p.latestDocuments.values.where((d) => d.documentType != null && test(d)).toList()
      ..sort((a, b) => DocumentType.values.indexOf(a.documentType!).compareTo(DocumentType.values.indexOf(b.documentType!)));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
