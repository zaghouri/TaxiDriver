import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/geo/places.dart';

/// Answers by host + path; records every call.
class _Http implements HttpClientAdapter {
  final Map<String, Object? Function(RequestOptions o)> routes = {};
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    final h = routes['${o.uri.host}${o.uri.path}'];
    if (h == null) return ResponseBody.fromString('{"error":{"code":"NOT_FOUND","message":""}}', 404, headers: _json);
    final body = h(o);
    if (body is int) return ResponseBody.fromString('{}', body, headers: _json);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

const _p = LatLng(33.8935, -5.564);

void main() {
  late _Http http;
  late BackendPlacesService backend;

  setUp(() {
    http = _Http();
    backend = BackendPlacesService(RideMaApi(ApiClient(
      baseUrl: 'https://api.test',
      config: const AppConfig(app: AppKind.rider, version: '1.0.0', platform: 'android'),
      tokens: MemoryTokenStore(access: 'a', refresh: 'refresh-token-xxxxxxxxxxxxxxxxxxxxxxxx'),
      deviceId: 'dev-1',
      localeProvider: () => 'fr',
      dio: Dio()..httpClientAdapter = http,
      retryDelay: Duration.zero,
    )));
  });

  test('backend reverse returns the server label in the app language', () async {
    http.routes['api.test/v1/geo/reverse'] = (o) => {'label': o.queryParameters['locale'] == 'ar' ? 'قرب ساحة الهديم' : 'près de Place El Hedim'};
    expect(await backend.reverse(_p, language: 'fr'), 'près de Place El Hedim');
    expect(await backend.reverse(_p, language: 'ar'), 'قرب ساحة الهديم');
  });

  test('backend reverse: no label or a failed call → null (the app shows the GPS point)', () async {
    http.routes['api.test/v1/geo/reverse'] = (_) => {'label': null};
    expect(await backend.reverse(_p, language: 'fr'), isNull);
    http.routes['api.test/v1/geo/reverse'] = (_) => 500;
    expect(await backend.reverse(_p, language: 'fr'), isNull);
  });

  test('Google reverse is used when it answers, the backend when it has nothing or fails', () async {
    http.routes['api.test/v1/geo/reverse'] = (_) => {'label': 'Avenue Moulay Ismail, près de Place El Hedim'};
    final google = GooglePlacesService(apiKey: 'k', fallback: backend, dio: Dio()..httpClientAdapter = http);

    http.routes['maps.googleapis.com/maps/api/geocode/json'] = (_) => {
          'status': 'OK',
          'results': [
            {'formatted_address': '12 Avenue Moulay Ismail, Meknès, Maroc'},
          ],
        };
    expect(await google.reverse(_p, language: 'fr'), '12 Avenue Moulay Ismail, Meknès, Maroc');
    expect(http.calls.where((o) => o.uri.host == 'api.test'), isEmpty);

    // Key restricted / quota exceeded: Google answers with no results.
    http.routes['maps.googleapis.com/maps/api/geocode/json'] = (_) => {'status': 'REQUEST_DENIED', 'results': []};
    expect(await google.reverse(_p, language: 'fr'), 'Avenue Moulay Ismail, près de Place El Hedim');

    // Network / HTTP failure.
    http.routes['maps.googleapis.com/maps/api/geocode/json'] = (_) => 503;
    expect(await google.reverse(_p, language: 'fr'), 'Avenue Moulay Ismail, près de Place El Hedim');
  });
}
