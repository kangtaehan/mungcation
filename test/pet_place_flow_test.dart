import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mungcation/features/walking_page.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/pet_admission.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/walk_session.dart';
import 'controller_test.dart' show MemoryRepository;
import 'walk_test.dart' show FakeLocation;
import 'walking_reroute_test.dart' show CapturingMaps;

class PetFlowMaps extends CapturingMaps {
  bool offlineRestaurants = false;
  final queries = <String>[];
  final store = PlaceInfo(
    id: 'store',
    name: '쇼핑시설 동탄점',
    address: '경기도 화성시',
    category: 'shopping',
    location: GeoSample(37.501, 127, 0, DateTime.now()),
    fetchedAt: DateTime.now(),
    admission: const PetAdmission(
      status: PetAdmissionStatus.conditional,
      transportRule: '유모차 또는 캐리어 중 선택',
      conditions: '유모차 또는 캐리어 중 선택',
      sizeRule: '5kg 미만',
      sourceName: '공식 운영사',
      sourceUrl: 'https://example.org/policy',
    ),
  );
  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    queries.add(query);
    if (offlineRestaurants && query.contains('식당')) throw StateError('offline');
    return query.contains('마트') || query == '반려동물 동반' ? [store] : [];
  }
}

Future<WalkingPageState> mountFlow(
  WidgetTester tester,
  PetFlowMaps maps,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = AppController(
    MemoryRepository(AppData(pet: const PetProfile(name: '몽이'))),
  );
  await app.load();
  final source = FakeLocation(GeoSample(37.5, 127, 5, DateTime.now()));
  final session = WalkSession(app, source: source)..current = source.fix;
  final key = GlobalKey<WalkingPageState>();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    app.dispose();
    await source.events.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WalkingPage(
          key: key,
          controller: app,
          session: session,
          maps: maps,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

void main() {
  setUpAll(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  testWidgets('one unavailable source does not hide published nearby places', (
    tester,
  ) async {
    final maps = PetFlowMaps()..offlineRestaurants = true;
    final page = await mountFlow(tester, maps);
    expect(page.places.map((place) => place.id), ['store']);
    expect(page.error, contains('일부'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('shopping map filter opens sourced branch admission conditions', (
    tester,
  ) async {
    final maps = PetFlowMaps();
    await mountFlow(tester, maps);
    final filter = find.widgetWithText(ActionChip, '마트·쇼핑');
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(maps.queries.last, '반려동물 동반 마트');
    await tester.tap(find.byTooltip('산책 정보 펼치기'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('suggestion-store'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('walk-details-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('유모차 또는 캐리어 중 선택'), findsWidgets);
    expect(find.text('5kg 미만'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
