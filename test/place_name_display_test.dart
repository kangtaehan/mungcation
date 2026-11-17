import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'package:mungcation/widgets/android_walk_map.dart';

import 'additional_features_test.dart' show picture;
import 'android_map_widget_test.dart' show MemoryTiles;
import 'android_services_test.dart' show MemoryMapSettings;

const longParkName = '서울숲 반려견과 함께 걷는 무장애 산책길 중앙 생태공원';
const longSubtitle = '예상 왕복 45분 · 출발 위치에서 1.8km · 동반 조건 확인 필요';

PlaceInfo longNamedPark() => PlaceInfo(
  id: 'long-park',
  name: longParkName,
  address: '서울특별시 성동구',
  category: 'park',
  location: GeoSample(37.5445, 127.0374, 5, DateTime.now()),
  fetchedAt: DateTime.now(),
  source: 'OpenStreetMap',
);

void expectCompleteMarkerText(WidgetTester tester) {
  final marker = find.byType(PixelPlaceMarker);
  final paragraphs = find.descendant(
    of: marker,
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsAtLeastNWidgets(2));
  expect(find.textContaining(longParkName), findsOneWidget);
  expect(find.text(longSubtitle), findsOneWidget);
  final markerBounds = tester.getRect(marker);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      false,
      reason: '장소명과 부가 설명은 말줄임 없이 모두 읽을 수 있어야 합니다.',
    );
    final bounds = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    expect(
      bounds.bottom,
      lessThanOrEqualTo(markerBounds.bottom + 1),
      reason: '확대된 장소 텍스트가 마커 높이 밖으로 잘리면 안 됩니다.',
    );
  }
}

void main() {
  testWidgets('long park name and subtitle wrap at double text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 178,
                child: PixelPlaceMarker(
                  place: longNamedPark(),
                  subtitle: longSubtitle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectCompleteMarkerText(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small map keeps the full long name visible and tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(picture))!;
    final config = AndroidMapConfiguration(store: MemoryMapSettings());
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: AndroidWalkMap(
              configuration: config,
              tileProvider: MemoryTiles(bytes),
              places: [longNamedPark()],
              placeLabels: const {'long-park': longSubtitle},
              onPlace: (id) => selected = id,
              fit: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectCompleteMarkerText(tester);
    final nameBounds = tester.getRect(find.textContaining(longParkName));
    expect(nameBounds.left, greaterThanOrEqualTo(0));
    expect(nameBounds.right, lessThanOrEqualTo(320));
    await tester.tap(find.textContaining(longParkName));
    await tester.pumpAndSettle();
    expect(selected, 'long-park');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    config.dispose();
  });
}
