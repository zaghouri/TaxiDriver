import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';

/// JSON shapes copied from docs/API.md / backend views (as serialised over HTTP).
const rideJson = '''
{
  "id": "0193f1a2-1111-7000-8000-00000000aaaa",
  "status": "accepted",
  "city_id": "0193f1a2-2222-7000-8000-00000000cccc",
  "pickup": {"lat": 33.8926, "lng": -5.5665, "address": "Bab Mansour"},
  "dropoff": {"lat": 33.8957, "lng": -5.5399, "address": "Gare ONCF Meknès Amir Abdelkader"},
  "distance_m": 3120,
  "duration_s": 540,
  "suggested_price": 22,
  "offered_price": 20,
  "final_price": 25,
  "currency": "DH",
  "payment_method": "cash",
  "comment": "Valise",
  "requested_at": "2026-10-26T10:00:00.000Z",
  "expires_at": "2026-10-26T10:05:00.000Z",
  "accepted_at": "2026-10-26T10:01:10.000Z",
  "arrived_at": null,
  "started_at": null,
  "completed_at": null,
  "cancelled_at": null,
  "cancelled_by": null,
  "cancel_reason": null,
  "pickup_pin": "4821",
  "driver": {"id": "d1", "first_name": "Youssef", "rating": 4.87, "rating_count": 120, "trips": 340,
             "vehicle": {"make": "Dacia", "model": "Logan", "year": 2022, "colour": "Blanc", "plate": "12345-A-6"}},
  "rider": {"id": "r1", "first_name": "Amina", "rating": null, "rating_count": 0, "trips": 2},
  "my_rating": null,
  "can_cancel_free": true,
  "some_future_field": {"x": 1}
}
''';

