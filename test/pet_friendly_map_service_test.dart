import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/pet_place_catalog.dart';
import 'package:mungcation/services/pet_friendly_map_service.dart';
import 'pet_place_catalog_test.dart'
    show petFixture, foodFixture, registeredPlace;
import 'walking_reroute_test.dart' show CapturingMaps;

class SearchMaps extends CapturingMaps {
  List<PlaceInfo> results = [];
  bool offline = false;
  final queries = <String>[];
  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    queries.add(query);
    if (offline) throw StateError('offline');
    return results;
  }
}

PetFriendlyMapService service(SearchMaps maps) => PetFriendlyMapService(
  maps,
  loadPlaces: () async => PetPlaceCatalog.fromJson(petFixture()),
  loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
);
void main() {
  test(
    'friendly searches show sourced allowed places and matching registered food branches only',
    () async {
      final maps = SearchMaps()
        ..results = [
          registeredPlace(),
          registeredPlace(id: 'unknown', name: '모르는 카페'),
        ];
      final results = await service(
        maps,
      ).search('반려동물 동반 카페', GeoSample(37.5, 127, 5, DateTime.now()));
      expect(results.map((p) => p.id).toSet(), {'allowed', 'osm'});
      expect(results.every((p) => p.admission?.isAllowed == true), true);
      expect(
        results.singleWhere((p) => p.id == 'osm').admission!.sourceName,
        contains('식품안전나라'),
      );
    },
  );
  test('unverified cafe does not receive another branch policy', () async {
    final maps = SearchMaps()..results = [registeredPlace(number: '20')];
    final results = await service(
      maps,
    ).search('반려동물 동반 카페', GeoSample(37.5, 127, 5, DateTime.now()));
    expect(results.map((p) => p.id), ['allowed']);
  });
  test(
    'food registration cannot erase published gear or denial rules',
    () async {
      final raw = jsonDecode(petFixture()) as Map<String, dynamic>;
      final food = jsonDecode(foodFixture()) as Map<String, dynamic>;
      final rows = raw['places'] as List;
      final registered = food['places'] as List;
      for (final row in rows.where((p) => p['category'] == 'cafe')) {
        registered.add({
          ...registered.first as Map<String, dynamic>,
          'name': row['name'],
        });
      }
      final wrapper = PetFriendlyMapService(
        SearchMaps(),
        loadPlaces: () async => PetPlaceCatalog.fromJson(jsonEncode(raw)),
        loadRegistry: () async => PetFoodRegistry.fromJson(jsonEncode(food)),
      );
      final results = await wrapper.search(
        '반려동물 동반 카페',
        GeoSample(37.5, 127, 0, DateTime.now()),
      );
      expect(results.map((p) => p.id), ['allowed']);
      expect(results.single.admission!.transportRule, '유모차 또는 이동장');
      expect(results.single.admission!.sourceName, '공개 자료');
    },
  );
  test(
    'offline provider still returns published local catalog places',
    () async {
      final maps = SearchMaps()..offline = true;
      final results = await service(
        maps,
      ).search('반려동물 동반 카페', GeoSample(37.5, 127, 5, DateTime.now()));
      expect(results.single.id, 'allowed');
    },
  );
  test('normal park search and walking routes still delegate', () async {
    final maps = SearchMaps()..results = [registeredPlace()];
    final wrapper = service(maps),
        center = GeoSample(37.5, 127, 5, DateTime.now());
    expect(await wrapper.search('공원', center), maps.results);
    expect(await wrapper.directions(center, registeredPlace()), isNotEmpty);
    expect(maps.queries, ['공원']);
  });
}
