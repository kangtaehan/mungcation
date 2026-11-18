import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/pet_admission.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/widgets/android_walk_map.dart';

PlaceInfo shoppingPlace({String category = 'shopping'}) => PlaceInfo(
  id: 'shopping',
  name: '조건부 동반이 가능한 아주 긴 이름의 쇼핑시설 지점',
  address: '서울',
  category: category,
  location: GeoSample(37.5, 127, 0, DateTime.now()),
  fetchedAt: DateTime.now(),
  admission: const PetAdmission(
    status: PetAdmissionStatus.conditional,
    transportRule: '유모차 또는 이동장',
    sourceName: '공식 안내',
    sourceUrl: 'https://example.org/policy',
  ),
);
void main() {
  test('typed civic and shopping places use their own icons', () {
    expect(pixelPlaceKind(shoppingPlace()), PixelPlaceKind.shopping);
    expect(
      pixelPlaceKind(shoppingPlace(category: 'civic')),
      PixelPlaceKind.civic,
    );
  });
  testWidgets(
    'full marker name and admission caption fit at double text size',
    (tester) async {
      final place = shoppingPlace();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Builder(
                builder: (context) => Center(
                  child: SizedBox(
                    width: 178,
                    height: PixelPlaceMarker.heightFor(
                      context,
                      place,
                      '왕복 약 30분',
                      178,
                    ),
                    child: PixelPlaceMarker(place: place, subtitle: '왕복 약 30분'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('조건부 동반 · 왕복 약 30분'), findsOneWidget);
      final bounds = tester.getRect(find.byType(PixelPlaceMarker));
      for (final element
          in find
              .descendant(
                of: find.byType(PixelPlaceMarker),
                matching: find.byType(RichText),
              )
              .evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, false);
        expect(
          (paragraph.localToGlobal(Offset.zero) & paragraph.size).bottom,
          lessThanOrEqualTo(bounds.bottom + 1),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
