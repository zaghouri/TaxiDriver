import 'package:dio/dio.dart';

import '../models/app_models.dart';
import '../models/chat.dart';
import '../models/driver.dart';
import '../models/json.dart';
import '../models/ride.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Typed calls for every endpoint of docs/API.md used by the apps.
///
/// Methods return models where API.md defines one, otherwise the raw JSON map.
/// Every method throws `ApiException` on error.
class RideMaApi {
  RideMaApi(this.client);

  final ApiClient client;

  String get _app => client.config.app.apiName;

  // ---------------------------------------------------------------- public

  Future<AppConfigResponse> appConfig() async => AppConfigResponse.fromJson(await client.get(
        '/v1/app/config',
        query: {'app': _app, 'platform': client.config.platform, 'version': client.config.version},
        auth: false,
      ));

  Future<List<LegalDoc>> legal(String locale) async =>
      asJsonList(await client.get('/v1/legal', query: {'locale': locale}, auth: false)).map(LegalDoc.fromJson).toList();

  Future<LegalDoc> legalDoc(String kind, String locale) async =>
      LegalDoc.fromJson(await client.get('/v1/legal/$kind', query: {'locale': locale}, auth: false));

  Future<List<City>> cities() async =>
      asJsonList(await client.get('/v1/cities', auth: false)).map(City.fromJson).toList();

  Future<List<GeoPlace>> geoSearch(String q) async =>
      asJsonList(asJson(await client.get('/v1/geo/search', query: {'q': q}))['items']).map(GeoPlace.fromJson).toList();

  /// [locale] is `ar`, `fr` or `en`; otherwise the server uses Accept-Language.
  Future<ReverseGeocode> geoReverse(double lat, double lng, {String? locale}) async => ReverseGeocode.fromJson(await client.get(
        '/v1/geo/reverse',
        query: {'lat': lat, 'lng': lng, if (locale == 'ar' || locale == 'fr' || locale == 'en') 'locale': locale},
      ));

  Future<TurnCredentials> turnCredentials() async => TurnCredentials.fromJson(await client.get('/v1/calls/turn-credentials'));

  // ------------------------------------------------------------------ auth

  /// `consents` = kind → version, from [legal].
  Future<Me> signup({
    required String email,
    required String password,
    required String fullName,
    required String locale,
    required Map<String, String> consents,
  }) async {
    final res = asJson(await client.post('/v1/auth/signup', auth: false, data: {
      'email': email.trim(),
      'password': password,
      'full_name': fullName.trim(),
      'role': _app,
      'locale': locale,
      'consents': [
        for (final e in consents.entries) {'kind': e.key, 'version': e.value},
      ],
    }));
    return Me.fromJson(res['user']);
  }

  Future<void> verifyEmail(String email, String code) =>
      client.post('/v1/auth/email/verify', auth: false, data: {'email': email.trim(), 'code': code.trim()});

  Future<void> resendEmailCode(String email) => client.post('/v1/auth/email/resend', auth: false, data: {'email': email.trim()});

  Future<LoginResult> login(String email, String password) async => LoginResult.fromJson(await client.post(
        '/v1/auth/login',
        auth: false,
        data: {'email': email.trim(), 'password': password, 'device_id': client.deviceId},
      ));

  Future<LoginResult> login2fa(String mfaToken, String code) async => LoginResult.fromJson(
      await client.post('/v1/auth/login/2fa', auth: false, data: {'mfa_token': mfaToken, 'code': code.trim()}));

  Future<void> logout() => client.post('/v1/auth/logout');

  Future<void> forgotPassword(String email) => client.post('/v1/auth/password/forgot', auth: false, data: {'email': email.trim()});

  Future<void> resetPassword({required String email, required String code, required String newPassword}) => client.post(
        '/v1/auth/password/reset',
        auth: false,
        data: {'email': email.trim(), 'code': code.trim(), 'new_password': newPassword},
      );

  // -------------------------------------------------------------------- me

  Future<Me> me() async => Me.fromJson(await client.get('/v1/me'));

  Future<Me> updateMe({String? fullName, String? locale}) async => Me.fromJson(await client.patch('/v1/me', data: {
        'full_name': ?fullName,
        'locale': ?locale,
      }));

  Future<void> changePassword(String current, String next) =>
      client.post('/v1/me/password', data: {'current_password': current, 'new_password': next});

