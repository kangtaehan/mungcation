import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/features/places_page.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/saved_place.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/walk_session.dart';
import 'package:mungcation/widgets/outing_checklist.dart';
import 'additional_features_test.dart' show savedFixture;
import 'additional_widgets_test.dart' show FakeMaps, phoneSize;
import 'controller_test.dart' show MemoryRepository;
import 'pet_place_catalog_test.dart' show registeredPlace;
import 'walk_test.dart' show FakeLocation;

void main() {
  testWidgets(
    'old preparation is unchecked for a new outing and saving preserves private notes',
    (tester) async {
      phoneSize(tester, size: const Size(320, 1100));
      final place = savedFixture();
      final app = AppController(
        MemoryRepository(
          AppData(
            savedPlaces: {
              place.id: SavedPlace(
                place: place,
                note: '내 메모',
                access: PetAccess.outdoorOnly,
                preparation: {'water', 'leash'},
                preparedAt: DateTime.now().subtract(const Duration(days: 2)),
              ),
            },
          ),
        ),
      );
      await app.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: OutingChecklist(controller: app, place: place),
            ),
          ),
        ),
      );
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((tile) => !tile.value!),
        true,
      );
      expect(find.textContaining('오늘 준비물을 다시'), findsOneWidget);
      await tester.tap(find.text('목줄·하네스'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('즐겨찾기에 준비 상태 저장'));
      await tester.tap(find.text('즐겨찾기에 준비 상태 저장'));
      await tester.pumpAndSettle();
      expect(app.data.savedPlaces[place.id]!.preparation, {'leash'});
      expect(app.data.savedPlaces[place.id]!.note, '내 메모');
      expect(app.data.savedPlaces[place.id]!.access, PetAccess.outdoorOnly);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );

  testWidgets('favorite category filters work offline', (tester) async {
    phoneSize(tester, size: const Size(390, 1200));
    final cafe = registeredPlace(id: 'cafe', name: '내 카페');
    final app = AppController(
      MemoryRepository(
        AppData(
          savedPlaces: {
            'park': SavedPlace(place: savedFixture()),
            'cafe': SavedPlace(place: cafe),
          },
        ),
      ),
    );
    await app.load();
    final maps = FakeMaps();
    final source = FakeLocation(GeoSample(37.5, 127, 0, DateTime.now()));
    final session = WalkSession(app, source: source);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesSearchPage(
            controller: app,
            maps: maps,
            session: session,
            onDestination: (_) {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '카페'));
    await tester.pumpAndSettle();
    expect(find.text('내 카페'), findsOneWidget);
    expect(find.text('내 공원'), findsNothing);
    expect(maps.queries, isEmpty);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    app.dispose();
    await source.events.close();
  });
}
