import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/features/place_details.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/saved_place.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/pet_friendly_map_service.dart';
import 'package:mungcation/services/pet_place_catalog.dart';
import 'controller_test.dart' show MemoryRepository;
import 'pet_friendly_map_service_test.dart' show SearchMaps;
import 'pet_place_catalog_test.dart'
    show petFixture, foodFixture, registeredPlace;

void main() {
  testWidgets(
    'failed evidence loading offers retry instead of an unknown verdict',
    (tester) async {
      final app = AppController(MemoryRepository(AppData()));
      await app.load();
      var attempts = 0;
      final maps = PetFriendlyMapService(
        SearchMaps(),
        loadPlaces: () async {
          if (++attempts == 1) throw StateError('unavailable');
          return PetPlaceCatalog.fromJson(petFixture());
        },
        loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceDetails(
              place: registeredPlace(name: 'allowed 지점'),
              maps: maps,
              controller: app,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('동반 여부 미확인'), findsNothing);
      expect(find.text('동반 정보 다시 불러오기'), findsOneWidget);
      await tester.tap(find.text('동반 정보 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('자료상 동반 가능'), findsOneWidget);
      expect(find.text('동반 정보 다시 불러오기'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
  testWidgets(
    'opening a legacy favorite resolves evidence and passes it to navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final place = registeredPlace(name: 'allowed 지점');
      final app = AppController(
        MemoryRepository(
          AppData(
            savedPlaces: {place.id: SavedPlace(place: place, note: '내 메모')},
          ),
        ),
      );
      await app.load();
      final maps = PetFriendlyMapService(
        SearchMaps(),
        loadPlaces: () async => PetPlaceCatalog.fromJson(petFixture()),
        loadRegistry: () async => PetFoodRegistry.fromJson(foodFixture()),
      );
      PlaceInfo? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceDetails(
              place: place,
              maps: maps,
              controller: app,
              onRoute: (resolved) => destination = resolved,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('자료상 동반 가능'), findsOneWidget);
      expect(find.text('동반 여부 미확인'), findsNothing);
      expect(find.text('유모차 또는 이동장'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('여기까지 도보 경로'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('여기까지 도보 경로'));
      await tester.pumpAndSettle();
      expect(destination?.admission?.isAllowed, true);
      expect(app.data.savedPlaces[place.id]!.note, '내 메모');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