  /// [phone] in any accepted form (`06…`, `+2126…`).
  Future<PhoneStartResult> startPhoneVerification(String phone) async =>
      PhoneStartResult.fromJson(await client.post('/v1/me/phone/start', data: {'phone': phone}));

  Future<void> verifyPhone(String code) => client.post('/v1/me/phone/verify', data: {'code': code.trim()});

  Future<TotpSetup> totpSetup() async => TotpSetup.fromJson(await client.post('/v1/me/2fa/totp/setup'));

  Future<void> totpEnable(String code) => client.post('/v1/me/2fa/totp/enable', data: {'code': code.trim()});

  Future<void> emailTwoFactorEnable(String password) => client.post('/v1/me/2fa/email/enable', data: {'password': password});

  Future<void> twoFactorDisable(String password) => client.post('/v1/me/2fa/disable', data: {'password': password});

  Future<void> registerDevice({String? fcmToken, bool? rooted, bool? mockLocation}) => client.post('/v1/me/devices', data: {
        'device_id': client.deviceId,
        'platform': client.config.platform,
        'app_version': client.config.version,
        'fcm_token': ?fcmToken,
        'rooted': ?rooted,
        'mock_location': ?mockLocation,
      });

  Future<List<Json>> consents() async => asJsonList(await client.get('/v1/me/consents'));

  /// Full personal-data export (JSON object).
  Future<Json> dataExport() async => asJson(await client.get('/v1/me/data-export'));

  Future<List<DataRequest>> dataRequests() async =>
      asJsonList(await client.get('/v1/me/data-requests')).map(DataRequest.fromJson).toList();

  /// [kind]: access / correction / deletion.
  Future<DataRequest> createDataRequest(String kind, String details) async =>
      DataRequest.fromJson(await client.post('/v1/me/data-requests', data: {'kind': kind, 'details': details}));

  Future<void> deleteAccount(String password) => client.delete('/v1/me', data: {'password': password});

  /// Rider ID check / driver selfie (JPEG/PNG).
  Future<Json> uploadIdCheck(String filePath) async => asJson(await client.request(
        'POST',
        '/v1/me/id-check',
        data: () => FormData.fromMap({'file': MultipartFile.fromFileSync(filePath)}),
      ));

  // ------------------------------------------------------------ rides (both)

  /// Call on app start, resume and every socket (re)connect.
  Future<ActiveRide> activeRide() async => ActiveRide.fromJson(await client.get('/v1/rides/active'));

  Future<RidePage> rides({String? before, int limit = 20}) async =>
      RidePage.fromJson(await client.get('/v1/rides', query: {'before': ?before, 'limit': limit}));

  Future<Ride> ride(String id) async => Ride.fromJson(await client.get('/v1/rides/$id'));

  Future<Receipt> receipt(String rideId) async => Receipt.fromJson(await client.get('/v1/rides/$rideId/receipt'));

  /// Rider: `{ride, cancels_recent, warning}`; driver: `{ride, penalty, blocked_until}`.
  Future<Json> cancelRide(String rideId, CancelReason reason) async =>
      asJson(await client.post('/v1/rides/$rideId/cancel', data: {'reason': reason.apiName}));

  /// [reasons]: chips from [RatingReasons.forRating] (D64).
  Future<void> rate(String rideId, int stars, {String? comment, List<String> reasons = const []}) =>
      client.post('/v1/rides/$rideId/rating', data: {
        'stars': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (reasons.isNotEmpty) 'reasons': reasons,
      });

  /// [service]: police / gendarmerie / ambulance.
  Future<SosResult> sos(String rideId, {required String service, required double lat, required double lng}) async =>
      SosResult.fromJson(await client.post('/v1/rides/$rideId/sos', data: {'service': service, 'lat': lat, 'lng': lng}));

  /// Ride chat history (D72).
  Future<List<ChatMessage>> rideMessages(String rideId) async =>
      asJsonList(asJson(await client.get('/v1/rides/$rideId/messages'))['items']).map(ChatMessage.fromJson).toList();

  /// REST fallback for a chat message when the socket is down; [clientId] makes a retry safe.
  Future<ChatMessage> sendRideMessage(String rideId, {String? text, String? quick, required String clientId}) async =>
      ChatMessage.fromJson(await client.post('/v1/rides/$rideId/messages', data: {'text': ?text, 'quick': ?quick, 'client_id': clientId}));

