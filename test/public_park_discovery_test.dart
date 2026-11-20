import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/models/pet_admission.dart';
import 'package:mungcation/services/pet_friendly_map_service.dart';
import 'package:mungcation/services/pet_place_catalog.dart';
import 'package:mungcation/services/national_park_catalog.dart';
import 'package:mungcation/widgets/walk_map.dart';
import 'national_park_catalog_test.dart' show fixtureCatalog;
import 'pet_friendly_map_service_test.dart' show SearchMaps;
import 'pet_place_catalog_test.dart'
    show petFixture, foodFixture, registeredPlace;
import 'walking_reroute_test.dart' show mountWalk;
import 'pet_place_map_test.dart' show shoppingPlace;

void main() {
  test('a failed pet catalog does not remove public park locations', () async {
    final service = PetFriendlyMapService(
      SearchMaps()..offline = true,
      loadPlaces: () async => throw StateError('unavailable'),
      loadParks: () async => NationalParkCatalog.fromJson(fixtureCatalog()),
    );
    final places = await service.discoverNearby(
      GeoSample(37.5345, 127.0125, 5, DateTime.now()),
    );
    expect(places.single.id, 'kr-park-seoul');
    expect(places.single.admission, isNull);
  });
  test(
    'public park location is visible without claiming pet admission',
    () async {
      final maps = SearchMaps()..offline = true;
      final service = PetFriendlyMapService(
        maps,
        loadPlaces: () async => PetPlaceCatalog.fromJson(petFixture()),
        loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
        loadParks: () async => NationalParkCatalog.fromJson(fixtureCatalog()),
      );
      final places = await service.discoverNearby(
        GeoSample(37.5345, 127.0125, 5, DateTime.now()),
      );
      final park = places.singleWhere((p) => p.id == 'kr-park-seoul');
      expect(park.isMapDiscoverable, true);
      expect(park.admission?.isAllowed, isNot(true));
      expect(park.mapSubtitle(null), contains('규정 미확인'));
      expect(registeredPlace().isMapDiscoverable, false);
      expect(
        park
            .withAdmission(
              const PetAdmission(
                status: PetAdmissionStatus.notAllowed,
                sourceName: '테스트 규정',
                sourceUrl: 'https://example.org/rules',
              ),
            )
            .isMapDiscoverable,
        false,
      );
      expect(maps.queries, isEmpty);
    },
  );
  testWidgets(
    'public parks outside the walk-time shortlist remain on the map',
    (tester) async {
      final walk = await mountWalk(tester);
      final catalog = NationalParkCatalog.fromJson(fixtureCatalog());
      final park = catalog.search('독서당공원', null).first;
      walk.page.nearbyCandidates = [shoppingPlace(), park];
      walk.page.nearbyCenter = GeoSample(37.5001, 127, 5, DateTime.now());
      walk.page.discoveredNearby = true;
      walk.page.applyNearbyMinutes(5);
      await tester.pumpAndSettle();
      expect(walk.page.places.map((p) => p.id), isNot(contains(park.id)));
      expect(
        tester.widget<WalkMap>(find.byType(WalkMap)).places.map((p) => p.id),
        contains(park.id),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
