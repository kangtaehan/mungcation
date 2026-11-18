import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mungcation/features/walking_page.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/walk_session.dart';
import 'controller_test.dart' show MemoryRepository;
import 'walk_test.dart' show FakeLocation;
import 'walking_reroute_test.dart' show CapturingMaps;

class EntryLocation extends FakeLocation {
  int requests = 0;
  VoidCallback? duringPrepare;
  EntryLocation(super.fix);
  @override
  Future<GeoSample> prepare({required bool background}) {
    requests++;
    expect(background, false);
    duringPrepare?.call();
    return super.prepare(background: background);
  }
}

class NearbyMaps extends CapturingMaps {
  final centers = <GeoSample?>[];
  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    centers.add(center);
    return [];
  }
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  for (final initiallyVisible in [false, true]) {
    testWidgets(
      'map entry requests fresh location (initially visible: $initiallyVisible)',
      (tester) async {
        final app = AppController(
          MemoryRepository(AppData(pet: const PetProfile(name: '몽이'))),
        );
        await app.load();
        final source = EntryLocation(
          GeoSample(37.54, 127.04, 5, DateTime.now()),
        );
        final session = WalkSession(app, source: source);
        final maps = NearbyMaps();
        final key = GlobalKey<WalkingPageState>();
        Future<void> show(bool visible) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WalkingPage(
                  key: key,
                  controller: app,
                  session: session,
                  maps: maps,
                  visible: visible,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          session.dispose();
          app.dispose();
          await source.events.close();
        });
        await show(initiallyVisible);
        if (!initiallyVisible) {
          expect(
            source.requests,
            0,
            reason: 'Hidden map must not request permission.',
          );
          await show(true);
        }
        expect(source.requests, 1);
        expect(session.current, source.fix);
        expect(maps.centers, hasLength(3));
        expect(maps.centers.every((center) => center == source.fix), true);
        final chosen = PlaceInfo(
          id: 'chosen',
          name: '선택한 공원',
          address: '',
          category: 'park',
          location: GeoSample(37.541, 127.04, 5, DateTime.now()),
          fetchedAt: DateTime.now(),
        );
        key.currentState!.query.text = '선택한 공원';
        await key.currentState!.routeTo(chosen, closeSheet: false);
        await tester.pumpAndSettle();
        final initialCenterRequest = key.currentState!.centerRequest;
        await show(false);
        source.fix = GeoSample(37.55, 127.05, 5, DateTime.now());
        await show(true);
        expect(source.requests, 2);
        expect(session.current, source.fix);
        expect(key.currentState!.destination, chosen);
        expect(key.currentState!.routes, isNotEmpty);
        expect(key.currentState!.places, contains(chosen));
        expect(key.currentState!.query.text, '선택한 공원');
        expect(maps.centers, hasLength(3));
        expect(
          key.currentState!.centerRequest,
          greaterThan(initialCenterRequest),
        );
        expect(tester.takeException(), isNull);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          source.requests,
          3,
          reason: 'Returning from settings should refresh location.',
        );
        await show(false);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          source.requests,
          3,
          reason: 'Resuming on another tab must not request location.',
        );
      },
    );
  }

  testWidgets('denied location keeps manual search usable', (tester) async {
    final app = AppController(MemoryRepository());
    await app.load();
    final source = EntryLocation(GeoSample(37, 127, 5, DateTime.now()))
      ..denied = true;
    source.duringPrepare = () {
      source.duringPrepare = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    };
    final session = WalkSession(app, source: source);
    final maps = NearbyMaps();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkingPage(controller: app, session: session, maps: maps),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.requests, 1);
    expect(session.error, isNotNull);
    expect(maps.centers, isEmpty);
    final field = find.byType(TextField).first;
    await tester.enterText(field, '공원');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(maps.centers, [null]);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    app.dispose();
    await source.events.close();
    expect(tester.takeException(), isNull);
  });
}
