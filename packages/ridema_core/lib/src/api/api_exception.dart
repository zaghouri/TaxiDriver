/// Error from the RideMA API (or the network).
///
/// [code] is the API's SNAKE_CASE code (`EMAIL_TAKEN`, `OFFER_TOO_LOW`, ...).
/// Client-side codes: `NETWORK_ERROR` (no answer), `TIMEOUT`, `BAD_RESPONSE`,
/// `SESSION_EXPIRED` (refresh impossible). Translate with `apiErrorText()`.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status = 0, this.details});

  final String code;

  /// English text from the server; shown only when no translation exists.
  final String message;

  /// HTTP status, 0 when the server was not reached.
  final int status;
  final Object? details;

  static const network = 'NETWORK_ERROR';
  static const timeout = 'TIMEOUT';
  static const badResponse = 'BAD_RESPONSE';
  static const sessionExpired = 'SESSION_EXPIRED';

  /// True when the server never answered (retrying may help).
  bool get isNetwork => status == 0 && (code == network || code == timeout);

  /// Value from `details` (e.g. `min_offer`, `max`, `min_version`).
  Object? detail(String key) {
    final d = details;
    return d is Map ? d[key] : null;
  }

  @override
  String toString() => 'ApiException($status $code: $message)';
}