  /// Status of each emergency contact told about this SOS (D71).
  Future<List<SosContactStatus>> sosContacts(String sosId) async =>
      asJsonList(asJson(await client.get('/v1/sos/$sosId'))['contacts']).map(SosContactStatus.fromJson).toList();

  /// Saved emergency contacts (D71).
  Future<List<EmergencyContact>> emergencyContacts() async =>
      asJsonList(asJson(await client.get('/v1/me/emergency-contacts'))['items']).map(EmergencyContact.fromJson).toList();

  Future<EmergencyContact> addEmergencyContact(String name, String phone) async =>
      EmergencyContact.fromJson(await client.post('/v1/me/emergency-contacts', data: {'name': name, 'phone': phone}));

  Future<void> deleteEmergencyContact(String id) => client.delete('/v1/me/emergency-contacts/$id');

  /// No Idempotency-Key (exempt). Send every ~10 s while the SOS screen is open.
  Future<void> sosLocation(String sosId, {required double lat, required double lng}) =>
      client.post('/v1/sos/$sosId/location', data: {'lat': lat, 'lng': lng});

  /// [kind]: car_mismatch / dispute / safety / lost_item / other.
  Future<Json> report(String rideId, String kind, {String? details}) async =>
      asJson(await client.post('/v1/rides/$rideId/reports', data: {'kind': kind, 'details': ?details}));

  // ------------------------------------------------------------------ rider

  Future<RideEstimate> estimate(LatLng pickup, LatLng dropoff) async => RideEstimate.fromJson(
      await client.post('/v1/rides/estimate', data: {'pickup': pickup.toJson(), 'dropoff': dropoff.toJson()}));

  /// Returns `{ride, drivers_notified}`.
  Future<({Ride ride, int driversNotified})> createRide({
    required Place pickup,
    required Place dropoff,
    required int offeredPrice,
    String? comment,
  }) async {
    final j = asJson(await client.post('/v1/rides', data: {
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'offered_price': offeredPrice,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    }));
    return (ride: Ride.fromJson(j['ride']), driversNotified: asIntOr(j['drivers_notified']));
  }

  Future<({List<Bid> offers, int total})> offers(String rideId) async {
    final j = asJson(await client.get('/v1/rides/$rideId/offers'));
    return (offers: asJsonList(j['offers']).map(Bid.fromJson).toList(), total: asIntOr(j['total']));
  }

  Future<Ride> raiseOffer(String rideId, int offeredPrice) async =>
      Ride.fromJson(await client.post('/v1/rides/$rideId/raise', data: {'offered_price': offeredPrice}));

  /// Move the pickup point once after acceptance (D61). Errors `PICKUP_TOO_FAR`, `PICKUP_EDIT_USED`, `PICKUP_LOCKED`.
  Future<Ride> editPickup(String rideId, Place pickup) async => Ride.fromJson(await client.post('/v1/rides/$rideId/pickup', data: {
        'lat': pickup.lat,
        'lng': pickup.lng,
        if (pickup.address != null && pickup.address!.trim().isNotEmpty) 'address': pickup.address!.trim(),
      }));

  Future<Ride> acceptBid(String rideId, String bidId) async =>
      Ride.fromJson(await client.post('/v1/rides/$rideId/bids/$bidId/accept'));

  Future<void> declineBid(String rideId, String bidId) => client.post('/v1/rides/$rideId/bids/$bidId/decline');

  Future<ShareResult> shareTrip(String rideId, List<({String name, String phone})> contacts) async =>
      ShareResult.fromJson(await client.post('/v1/rides/$rideId/share', data: {
        'contacts': [
          for (final c in contacts) {'name': c.name, 'phone': c.phone},
        ],
      }));

  // ----------------------------------------------------------------- driver

  Future<DriverProfile> driverProfile() async => DriverProfile.fromJson(await client.get('/v1/driver/profile'));

  Future<DriverProfile> updateDriverProfile({
    required String cityId,
    required String driverType,
    required String cinLast4,
    required DateTime licenceIssuedOn,
  }) async =>
      DriverProfile.fromJson(await client.put('/v1/driver/profile', data: {
        'city_id': cityId,
        'driver_type': driverType,
        'cin_last4': cinLast4,
        'licence_issued_on': ymd(licenceIssuedOn),
      }));

