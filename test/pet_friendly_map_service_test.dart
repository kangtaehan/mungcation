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
  test('nearby result limit applies after excluding denied records', () async {
    final raw = jsonDecode(petFixture()) as Map<String, dynamic>;
    final original = raw['places'] as List;
    final denied = original[1] as Map<String, dynamic>;
    raw['places'] = [
      for (var i = 0; i < 65; i++) {...denied, 'id': 'denied-$i', 'lat': 37.5},
      {...original.first as Map<String, dynamic>, 'lat': 37.502},
    ];
    final wrapper = PetFriendlyMapService(
      SearchMaps()..offline = true,
      loadPlaces: () async => PetPlaceCatalog.fromJson(jsonEncode(raw)),
      loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
    );
    final found = await wrapper.search(
      '반려동물 동반',
      GeoSample(37.5, 127, 5, DateTime.now()),
    );
    expect(found.map((p) => p.id), ['allowed']);
  });
  test(
    'bundled nearby discovery works without an external place provider',
    () async {
      final maps = SearchMaps()..offline = true;
      final wrapper = service(maps);
      final near = await wrapper.search(
        '반려동물 동반',
        GeoSample(37.5, 127, 5, DateTime.now()),
      );
      expect(near.map((p) => p.id).toSet(), {'allowed', 'conditional'});
      expect(near.every((p) => p.admission?.isAllowed == true), true);
      expect(
        await wrapper.search(
          '반려동물 동반',
          GeoSample(35.1, 129, 5, DateTime.now()),
        ),
        isEmpty,
      );
      expect(maps.queries, isEmpty);
    },
  );
  test(
    'regular park search also attaches published rules without changing the official park identity',
    () async {
      final raw = jsonDecode(petFixture()) as Map<String, dynamic>;
      final row = (raw['places'] as List).first as Map<String, dynamic>;
      row['category'] = 'civic';
      row['kind'] = '여행지';
      final park = PlaceInfo(
        id: 'official-park',
        name: 'allowed 지점',
        category: 'park',
        address: '서울특별시 성동구 왕십리로 10',
        source: '전국도시공원정보표준데이터',
        location: GeoSample(37.5, 127, 0, DateTime.now()),
        fetchedAt: DateTime.now(),
      );
      final maps = SearchMaps()..results = [park];
      final wrapper = PetFriendlyMapService(
        maps,
        loadPlaces: () async => PetPlaceCatalog.fromJson(jsonEncode(raw)),
        loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
      );
      final resolved = (await wrapper.search('공원', park.location)).single;
      expect(resolved.admission?.isAllowed, true);
      expect(resolved.id, park.id);
      expect(resolved.category, 'park');
      expect(resolved.source, park.source);
      final friendly = (await wrapper.search(
        '반려동물 동반 allowed 지점',
        park.location,
      )).single;
      expect(friendly.id, park.id);
      expect(friendly.category, 'park');
      expect(friendly.source, park.source);
      expect(friendly.admission?.isAllowed, true);
      expect(
        (await wrapper.resolveAdmission(park)).admission?.transportRule,
        '유모차 또는 이동장',
      );
    },
  );
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
    final maps = SearchMaps()..results = [registeredPlace(category: 'park')];
    final wrapper = service(maps),
        center = GeoSample(37.5, 127, 5, DateTime.now());
    expect(await wrapper.search('공원', center), maps.results);
    expect(await wrapper.directions(center, registeredPlace()), isNotEmpty);
    expect(maps.queries, ['공원']);
  });
}
