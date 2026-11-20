import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/pet_admission.dart';
import 'place_name_display_test.dart' show longParkName, longNamedPark;
import 'walking_reroute_test.dart' show mountWalk;

void main() {
  testWidgets('walking recommendation cards show the whole park name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final walk = await mountWalk(tester);
    await walk.page.routeTo(
      longNamedPark().withAdmission(
        const PetAdmission(
          status: PetAdmissionStatus.allowed,
          sourceName: '테스트 확인 자료',
          sourceUrl: 'https://example.org/park-policy',
        ),
      ),
      closeSheet: false,
    );
    await tester.pumpAndSettle();
    final cardName = find.descendant(
      of: find.byKey(const ValueKey('suggestion-long-park')),
      matching: find.text(longParkName),
    );
    await tester.scrollUntilVisible(
      cardName,
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('walk-details-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final richText = find.descendant(
      of: cardName,
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(richText);
    expect(paragraph.didExceedMaxLines, false);
    expect(paragraph.size.height, greaterThan(30));
    expect(tester.takeException(), isNull);
  });
}
