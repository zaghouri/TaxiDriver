import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/geo/places.dart';
import 'package:ridema_rider/src/geo/saved_places.dart';
import 'package:ridema_rider/src/l10n/rider_strings.dart';
import 'package:ridema_rider/src/ui/address_search_screen.dart';

import 'support/fakes.dart';

class _Places implements PlacesService {
  @override
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near, required String language}) async =>
      [const PlaceSuggestion(title: 'Bab Mansour', lat: 33.893, lng: -5.566)];
  @override
  Future<Place?> resolve(PlaceSuggestion s, {required String language}) async =>
      Place(lat: s.lat!, lng: s.lng!, address: s.fullText);
  @override
  Future<String?> reverse(LatLng p, {required String language}) async => null;
}

class _Store implements SavedPlacesStore {
  _Store(this.state);
  SavedPlaces state;
  final calls = <String>[];

  @override
  Future<SavedPlaces> load() async => state;
  @override
  Future<SavedPlaces> save(String kind, Place place) async {
    calls.add('save $kind ${place.address}');
    state = SavedPlaces(home: kind == 'home' ? place : state.home, work: kind == 'work' ? place : state.work, recent: state.recent);
    return state;
  }

  @override
  Future<SavedPlaces> remove(String kind) async {
    calls.add('remove $kind');
    state = SavedPlaces(home: kind == 'home' ? null : state.home, work: kind == 'work' ? null : state.work, recent: state.recent);
    return state;
  }
}

/// Opens the search from a button so the popped [Place] can be checked.
Widget _host(_Store store, void Function(Place?) done) => wrapApp(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () async => done(await Navigator.of(c).push<Place>(MaterialPageRoute(
            builder: (_) => AddressSearchScreen(places: _Places(), title: 'To', saved: store),
          ))),
          child: const Text('open'),
        ),
      ),
    ));

void main() {
  const home = Place(lat: 33.9, lng: -5.55, address: 'Rue 12, Hamria');
  const recent = Place(lat: 33.87, lng: -5.52, address: 'Marjane Meknès');

  testWidgets('Home and recent places are one tap away when the query is empty', (tester) async {
    final store = _Store(const SavedPlaces(home: home, recent: [recent]));
    Place? got;
    await tester.pumpWidget(_host(store, (p) => got = p));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Rue 12, Hamria'), findsOneWidget);
    expect(find.text(RiderStrings('en').addWork), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    // Typing hides the shortcuts and shows search results.
    await tester.enterText(find.byKey(const ValueKey('address_query')), 'bab');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);
    expect(find.text('Bab Mansour'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('address_query')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marjane Meknès'));
    await tester.pumpAndSettle();
    expect(got?.address, 'Marjane Meknès');
  });

  testWidgets('add Work through a nested search, then remove Home', (tester) async {
    final store = _Store(const SavedPlaces(home: home));
    await tester.pumpWidget(_host(store, (_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saved_add_work')));
    await tester.pumpAndSettle();
    expect(find.text(RiderStrings('en').setWorkTitle), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('address_query')).last, 'bab');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bab Mansour'));
    await tester.pumpAndSettle();
    expect(store.calls, ['save work Bab Mansour']);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text(RiderStrings('en').placeSaved), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('saved_menu_home')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RiderStrings('en').removePlace));
    await tester.pumpAndSettle();
    expect(store.calls.last, 'remove home');
    expect(find.text(RiderStrings('en').addHome), findsOneWidget);
  });

  test('saved-place strings exist in ar, fr and en', () {
    for (final lang in ['ar', 'fr', 'en']) {
      final s = RiderStrings(lang);
      for (final t in [s.placeHome, s.placeWork, s.addHome, s.addWork, s.setHomeTitle, s.setWorkTitle, s.recentPlaces, s.changePlace, s.removePlace, s.placeSaved, s.placeRemoved]) {
        expect(t, isNotEmpty);
      }
    }
  });

  test('SavedPlaces parses the API shape', () {
    final s = SavedPlaces.fromJson({
      'home': {'lat': 1, 'lng': 2, 'address': 'A', 'updated_at': 'x'},
      'work': null,
      'recent': [
        {'lat': 3, 'lng': 4, 'address': 'B'},
      ],
    });
    expect(s.home?.address, 'A');
    expect(s.of('work'), isNull);
    expect(s.recent.single.lat, 3);
  });
}
