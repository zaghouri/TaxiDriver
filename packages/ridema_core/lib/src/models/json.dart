/// Tolerant JSON readers: the API may add fields or leave some out, and
/// numbers can arrive as int, double or string. None of these throw.
library;

typedef Json = Map<String, dynamic>;

Json asJson(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

Json? asJsonOrNull(Object? v) => v is Map ? asJson(v) : null;

List<Json> asJsonList(Object? v) => v is List ? v.whereType<Map>().map(asJson).toList() : <Json>[];

String? asString(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

String asStringOr(Object? v, [String fallback = '']) => asString(v) ?? fallback;

int? asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
  return null;
}

int asIntOr(Object? v, [int fallback = 0]) => asInt(v) ?? fallback;

double? asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return fallback;
}

DateTime? asDate(Object? v) {
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  return null;
}

List<String> asStringList(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
