import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/pet_place_catalog.dart';

String petFixture() => jsonEncode({
  'schema': 1,
  'retrievedAt': '2026-11-18T00:00:00Z',
  'policies': {},
  'places': [
    for (final entry in [
      ('allowed', 'cafe', 37.5),
      ('notAllowed', 'cafe', 37.501),
      ('conditional', 'shopping', 37.502),
    ])
      {
        'id': entry.$1,
        'name': '${entry.$1} 지점',
        'category': entry.$2,
        'address': '서울특별시 성동구 왕십리로 10',
        'roadName': '왕십리로',
        'buildingNumber': '10',
        'lat': entry.$3,
        'lon': 127,
        'admission': {
          'status': entry.$1,
          'conditions': '유모차 또는 이동장',
          'transportRule': '유모차 또는 이동장',
          'sourceName': '공개 자료',
          'sourceUrl': 'https://example.org/rules',
          'referenceDate': '2025-03-24',
        },
      },
  ],
});
String foodFixture() => jsonEncode({
  'schema': 1,
  'retrievedAt': '2026-11-18T00:00:00Z',
  'sourceUrl': 'https://www.foodsafetykorea.go.kr/portal/petKorea.do',
  'places': [
    {
      'id': 'registered',
      'name': '등록 카페 성수점',
      'road': '왕십리로',
      'number': '10',
      'region': '서울',
      'locality': '성동구',
      'address': '서울특별시 성동구 왕십리로 10',
    },
  ],
});
PlaceInfo registeredPlace({
  String id = 'osm',
  String category = 'cafe',
  String number = '10',
  String name = '등록 카페 성수점',
}) => PlaceInfo(
  id: id,
  name: name,
  address: '서울특별시 성동구 왕십리로 $number',
  roadName: '왕십리로',
  buildingNumber: number,
  category: category,
  location: GeoSample(37.5, 127, 0, DateTime.now()),
  fetchedAt: DateTime.now(),
);

void main() {
  test(
    'public parks need matching full identity and a travel-place policy, not a cafe policy',
    () {
      final raw = jsonDecode(petFixture()) as Map<String, dynamic>;
      final row = (raw['places'] as List).first as Map<String, dynamic>;
      PlaceInfo park({String address = '서울특별시 성동구 왕십리로 10'}) => PlaceInfo(
        id: 'official-park',
        name: 'allowed 지점',
        address: address,
        category: 'park',
        location: GeoSample(37.5, 127, 0, DateTime.now()),
        fetchedAt: DateTime.now(),
      );
      expect(PetPlaceCatalog.fromJson(jsonEncode(raw)).match(park()), isNull);
      row['category'] = 'civic';
      row['kind'] = '여행지';
      final catalog = PetPlaceCatalog.fromJson(jsonEncode(raw));
      expect(catalog.match(park())?.admission?.isAllowed, true);
      expect(catalog.match(park(address: '서울특별시 성동구 왕십리로 20')), isNull);
      (raw['places'] as List).add({...row, 'id': 'duplicate-policy'});
      expect(PetPlaceCatalog.fromJson(jsonEncode(raw)).match(park()), isNull);
    },
  );
  test(
    'friendly search includes allowed and conditional records, never denied records',
    () {
      final catalog = PetPlaceCatalog.fromJson(petFixture());
      final results = catalog.search(
        '반려동물 동반',
        GeoSample(37.5, 127, 5, DateTime.now()),
      );
      expect(results.map((p) => p.id).toSet(), {'allowed', 'conditional'});
      expect(
        catalog.search('카페', GeoSample(37.5, 127, 5, DateTime.now())).single.id,
        'allowed',
      );
      expect(
        catalog.search('마트', GeoSample(37.5, 127, 5, DateTime.now())).single.id,
        'conditional',
      );
      expect(catalog.search('카페', null), isEmpty);
      expect(catalog.search('서울 카페', null).single.id, 'allowed');
    },
  );
  test(
    'matching admission information requires the exact branch and building',
    () {
      final catalog = PetPlaceCatalog.fromJson(petFixture());
      expect(catalog.match(registeredPlace(name: 'allowed 지점'))?.id, 'allowed');
      expect(
        catalog.match(registeredPlace(name: 'allowed 지점', number: '20')),
        isNull,
      );
      expect(catalog.match(registeredPlace(name: 'allowed 다른지점')), isNull);
    },
  );
  test(
    'food registration only attaches to exact name, locality, road and building number',
    () {
      final registry = PetFoodRegistry.fromJson(foodFixture());
      expect(registry.match(registeredPlace())?.isAllowed, true);
      expect(registry.match(registeredPlace())?.transportRule, isEmpty);
      expect(registry.match(registeredPlace(number: '20')), isNull);
      expect(registry.match(registeredPlace(name: '등록 카페 강남점')), isNull);
      expect(
        registry.match(registeredPlace(category: 'shopping')),
        isNull,
        reason: 'A food licence must not replace a shopping facility policy.',
      );
      final missing = PlaceInfo(
        id: 'x',
        name: '등록 카페 성수점',
        address: '서울특별시 성동구 왕십리로 10',
        category: 'cafe',
        location: GeoSample(37.5, 127, 0, DateTime.now()),
        fetchedAt: DateTime.now(),
      );
      expect(
        registry.match(missing),
        isNull,
        reason:
            'Do not infer the building from a business name or a nearby coordinate.',
      );
    },
  );
}
