import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mungcation/models/pet_admission.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/pet_place_catalog.dart';
import 'package:mungcation/services/national_park_catalog.dart';
import 'package:mungcation/services/pet_friendly_map_service.dart';
import 'pet_friendly_map_service_test.dart' show SearchMaps;

Future<String> sourceAsset(
  WidgetTester tester,
  String name,
) async => (await tester.runAsync(() async {
  if (!kIsWeb) return rootBundle.loadString('assets/data/$name');
  // Flutter #159879 discards asset messages in web widget tests. The server
  // serves the exact asset copied by CI; the web build is compared afterwards.
  final response = await http.get(Uri.base.resolve('/fixtures/$name'));
  expect(response.statusCode, 200);
  return utf8.decode(response.bodyBytes);
}))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Samcheok discovery restores public park pins independently of business admission coverage',
    (tester) async {
      final parkCatalog = NationalParkCatalog.fromJson(
        await sourceAsset(tester, 'national_parks.json'),
      );
      final petCatalog = PetPlaceCatalog.fromJson(
        await sourceAsset(tester, 'pet_places.json'),
      );
      expect(parkCatalog.search('삼척시 공원', null).length, 24);
      final delegate = SearchMaps()..offline = true;
      final service = PetFriendlyMapService(
        delegate,
        loadPlaces: () async => petCatalog,
        loadParks: () async => parkCatalog,
      );
      final center = GeoSample(37.445, 129.165, 5, DateTime.now());
      final places = await service.discoverNearby(center);
      final parks = places
          .where((place) => place.hasPublicParkLocation)
          .toList();
      expect(parks.length, greaterThan(10));
      expect(
        parks.every(
          (park) =>
              park.isMapDiscoverable &&
              distanceBetween(center, park.location) <= 8000,
        ),
        true,
      );
      expect(parks.any((park) => park.admission == null), true);
      expect(
        places
            .where((place) => !place.hasPublicParkLocation)
            .every((place) => place.admission?.isAllowed == true),
        true,
      );
      expect(delegate.queries, isEmpty);
    },
  );
  testWidgets(
    'real public parks receive available admission evidence without fabricated permissions',
    (tester) async {
      final catalog = PetPlaceCatalog.fromJson(
        await sourceAsset(tester, 'pet_places.json'),
      );
      final parks = NationalParkCatalog.fromJson(
        await sourceAsset(tester, 'national_parks.json'),
      );
      final matches = parks
          .search('서울특별시', null, limit: 20000)
          .map((park) => (park, catalog.match(park)))
          .where((pair) => pair.$2 != null)
          .toList();
      expect(matches.length, greaterThan(0));
      for (final pair in matches) {
        expect(pair.$2!.admission!.hasEvidence, true);
        expect(
          distanceBetween(pair.$1.location, pair.$2!.location),
          lessThanOrEqualTo(100),
        );
      }
    },
  );
  testWidgets(
    'published pet data covers all requested kinds and retains restrictions and denials',
    (tester) async {
      final text = await sourceAsset(tester, 'pet_places.json');
      final raw = jsonDecode(text) as Map<String, dynamic>;
      final catalog = PetPlaceCatalog.fromJson(text);
      expect(catalog.places.length, greaterThan(3000));
      expect(
        catalog.places.map((p) => p.id).toSet().length,
        catalog.places.length,
      );
      for (final kind in ['cafe', 'restaurant', 'civic', 'shopping', 'stay']) {
        expect(
          catalog.places.any(
            (p) => p.category == kind && p.admission?.isAllowed == true,
          ),
          true,
          reason: kind,
        );
      }
      expect(
        catalog.places.any(
          (p) => p.admission?.status == PetAdmissionStatus.notAllowed,
        ),
        true,
      );
      expect(
        catalog.places.where((p) => p.admission?.isAllowed == true).length,
        (raw['report']['allowed'] as int) + 6,
      );
      final museum = catalog.places.firstWhere((p) => p.name == '구하우스');
      expect(museum.admission!.transportRule, contains('유모차 필수'));
      expect(museum.admission!.referenceDate, DateTime(2025, 3, 24));
      final mart = catalog.places.singleWhere(
        (p) => p.id == 'pet-retail-starfield-market-dongtan',
      );
      expect(mart.admission!.areaRule, contains('식품매장 전체의 입장 허용을 뜻하지 않습니다'));
      expect(mart.admission!.sizeRule, contains('5kg 미만'));
      final ikea = catalog.places.where(
        (p) => p.id.startsWith('pet-retail-ikea-'),
      );
      expect(ikea, hasLength(5));
      for (final shop in ikea) {
        expect(shop.admission!.transportRule, contains('또는'));
        expect(shop.admission!.rentalRule, contains('대여 없음'));
        expect(shop.admission!.checkedAt, DateTime(2026, 11, 18));
      }
    },
  );
  testWidgets(
    'food registry is an unlocated registration list, not invented map pins',
    (tester) async {
      final text = await sourceAsset(tester, 'pet_food_registry.json');
      final raw = jsonDecode(text) as Map<String, dynamic>;
      final rows = raw['places'] as List;
      expect(rows.length, greaterThan(2000));
      expect(
        rows.every((row) => !row.containsKey('lat') && !row.containsKey('lon')),
        true,
      );
      final names = rows
          .where((row) => (row['locality'] as String).isNotEmpty)
          .toList();
      final counts = <String, int>{};
      for (final row in names) {
        final key =
            '${row['name']}|${row['locality']}|${row['road']}|${row['number']}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final first = names.firstWhere(
        (row) =>
            counts['${row['name']}|${row['locality']}|${row['road']}|${row['number']}'] ==
            1,
      );
      final registry = PetFoodRegistry.fromJson(text);
      final place = PlaceInfo(
        id: 'resolved',
        name: first['name'],
        address: first['address'],
        roadName: first['road'],
        buildingNumber: first['number'],
        category: 'restaurant',
        location: GeoSample(37.5, 127, 0, DateTime.now()),
        fetchedAt: DateTime.now(),
      );
      final matched = registry.match(place);
      expect(matched, isNotNull);
      expect(matched!.transportRule, isEmpty);
      expect(matched.sourceName, contains('식품안전나라'));
    },
  );
}
