import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mungcation/features/android_map_settings_page.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'package:mungcation/widgets/android_walk_map.dart';
import 'package:mungcation/widgets/walk_map.dart';
import 'additional_features_test.dart' show picture;
import 'android_map_widget_test.dart' show MemoryTiles;
import 'android_services_test.dart' show MemoryMapSettings;

class ErrorTile extends Fake implements TileImage {}

void main() {
  testWidgets(
    'VWorld network tiles explicitly disable the persistent tile cache',
    (tester) async {
      final config = AndroidMapConfiguration(
        store: MemoryMapSettings(),
        vworldKey: 'test-key-12345',
      );
      final bytes = (await tester.runAsync(picture))!;
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AndroidWalkMap(configuration: config, tileClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final provider =
          tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider
              as NetworkTileProvider;
      expect(provider.cachingProvider, isA<DisabledMapCachingProvider>());
      expect(requests, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      client.close();
      config.dispose();
    },
  );
  testWidgets(
    'shared map renders configured VWorld with unchanged route samples',
    (tester) async {
      final config = AndroidMapConfiguration(store: MemoryMapSettings());
      await config.save(config.value.withVWorld('test-key-12345'));
      final bytes = (await tester.runAsync(picture))!;
      final current = GeoSample(37.5, 127, 0, DateTime.now());
      final route = [current, GeoSample(37.501, 127, 0, DateTime.now())];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalkMap(
              configuration: config,
              tileProvider: MemoryTiles(bytes),
              current: current,
              route: route,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
        contains('api.vworld.kr'),
      );
      final raster = tester.widget<AndroidWalkMap>(find.byType(AndroidWalkMap));
      expect(raster.route, same(route));
      expect(raster.configuration, same(config));
      await tester.pumpWidget(const SizedBox());
      config.dispose();
    },
  );
  testWidgets(
    'VWorld outage switches the whole basemap and attribution, preserving the camera and route',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = AndroidMapConfiguration(store: MemoryMapSettings());
      await config.save(config.value.withVWorld('test-key-12345'));
      final bytes = (await tester.runAsync(picture))!;
      final current = GeoSample(37.5, 127, 0, DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AndroidWalkMap(
              configuration: config,
              tileProvider: MemoryTiles(bytes),
              current: current,
              route: [current, GeoSample(37.501, 127, 0, DateTime.now())],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
      final oldCenter = camera.center;
      final original = tester.widget<TileLayer>(find.byType(TileLayer));
      original.errorTileCallback!(
        ErrorTile(),
        StateError('network'),
        StackTrace.current,
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('기본 지도'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
        contains('openstreetmap'),
      );
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(
        MapCamera.of(tester.element(find.byType(TileLayer))).center,
        oldCenter,
      );
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        isNotEmpty,
      );
      expect(
        config.value.isVWorld,
        true,
        reason: 'An outage fallback must not rewrite saved preferences.',
      );
      original.errorTileCallback!(
        ErrorTile(),
        StateError('late old tile'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.text('지도 타일을 불러오지 못했어요.'), findsNothing);
      await tester.tap(find.text('브이월드 재시도'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
        contains('api.vworld.kr'),
      );
      expect(find.text('공간정보 오픈플랫폼(브이월드)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      config.dispose();
    },
  );

  testWidgets(
    'VWorld settings require a key and leave walking endpoints unchanged',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = AndroidMapConfiguration(store: MemoryMapSettings());
      final route = config.value.routing;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AndroidMapSettingsPage(configuration: config),
                  ),
                ),
                child: const Text('설정 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('설정 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '브이월드'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('지도 설정 저장'));
      await tester.tap(find.text('지도 설정 저장'));
      await tester.pumpAndSettle();
      expect(config.value.isVWorld, false);
      expect(find.text('발급받은 브이월드 인증키를 확인해 주세요.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('vworld-key')));
      await tester.enterText(
        find.byKey(const ValueKey('vworld-key')),
        'test-key-12345',
      );
      await tester.ensureVisible(find.text('지도 설정 저장'));
      await tester.tap(find.text('지도 설정 저장'));
      await tester.pumpAndSettle();
      expect(config.value.isVWorld, true);
      expect(config.value.routing, route);
      expect(find.text('설정 열기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      config.dispose();
    },
  );
}
