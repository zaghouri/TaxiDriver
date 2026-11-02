import 'package:flutter/foundation.dart';

/// One trip-share contact.
@immutable
class ShareContact {
  const ShareContact({required this.name, required this.phone});
  final String name;
  final String phone;

  @override
  bool operator ==(Object other) => other is ShareContact && other.phone == phone;

  @override
  int get hashCode => phone.hashCode;
}

/// Why a contact could not be added.
enum AddContactResult { added, full, invalidName, invalidPhone, duplicate }

/// Up to [max] contacts for "Share trip" (SPEC §3.2.8, §4.5).
class ShareContactsModel extends ChangeNotifier {
  ShareContactsModel({this.max = 5});

  final int max;
  final List<ShareContact> _items = [];

  List<ShareContact> get items => List.unmodifiable(_items);
  bool get isFull => _items.length >= max;
  bool get isEmpty => _items.isEmpty;

  /// Normalises a phone number the way the backend accepts it:
  /// Moroccan mobile/landline (`06…`, `+2126…`, `002126…`) → `+212XXXXXXXXX`,
  /// other international numbers kept as `+<8–15 digits>`. Null when invalid.
  static String? normalizePhone(String raw) {
    var p = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    final local = RegExp(r'^0([5-7]\d{8})$').firstMatch(p);
    if (local != null) return '+212${local.group(1)}';
    final bare = RegExp(r'^([5-7]\d{8})$').firstMatch(p);
    if (bare != null) return '+212${bare.group(1)}';
    final ma = RegExp(r'^\+212(0?)([5-7]\d{8})$').firstMatch(p);
    if (ma != null) return '+212${ma.group(2)}';
    if (p.startsWith('+212')) return null; // wrong Moroccan length
    if (RegExp(r'^\+\d{8,15}$').hasMatch(p)) return p;
    return null;
  }

  AddContactResult add(String name, String phone) {
    if (isFull) return AddContactResult.full;
    final n = name.trim();
    if (n.isEmpty || n.length > 60) return AddContactResult.invalidName;
    final p = normalizePhone(phone);
    if (p == null) return AddContactResult.invalidPhone;
    final c = ShareContact(name: n, phone: p);
    if (_items.contains(c)) return AddContactResult.duplicate;
    _items.add(c);
    notifyListeners();
    return AddContactResult.added;
  }

  void removeAt(int i) {
    _items.removeAt(i);
    notifyListeners();
  }

  List<({String name, String phone})> toRecords() => [for (final c in _items) (name: c.name, phone: c.phone)];
}