void main() {
  test('Ride parses the full rider view', () {
    final r = Ride.fromJson(jsonDecode(rideJson));
    expect(r.status, RideStatus.accepted);
    expect(r.status.isActive, isTrue);
    expect(r.pickup.address, 'Bab Mansour');
    expect(r.dropoff.lat, closeTo(33.8957, 1e-9));
    expect(r.finalPrice, 25);
    expect(r.price, 25);
    expect(r.pickupPin, '4821');
    expect(r.driver!.firstName, 'Youssef');
    expect(r.driver!.rating, 4.87);
    expect(r.driver!.vehicle!.plate, '12345-A-6');
    expect(r.driver!.vehicle!.label, 'Dacia Logan');
    expect(r.rider!.rating, isNull);
    expect(r.canCancelFree, isTrue);
    expect(r.acceptedAt, DateTime.utc(2026, 10, 26, 10, 1, 10));
  });

  test('Ride tolerates missing fields and odd types', () {
    final r = Ride.fromJson({'id': 'x', 'status': 'in_progress', 'offered_price': '30', 'distance_m': 1200.6});
    expect(r.status, RideStatus.inProgress);
    expect(r.status.apiName, 'in_progress');
    expect(r.offeredPrice, 30);
    expect(r.distanceM, 1201);
    expect(r.driver, isNull);
    expect(r.price, 30);
    expect(Ride.fromJson({'status': 'teleporting'}).status, RideStatus.unknown);
    expect(Ride.fromJson(null).id, '');
  });

  test('Bid (offer with driver card, no plate)', () {
    final b = Bid.fromJson({
      'id': 'b1',
      'ride_id': 'r1',
      'kind': 'counter',
      'price': 30,
      'currency': 'DH',
      'eta_s': 250,
      'distance_m': 1400,
      'status': 'active',
      'created_at': '2026-10-26T10:00:20.000Z',
      'expires_at': '2026-10-26T10:01:20.000Z',
      'driver': {
        'id': 'd1',
        'first_name': 'Youssef',
        'rating': 4.9,
        'rating_count': 12,
        'trips': 40,
        'vehicle': {'make': 'Dacia', 'model': 'Logan', 'year': 2022, 'colour': 'Blanc'},
      },
    });
    expect(b.isCounter, isTrue);
    expect(b.driver!.checks, isNull);
    expect(b.etaMinutes, 5);
    expect(b.driver!.vehicle!.plate, isNull);
    expect(b.expiresAt!.difference(b.createdAt!), const Duration(seconds: 60));
  });

  test('RideRequest (driver view) with my_bid and rider rating', () {
    final q = RideRequest.fromJson({
      'id': 'r1',
      'status': 'searching',
      'pickup': {'lat': 33.89, 'lng': -5.56, 'address': 'Hamria'},
      'dropoff': {'lat': 33.87, 'lng': -5.52, 'address': 'Marjane'},
      'distance_m': 4500,
      'duration_s': 720,
      'offered_price': 25,
      'suggested_price': 27,
      'currency': 'DH',
      'comment': null,
      'expires_at': '2026-10-26T10:05:00.000Z',
      'rider': {'id': 'u1', 'first_name': 'Amina', 'rating': 4.5, 'rating_count': 3, 'trips': 3},
      'pickup_distance_m': 900,
      'pickup_eta_s': 168,
      'my_bid': {'id': 'b9', 'kind': 'accept', 'price': 25, 'status': 'active', 'expires_at': '2026-10-26T10:01:00.000Z'},
    });
    expect(q.dropoff.address, 'Marjane');
    expect(q.rider!.rating, 4.5);
    expect(q.pickupEtaS, 168);
    expect(q.myBid!.price, 25);
    expect(q.copyWith(offeredPrice: 30).offeredPrice, 30);
  });

  test('ActiveRide: rider offers and driver pending bids', () {
    final a = ActiveRide.fromJson({
      'ride': jsonDecode(rideJson),
      'offers': [
        {'id': 'b1', 'price': 20},
      ],
      'pending_bids': [],
    });
    expect(a.ride!.id, isNotEmpty);
    expect(a.offers.single.price, 20);
    expect(ActiveRide.fromJson({'ride': null}).ride, isNull);
  });

  test('DriverProfile with vehicle, documents, problems', () {
    final p = DriverProfile.fromJson({
      'status': 'approved',
      'status_reason': null,
      'city': {'id': 'c1', 'slug': 'meknes', 'name_ar': 'مكناس', 'name_fr': 'Meknès', 'name_en': 'Meknes', 'enabled_driver_types': ['taxi', 'licensed_operator']},
      'driver_type': 'taxi',
      'cin_last4': 'A123',
      'licence_issued_on': '2015-03-01',
      'online': false,
      'blocked_until': null,
      'submitted_at': '2026-10-01T09:00:00.000Z',
      'vehicle': {'id': 'v1', 'make': 'Dacia', 'model': 'Logan', 'year': 2022, 'colour': 'Blanc', 'plate': '12345-A-6', 'doors': 4, 'has_ac': true},
      'documents': [
        {'id': 'd1', 'type': 'insurance', 'status': 'approved', 'expires_on': '2026-11-10', 'reject_reason': null, 'created_at': '2026-01-01T00:00:00Z', 'reviewed_at': null},
        {'id': 'd2', 'type': 'insurance', 'status': 'pending', 'expires_on': '2027-11-10', 'reject_reason': null, 'created_at': '2026-10-20T00:00:00Z', 'reviewed_at': null},
      ],
      'document_problems': [
        {'type': 'selfie', 'problem': 'missing'},
      ],
      'can_go_online': false,
      'problem': {'code': 'DOCUMENTS_INVALID', 'message': 'x'},
    });
    expect(p.status, DriverStatus.approved);
    expect(p.city!.name('ar'), 'مكناس');
    expect(p.vehicle!.hasAc, isTrue);
    expect(p.documents.first.documentType, DocumentType.insurance);
    expect(p.documents.first.daysLeft(DateTime(2026, 10, 26)), 15);
    expect(p.latestDocuments['insurance']!.id, 'd2');
    expect(p.documentProblems.single.problem, 'missing');
    expect(p.problemCode, 'DOCUMENTS_INVALID');
    expect(p.licenceIssuedOn, DateTime(2015, 3, 1));
  });

  test('Receipt', () {
    final r = Receipt.fromJson({
      'receipt_number': 'R-20261026-0193F1A2',
      'ride_id': 'r1',
      'date': '2026-10-26T10:20:00.000Z',
      'started_at': '2026-10-26T10:08:00.000Z',
      'from': {'lat': 33.89, 'lng': -5.56, 'address': 'Bab Mansour'},
      'to': {'lat': 33.9, 'lng': -5.54, 'address': 'Gare'},
      'distance_km': 3.1,
      'duration_min': 12,
      'price': 25,
      'currency': 'DH',
      'payment_method': 'cash',
      'commission': 0,
      'driver': {'first_name': 'Youssef', 'vehicle': {'make': 'Dacia', 'model': 'Logan', 'year': 2022, 'colour': 'Blanc', 'plate': '12345-A-6'}},
      'rider': {'first_name': 'Amina'},
      'company': {'name': 'RideMA SARL', 'rc': 'RC-1', 'ice': 'ICE-2', 'address': 'Meknès'},
      'note': 'Paid in cash directly to the driver.',
    });
    expect(r.price, 25);
    expect(r.distanceKm, 3.1);
    expect(r.vehicle!.plate, '12345-A-6');
    expect(r.company.ice, 'ICE-2');
    expect(r.riderFirstName, 'Amina');
  });

  test('AppConfigResponse', () {
    final c = AppConfigResponse.fromJson(appConfigJson);
    expect(c.minVersion, '1.0.0');
    expect(c.apkUrl, endsWith('.apk'));
    expect(c.storeUrl, isNull);
    expect(c.company.rc, 'RC-123');
    expect(c.legalVersions['terms'], '2026-10-01');
    expect(c.feature('voice_calls'), isTrue);
    expect(c.feature('subscriptions_enabled'), isFalse);
    expect(c.emergencyNumbers.forService('gendarmerie'), '177');
    final empty = AppConfigResponse.fromJson({'features': {'x': {'enabled': true}}});
    expect(empty.feature('x'), isTrue);
    expect(empty.emergencyNumbers.police, '19');
  });

  test('LegalDoc list', () {
    final docs = legalDocs('ar').map(LegalDoc.fromJson).toList();
    expect(docs.map((d) => d.kind), LegalKind.all);
    expect(docs.first.version, '2026-10-01');
    expect(docs.first.locale, 'ar');
  });

  test('Me, Tokens and LoginResult (session or 2FA)', () {
    final me = Me.fromJson(meJson(role: 'driver', phoneVerified: true, phone: '+212612345678', twofa: 'totp'));
    expect(me.role, Role.driver);
    expect(me.phoneVerified, isTrue);
    expect(me.twofaMethod, TwoFactorMethod.totp);
    expect(me.firstName, 'Amina');

    final session = LoginResult.fromJson({...tokensJson(), 'user': meJson()});
    expect(session.mfaRequired, isFalse);
    expect(session.tokens!.isValid, isTrue);
    expect(session.tokens!.expiresIn, 900);
    expect(session.user!.email, 'amina@example.ma');

    final mfa = LoginResult.fromJson({'mfa_required': true, 'method': 'email', 'mfa_token': 't'});
    expect(mfa.mfaRequired, isTrue);
    expect(mfa.mfaMethod, TwoFactorMethod.email);
  });

  test('realtime payloads, turn credentials, SOS result', () {
    expect(RequestClosed.fromJson({'id': 'r1', 'reason': 'taken'}).reason, 'taken');
    expect(BidUpdate.fromJson({'id': 'b', 'ride_id': 'r', 'status': 'lost'}).status, 'lost');
    expect(DriverLocationEvent.fromJson({'ride_id': 'r', 'lat': 1, 'lng': 2, 'heading': 90, 'at': '2026-10-26T10:00:00Z'}).heading, 90);
    final t = TurnCredentials.fromJson({
      'ice_servers': [
        {'urls': ['stun:x:3478', 'turn:x:3478?transport=udp'], 'username': '1:u', 'credential': 'c'},
      ],
      'ttl': 3600,
    });
    expect(t.iceServers.single.urls, hasLength(2));
    expect(SosResult.fromJson({'sos_id': 's1', 'call': '19'}).call, '19');
  });

  test('compareVersions', () {
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('2.0', '2.0.0'), 0);
    expect(compareVersions('1.2.3+45', '1.2.3'), 0);
  });

  test('driver trust badges (D63)', () {
    final p = PersonCard.fromJson({'id': 'd', 'first_name': 'Y', 'checks': {'identity': true, 'car': false}});
    expect(p.checks!.identity, isTrue);
    expect(p.checks!.car, isFalse);
    expect(p.checks!.any, isTrue);
    expect(PersonCard.fromJson({'id': 'd', 'first_name': 'Y', 'checks': {}}).checks!.any, isFalse);
  });

  test('Ride.search: wave, radius and drivers notified while searching (D60)', () {
    final r = Ride.fromJson({
      'id': 'r1', 'status': 'searching', 'pickup': {'lat': 1, 'lng': 2}, 'dropoff': {'lat': 1, 'lng': 3},
      'search': {'wave': 1, 'radius_m': 3500, 'drivers_notified': 4},
    });
    expect(r.search?.wave, 1);
    expect(r.search?.radiusM, 3500);
    expect(r.search?.driversNotified, 4);
    expect(Ride.fromJson({'id': 'r2', 'status': 'accepted', 'pickup': {'lat': 1, 'lng': 2}, 'dropoff': {'lat': 1, 'lng': 3}}).search, isNull);
    final e = Ride.fromJson({'id': 'r3', 'status': 'accepted', 'pickup': {'lat': 1, 'lng': 2}, 'dropoff': {'lat': 1, 'lng': 3}, 'can_edit_pickup': false, 'pickup_edited_at': '2026-10-28T14:00:00Z'});
    expect(e.canEditPickup, isFalse);
    expect(e.pickupEditedAt, DateTime.utc(2026, 10, 28, 14));
  });
}
