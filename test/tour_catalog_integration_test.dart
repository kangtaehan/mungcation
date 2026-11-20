import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/services/pet_place_catalog.dart';
import 'package:mungcation/services/pet_friendly_map_service.dart';
import 'package:mungcation/services/national_park_catalog.dart';
import 'package:mungcation/models/walk_data.dart';
import 'pet_place_catalog_test.dart' show petFixture;
import 'pet_place_catalog_test.dart' show registeredPlace, foodFixture;
import 'package:mungcation/models/pet_admission.dart';
import 'pet_place_data_test.dart' show sourceAsset;
import 'pet_friendly_map_service_test.dart' show SearchMaps;

void main() {
  test(
    'a retired TourAPI favorite cannot retain its former admission as current evidence',
    () async {
      final old = registeredPlace(id: 'tour-pet-retired').withAdmission(
        const PetAdmission(
          status: PetAdmissionStatus.conditional,
          sourceName: '한국관광공사',
          sourceUrl: 'https://www.data.go.kr/data/15135102/openapi.do',
        ),
      );
      final service = PetFriendlyMapService(
        SearchMaps(),
        loadPlaces: () async => PetPlaceCatalog.fromJson(petFixture()),
        loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
      );
      final resolved = await service.resolveAdmission(old);
      expect(resolved.admission!.isAllowed, false);
      expect(resolved.admission!.conditions, contains('현재 관광공사 자료'));
    },
  );
  testWidgets(
    'real TourAPI data supplies Samcheok details while public park pins remain',
    (tester) async {
      final tour = PetPlaceCatalog.fromJson(
        await sourceAsset(tester, 'pet_tour_places.json'),
      );
      final primary = PetPlaceCatalog.fromJson(
        await sourceAsset(tester, 'pet_places.json'),
      );
      final parks = NationalParkCatalog.fromJson(
        await sourceAsset(tester, 'national_parks.json'),
      );
      final combined = PetPlaceCatalog.combine(primary, tour);
      expect(tour.places.length, greaterThan(9000));
      expect(tour.search('삼척시', null).length, greaterThanOrEqualTo(10));
      final rail = tour.places.singleWhere(
        (place) => place.name == '삼척 해양레일바이크',
      );
      expect(rail.admission!.transportRule, contains('이동장'));
      expect(rail.admission!.sourceName, contains('한국관광공사'));
      expect(rail.admission!.referenceDate, isNull);
      final service = PetFriendlyMapService(
        SearchMaps()..offline = true,
        loadPlaces: () async => combined,
        loadParks: () async => parks,
      );
      final near = await service.discoverNearby(
        GeoSample(37.445, 129.165, 5, DateTime.now()),
      );
      expect(near.any((place) => place.hasPublicParkLocation), true);
      expect(near.any((place) => place.id.startsWith('tour-pet-')), true);
      expect(near.every((place) => place.isMapDiscoverable), true);
    },
  );
  test(
    'tour places join discovery without replacing existing restrictions or denied places',
    () {
      final primary = PetPlaceCatalog.fromJson(petFixture());
      final raw = jsonDecode(petFixture()) as Map<String, dynamic>;
      final rows = raw['places'] as List;
      rows.removeWhere((row) => row['id'] == 'conditional');
      for (final row in rows) {
        row['id'] = 'tour-${row['id']}';
        row['admission']['status'] = 'allowed';
      }
      rows.add({
        ...rows.first as Map<String, dynamic>,
        'id': 'tour-new',
        'name': '새로운 카페',
      });
      final combined = PetPlaceCatalog.combine(
        primary,
        PetPlaceCatalog.fromJson(jsonEncode(raw)),
      );
      expect(combined.places.map((p) => p.id).toSet(), {
        'allowed',
        'notAllowed',
        'conditional',
        'tour-new',
      });
      expect(
        combined.places
            .singleWhere((p) => p.id == 'allowed')
            .admission!
            .transportRule,
        '유모차 또는 이동장',
      );
      expect(
        combined.places
            .singleWhere((p) => p.id == 'notAllowed')
            .admission!
            .isAllowed,
        false,
      );
      expect(combined.search('새로운 카페', null).single.id, 'tour-new');
    },
  );
}
