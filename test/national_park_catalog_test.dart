import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/national_park_catalog.dart';
import 'package:mungcation/services/national_park_map_service.dart';
import 'walking_reroute_test.dart' show CapturingMaps;

String fixtureCatalog() => jsonEncode({
  'schema': 1,
  'retrievedAt': '2026-11-18T00:00:00Z',
  'parks': [
    [
      'kr-park-seoul',
      '독서당공원',
      '소공원',
      '서울특별시 용산구 한남동 1-32',
      37.5345083,
      127.012481,
      '02-2199-7605',
      '2026-09-22',
      '서울특별시 용산구청',
    ],
    [
      'kr-park-busan',
      '부산진성공원',
      '근린공원',
      '부산광역시 동구',
      35.13574252,
      129.05,
      '',
      '2026-10-01',
      '부산광역시 동구청',
    ],
    [
      'kr-park-jeju',
      '독서당공원',
      '소공원',
      '제주특별자치도 제주시',
      33.5,
      126.5,
      '',
      '2025-01-01',
      '제주시',
    ],
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'nearby search uses real park names and retains the data reference date',
    () {
      final catalog = NationalParkCatalog.fromJson(fixtureCatalog());
      final places = catalog.search(
        '공원',
        GeoSample(37.5345, 127.0125, 5, DateTime.now()),
      );
      expect(places.map((p) => p.name), ['독서당공원']);
      expect(places.single.referenceDate, DateTime(2026, 9, 22));
      expect(places.single.source, contains('공공데이터포털'));
      expect(places.single.rewardEligible, true);
    },
  );
  test(
    'region and full names can find parks nationwide without collapsing same-name parks',
    () {
      final catalog = NationalParkCatalog.fromJson(fixtureCatalog());
      expect(catalog.search('부산 공원', null).single.name, '부산진성공원');
      expect(catalog.search('독서당공원', null), hasLength(2));
      expect(catalog.search('제주 독서당공원', null).single.id, 'kr-park-jeju');
      expect(catalog.search('공원', null), isEmpty);
    },
  );
  test(
    'park search uses the bundle while cafe and walking routes keep the existing service',
    () async {
      final delegate = CapturingMaps();
      final service = NationalParkMapService(
        delegate,
        loadCatalog: () async => NationalParkCatalog.fromJson(fixtureCatalog()),
      );
      final center = GeoSample(37.5345, 127.0125, 5, DateTime.now());
      final parks = await service.search('공원', center);
      expect(parks.single.name, '독서당공원');
      expect(await service.search('카페', center), isEmpty);
      expect(await service.directions(center, parks.single), isNotEmpty);
      expect(delegate.requests.single.destination.id, parks.single.id);
    },
  );
  test(
    'bundled national snapshot has real names, unique identities, and all 17 provinces',
    () async {
      final raw =
          jsonDecode(
                await rootBundle.loadString('assets/data/national_parks.json'),
              )
              as Map<String, dynamic>;
      final rows = raw['parks'] as List;
      expect(rows.length, greaterThan(10000));
      expect(rows.map((row) => row[0]).toSet().length, rows.length);
      for (final prefix in [
        '서울',
        '부산',
        '대구',
        '인천',
        '광주',
        '대전',
        '울산',
        '세종',
        '경기',
        '강원',
        '충청북',
        '충청남',
        '전북',
        '전라남',
        '경상북',
        '경상남',
        '제주',
      ]) {
        expect(
          rows.any((row) => (row[3] as String).startsWith(prefix)),
          true,
          reason: prefix,
        );
      }
      final catalog = NationalParkCatalog.fromJson(jsonEncode(raw));
      expect(catalog.search('용산구 독서당공원', null).single.name, '독서당공원');
      expect(
        rows.every(
          (row) =>
              !RegExp(r'^[가-힣0-9·.]+(?:동|읍|면|리)$').hasMatch(row[1] as String),
        ),
        true,
      );
    },
  );
}