  Future<DriverProfile> updateVehicle({
    required String make,
    required String model,
    required int year,
    required String colour,
    required String plate,
    required int doors,
    required bool hasAc,
  }) async =>
      DriverProfile.fromJson(await client.put('/v1/driver/vehicle', data: {
        'make': make,
        'model': model,
        'year': year,
        'colour': colour,
        'plate': plate,
        'doors': doors,
        'has_ac': hasAc,
      }));

  Future<DriverDocument> uploadDocument({
    required DocumentType type,
    required String filePath,
    DateTime? expiresOn,
  }) async =>
      DriverDocument.fromJson(await client.request(
        'POST',
        '/v1/driver/documents',
        data: () => FormData.fromMap({
          'type': type.apiName,
          if (expiresOn != null) 'expires_on': ymd(expiresOn),
          'file': MultipartFile.fromFileSync(filePath),
        }),
      ));

  Future<List<DriverDocument>> documents() async =>
      asJsonList(await client.get('/v1/driver/documents')).map(DriverDocument.fromJson).toList();

  Future<DriverProfile> submitForReview() async => DriverProfile.fromJson(await client.post('/v1/driver/submit'));

  Future<Json> goOnline({
    required double lat,
    required double lng,
    required bool mockLocation,
    required bool rooted,
    String? integrityToken,
  }) async =>
      asJson(await client.post('/v1/driver/online', data: {
        'lat': lat,
        'lng': lng,
        'mock_location': mockLocation,
        'rooted': rooted,
        'integrity_token': ?integrityToken,
      }));

  Future<void> goOffline() => client.post('/v1/driver/offline');

  /// REST fallback for `driver:location` (no Idempotency-Key).
  Future<Json> driverLocation(Map<String, dynamic> location) async =>
      asJson(await client.post('/v1/driver/location', data: location));

  Future<List<RideRequest>> driverRequests() async =>
      asJsonList(asJson(await client.get('/v1/driver/requests'))['items']).map(RideRequest.fromJson).toList();

  /// `price` only for a counter-offer; [etaMin] (3/5/10/15) is the arrival time the driver promises (D66).
  Future<Bid> placeBid(String rideId, {int? counterPrice, int? etaMin}) async => Bid.fromJson(await client.post(
        '/v1/rides/$rideId/bids',
        data: {
          ...counterPrice == null ? {'kind': 'accept'} : {'kind': 'counter', 'price': counterPrice},
          'eta_min': ?etaMin,
        },
      ));

  /// Request feed (D68): hide a request for this driver only.
  Future<void> hideRequest(String rideId) => client.post('/v1/driver/requests/$rideId/hide');

  /// [reason]: fake_request / offensive / wrong_place / other. Also hides the request.
  Future<void> reportRequest(String rideId, String reason, {String? details}) => client.post(
        '/v1/driver/requests/$rideId/report',
        data: {'reason': reason, if (details != null && details.trim().isNotEmpty) 'details': details.trim()},
      );

  /// Alerts only for pickups within [maxPickupKm] (null = any distance).
  Future<void> setMaxPickupKm(double? maxPickupKm) => client.put('/v1/driver/preferences', data: {'max_pickup_km': maxPickupKm});

  Future<void> withdrawBid(String rideId) => client.delete('/v1/rides/$rideId/bids/mine');

  Future<Ride> arrived(String rideId) async => Ride.fromJson(await client.post('/v1/rides/$rideId/arrived'));

  Future<Ride> startTrip(String rideId, {String? pin}) async =>
      Ride.fromJson(await client.post('/v1/rides/$rideId/start', data: {'pin': ?pin}));

  Future<Ride> completeTrip(String rideId) async => Ride.fromJson(await client.post('/v1/rides/$rideId/complete'));

  Future<Json> earnings({int days = 7}) async => asJson(await client.get('/v1/driver/earnings', query: {'days': days}));

  Future<Json> subscription() async => asJson(await client.get('/v1/driver/subscription'));

  /// [method]: cashplus / wafacash / card / wallet.
  Future<Json> subscribe(String method) async => asJson(await client.post('/v1/driver/subscription', data: {'method': method}));

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
