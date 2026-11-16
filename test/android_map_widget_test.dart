import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'package:mungcation/widgets/android_walk_map.dart';
import 'additional_features_test.dart' show picture;
import 'android_services_test.dart' show MemoryMapSettings;

class MemoryTiles extends TileProvider {
  final Uint8List bytes;
  MemoryTiles(this.bytes);
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(bytes);
}

void main() {
  test('planned route paws are spaced and capped', () {
    final now = DateTime.now();
    final samples = List.generate(
      30,
      (index) => GeoSample(37.5 + index * .001, 127, 5, now),
    );
    final paws = spacedRoutePaws(samples, spacing: 80, limit: 5);
    expect(paws, hasLength(5));
    for (var index = 1; index < paws.length; index++) {
      expect(
        distanceBetween(paws[index - 1], paws[index]),
        greaterThanOrEqualTo(80),
      );
    }
  });

  testWidgets(
    'Android map displays discontinuous paths, attribution and tappable places without a key',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = (await tester.runAsync(picture))!,
          now = DateTime.now(),
          config = AndroidMapConfiguration(store: MemoryMapSettings());
      final samples = [
        GeoSample(37.5, 127, 5, now, breakBefore: true),
        GeoSample(37.5001, 127, 5, now.add(const Duration(seconds: 10))),
        GeoSample(
          37.5003,
          127,
          5,
          now.add(const Duration(seconds: 20)),
          breakBefore: true,
        ),
        GeoSample(37.5004, 127, 5, now.add(const Duration(seconds: 30))),
      ];
      String? selected;
      final place = PlaceInfo(
        id: 'park',
        name: '공원',
        address: '',
        category: 'park',
        location: GeoSample(37.5005, 127.0006, 0, now),
        fetchedAt: now,
        source: 'OpenStreetMap',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: AndroidWalkMap(
                configuration: config,
                tileProvider: MemoryTiles(bytes),
                samples: samples,
                current: samples.first,
                places: [place],
                onPlace: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.minZoom, 6);
      expect(options.maxZoom, 19);
      expect(options.cameraConstraint, isA<ContainCameraCenter>());
      expect(find.byTooltip('확대'), findsOneWidget);
      expect(find.byTooltip('축소'), findsOneWidget);
      expect(find.byTooltip('현재 위치로 이동'), findsOneWidget);
      expect(find.text('멍케이션 지도'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .length,
        2,
      );
      expect(pixelPlaceKind(place), PixelPlaceKind.park);
      await tester.tap(find.text('공원 · +30P'));
      await tester.pumpAndSettle();
      expect(selected, 'park');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      config.dispose();
    },
  );
}
