import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'package:mungcation/services/android_map_service.dart';
import 'package:mungcation/services/file_transfer.dart';
import 'package:mungcation/services/location_source.dart';
import 'package:mungcation/widgets/android_walk_map.dart';

class MemoryMapSettings implements MapSettingsStore {
  String? raw;
  bool fail = false;
  @override
  Future<String?> load() async => raw;
  @override
  Future<void> save(String value) async {
    if (fail) throw StateError('disk');
    raw = value;
  }
}

http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('saved places with blank names still expose a readable label', () {
    final place = PlaceInfo(
      id: 'legacy',
      name: ' ',
      address: '저장된 장소의 전체 주소',
      category: 'park',
      location: GeoSample(37.5, 127, 0, DateTime.now()),
      fetchedAt: DateTime.now(),
    );
    expect(place.displayName, '공원명 확인 필요');
    expect(place.toMap()['name'], place.displayName);
  });
  test('blank place names use Korean names or the returned address', () async {
    final service = AndroidMapService(
      configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
      client: MockClient((request) async {
        expect(request.url.queryParameters['namedetails'], '1');
        return jsonResponse([
          {
            'osm_id': 1,
            'name': '',
            'namedetails': {'name:ko': '한강 시민 공원 긴 정식 이름'},
            'display_name': '서울 주소',
            'lat': '37.5',
            'lon': '127',
          },
          {
            'osm_id': 2,
            'name': '   ',
            'display_name': '이름 대신 반환된 전체 주소, 서울',
            'lat': '37.5',
            'lon': '127',
          },
          {
            'osm_id': 3,
            'name': '',
            'display_name': '',
            'lat': '37.5',
            'lon': '127',
          },
        ]);
      }),
      requestSpacing: Duration.zero,
    );
    final places = await service.search(
      '공원',
      GeoSample(37.5, 127, 5, DateTime.now()),
    );
    expect(places.map((p) => p.name), [
      '한강 시민 공원 긴 정식 이름',
      '이름 대신 반환된 전체 주소, 서울',
      '이름 정보 없음',
    ]);
    service.close();
  });
  test(
    'Android requests identify the app, bound nearby category searches and cache results',
    () async {
      var calls = 0;
      final config = AndroidMapConfiguration(store: MemoryMapSettings());
      final client = MockClient((request) async {
        calls++;
        expect(request.headers['User-Agent'], contains('Mungcation'));
        expect(request.url.queryParameters['q'], '[park]');
        expect(request.url.queryParameters['bounded'], '1');
        expect(request.url.queryParameters['countrycodes'], 'kr');
        expect(request.url.queryParameters['viewbox'], isNotEmpty);
        return jsonResponse([
          {
            'osm_type': 'way',
            'osm_id': 10,
            'name': '실제 응답 공원',
            'display_name': '주소',
            'class': 'leisure',
            'type': 'park',
            'lat': '37.5',
            'lon': '127.0',
            'extratags': {'phone': '02-000-0000'},
          },
        ]);
      });
      final service = AndroidMapService(
            configuration: config,
            client: client,
            requestSpacing: Duration.zero,
          ),
          center = GeoSample(37.5, 127, 5, DateTime.now());
      final results = await service.search('공원', center);
      expect(results.single.rewardEligible, true);
      expect(results.single.source, contains('OpenStreetMap'));
      expect(results.single.phone, '02-000-0000');
      await service.search('공원', center);
      expect(calls, 1);
      service.close();
    },
  );
  test('unverified POI names do not become reward parks', () async {
    final service = AndroidMapService(
      configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
      client: MockClient(
        (_) async => jsonResponse([
          {
            'osm_type': 'node',
            'osm_id': 20,
            'name': '공원 옆 카페',
            'display_name': '주소',
            'class': 'amenity',
            'type': 'cafe',
            'lat': '37.5',
            'lon': '127',
          },
        ]),
      ),
      requestSpacing: Duration.zero,
    );
    final places = await service.search('공원 옆 카페', null);
    expect(places.single.rewardEligible, false);
    service.close();
  });
  test(
    'category searches exclude administrative areas even when they have names',
    () async {
      final service = AndroidMapService(
        configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
        requestSpacing: Duration.zero,
        client: MockClient(
          (_) async => jsonResponse([
            {
              'osm_id': 1,
              'name': '한남동',
              'class': 'place',
              'type': 'suburb',
              'lat': '37.5',
              'lon': '127',
            },
            {
              'osm_id': 2,
              'name': '용산구',
              'class': 'boundary',
              'type': 'administrative',
              'lat': '37.5',
              'lon': '127',
            },
            {
              'osm_id': 3,
              'name': '실제 카페',
              'class': 'amenity',
              'type': 'cafe',
              'lat': '37.5',
              'lon': '127',
            },
          ]),
        ),
      );
      final results = await service.search(
        '카페',
        GeoSample(37.5, 127, 5, DateTime.now()),
      );
      expect(results.map((place) => place.name), ['실제 카페']);
      service.close();
    },
  );
  test('search results and routes stay inside Korea', () async {
    final service = AndroidMapService(
      configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
      client: MockClient(
        (_) async => jsonResponse([
          {
            'osm_type': 'node',
            'osm_id': 30,
            'name': '서울 장소',
            'display_name': '서울',
            'lat': '37.5',
            'lon': '127.0',
          },
          {
            'osm_type': 'node',
            'osm_id': 31,
            'name': '해외 장소',
            'display_name': '해외',
            'lat': '35.6',
            'lon': '139.7',
          },
        ]),
      ),
      requestSpacing: Duration.zero,
    );
    expect(await service.search('장소', null), hasLength(1));
    final outside = GeoSample(35.6, 139.7, 5, DateTime.now());
    await expectLater(
      service.directions(
        outside,
        PlaceInfo(
          id: 'seoul',
          name: '서울',
          address: '',
          category: 'unknown',
          location: GeoSample(37.5, 127, 0, DateTime.now()),
          fetchedAt: DateTime.now(),
        ),
      ),
      throwsA(isA<MapServiceFailure>()),
    );
    service.close();
  });
  test(
    'category-only searches need a region or actual current location',
    () async {
      var calls = 0;
      final service = AndroidMapService(
        configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
        client: MockClient((_) async {
          calls++;
          return jsonResponse([]);
        }),
        requestSpacing: Duration.zero,
      );
      await expectLater(
        service.search('반려동물 동반 카페', null),
        throwsA(isA<MapServiceFailure>()),
      );
      expect(calls, 0);
      await service.search('강남 반려동물 동반 카페', null);
      expect(calls, 1);
      service.close();
    },
  );
  test(
    'walking routes use the foot server, lon-lat order and actual geometry',
    () async {
      final service = AndroidMapService(
        configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
        client: MockClient((request) async {
          expect(
            request.url.path,
            contains('/routed-foot/route/v1/foot/127.0,37.0;127.1,37.1'),
          );
          expect(request.url.queryParameters['geometries'], 'geojson');
          return jsonResponse({
            'code': 'Ok',
            'routes': [
              {
                'distance': 150.0,
                'duration': 120.0,
                'geometry': {
                  'coordinates': [
                    [127.0, 37.0],
                    [127.1, 37.1],
                  ],
                },
                'legs': [
                  {
                    'steps': [
                      {'name': '보행로', 'distance': 150},
                    ],
                  },
                ],
              },
            ],
          });
        }),
        requestSpacing: Duration.zero,
      );
      final start = GeoSample(37, 127, 5, DateTime.now()),
          end = PlaceInfo(
            id: 'end',
            name: '목적지',
            address: '',
            category: 'unknown',
            location: GeoSample(37.1, 127.1, 0, DateTime.now()),
            fetchedAt: DateTime.now(),
          );
      final routes = await service.directions(start, end);
      expect(routes.single.meters, 150);
      expect(routes.single.samples.last.latitude, 37.1);
      expect(routes.single.source, contains('OSRM'));
      expect(routes.single.instructions.single, contains('150m'));
      service.close();
    },
  );
  test('provider failures never produce invented routes', () async {
    final service = AndroidMapService(
      configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
      client: MockClient((_) async => jsonResponse({'code': 'NoRoute'})),
      requestSpacing: Duration.zero,
    );
    final sample = GeoSample(37, 127, 5, DateTime.now());
    await expectLater(
      service.directions(
        sample,
        PlaceInfo(
          id: 'x',
          name: '목적지',
          address: '',
          category: 'unknown',
          location: sample,
          fetchedAt: DateTime.now(),
        ),
      ),
      throwsA(isA<MapServiceFailure>()),
    );
    service.close();
  });
  test(
    'rate limits show retry information and do not poison the request queue',
    () async {
      var calls = 0;
      final service = AndroidMapService(
        configuration: AndroidMapConfiguration(store: MemoryMapSettings()),
        client: MockClient(
          (_) async =>
              ++calls == 1 ? jsonResponse({}, status: 429) : jsonResponse([]),
        ),
        requestSpacing: Duration.zero,
      );
      await expectLater(
        service.search('서울', null),
        throwsA(isA<MapServiceFailure>()),
      );
      expect(await service.search('서울', null), isEmpty);
      expect(calls, 2);
      service.close();
    },
  );
  test(
    'map settings persist only after successful saves and reject driving endpoints',
    () async {
      final store = MemoryMapSettings(),
          config = AndroidMapConfiguration(store: MemoryMapSettings());
      await config.load();
      final actual = AndroidMapConfiguration(store: store);
      await actual.save(const AndroidMapEndpoints());
      final loaded = AndroidMapConfiguration(store: store);
      await loaded.load();
      expect(loaded.value.routing, contains('routed-foot'));
      expect(
        () => const AndroidMapEndpoints(
          routing: 'https://router.project-osrm.org',
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => const AndroidMapEndpoints(
          tiles: 'http://example.com/{z}/{x}/{y}.png',
        ).validate(),
        throwsFormatException,
      );
      store.fail = true;
      await expectLater(
        actual.save(
          const AndroidMapEndpoints(search: 'https://example.com/search'),
        ),
        throwsStateError,
      );
      expect(actual.value.search, contains('nominatim.openstreetmap.org'));
      config.dispose();
      actual.dispose();
      loaded.dispose();
    },
  );
  test(
    'Android location foreground service is enabled only for opted-in walks',
    () {
      final enabled =
              DeviceLocation.settingsFor(android: true, background: true)
                  as AndroidSettings,
          disabled =
              DeviceLocation.settingsFor(android: true, background: false)
                  as AndroidSettings,
          ios =
              DeviceLocation.settingsFor(android: false, background: true)
                  as AppleSettings;
      expect(enabled.foregroundNotificationConfig, isNotNull);
      expect(enabled.foregroundNotificationConfig!.enableWakeLock, true);
      expect(disabled.foregroundNotificationConfig, isNull);
      expect(ios.allowBackgroundLocationUpdates, true);
    },
  );
  test('Android overlays preserve pauses and cap visible paw markers', () {
    final now = DateTime.now();
    final samples = List.generate(
      450,
      (i) => GeoSample(
        37 + i * .0003,
        127,
        5,
        now.add(Duration(seconds: i * 30)),
        breakBefore: i == 0 || i == 200,
      ),
    );
    final overlays = trackOverlays(samples);
    expect(overlays.segments.length, 2);
    expect(overlays.segments[1].first.breakBefore, true);
    expect(overlays.footprints.length, 400);
  });
  test(
    'file channel supports typed backup bytes and explicit cancellation',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(PlatformFileTransfer.channel, (
        call,
      ) async {
        if (call.method == 'pickBackup') return Uint8List.fromList([1, 2, 3]);
        return false;
      });
      try {
        final transfer = PlatformFileTransfer();
        expect(await transfer.pickBackup(), [1, 2, 3]);
      } finally {
        messenger.setMockMethodCallHandler(PlatformFileTransfer.channel, null);
      }
    },
  );
}
