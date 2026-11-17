import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/features/walking_page.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/map_service.dart';
import 'package:mungcation/services/walk_session.dart';

import 'controller_test.dart' show MemoryRepository;
import 'walk_test.dart' show FakeLocation;

GeoSample position(double latitude, [double longitude = 127]) =>
    GeoSample(latitude, longitude, 5, DateTime.now());

class CapturingMaps implements MapService {
  final requests = <({GeoSample start, PlaceInfo destination})>[];
  bool failHomeRoute = false;
  bool emptyHomeRoute = false;

  @override
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end) async {
    requests.add((start: start, destination: end));
    if (failHomeRoute && end.category == 'start') {
      throw StateError('return route unavailable');
    }
    if (emptyHomeRoute && end.category == 'start') return [];
    final meters = distanceBetween(start, end.location);
    return [
      WalkingRoute(
        '제공 경로',
        meters,
        meters / 1.25,
        [start, end.location],
        ['목적지까지 이동하세요'],
      ),
    ];
  }

  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async => [];

  @override
  Future<void> openPlace(PlaceInfo place) async {}
}

Future<
  ({
    WalkingPageState page,
    WalkSession session,
    CapturingMaps maps,
    GeoSample home,
    PlaceInfo destination,
  })
>
mountWalk(WidgetTester tester, {ThemeData? theme}) async {
  final home = position(37.5);
  final app = AppController(
    MemoryRepository(AppData(pet: const PetProfile(name: '몽이'))),
  );
  await app.load();
  final source = FakeLocation(home);
  final session = WalkSession(app, source: source)..current = home;
  final maps = CapturingMaps();
  final key = GlobalKey<WalkingPageState>();
  final destination = PlaceInfo(
    id: 'park',
    name: '산책 공원',
    address: '',
    category: 'park',
    location: position(37.502),
    fetchedAt: DateTime.now(),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    app.dispose();
    await source.events.close();
  });
  await key.currentState!.routeTo(destination, closeSheet: false);
  await tester.pumpAndSettle();
  return (
    page: key.currentState!,
    session: session,
    maps: maps,
    home: home,
    destination: destination,
  );
}

void main() {
  testWidgets('empty return lookup cannot reverse a moved starting point', (
    tester,
  ) async {
    final walk = await mountWalk(tester);
    walk.session.current = position(37.5007, 127.001);
    walk.maps.emptyHomeRoute = true;
    await walk.page.routeTo(
      walk.destination,
      closeSheet: false,
      rerouting: true,
    );
    await tester.pumpAndSettle();
    expect(walk.page.plannedRoute, isNull);
    expect(walk.page.error, isNotNull);
  });
  testWidgets('clearing a destination cancels a queued reroute', (
    tester,
  ) async {
    final walk = await mountWalk(tester);
    walk.session.status = WalkStatus.recording;
    walk.session.current = position(37.501, 127.002);
    walk.session.changed();
    expect(walk.page.lastReroute, isNotNull);
    walk.page.destination = null;
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(walk.maps.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('outward rerouting returns to the original departure point', (
    tester,
  ) async {
    final walk = await mountWalk(tester);
    expect(walk.maps.requests, hasLength(2));
    final moved = position(37.5007, 127.001);
    walk.session.current = moved;

    await walk.page.routeTo(
      walk.destination,
      closeSheet: false,
      rerouting: true,
    );
    await tester.pumpAndSettle();

    expect(walk.maps.requests, hasLength(4));
    expect(walk.maps.requests[2].start, same(moved));
    expect(walk.maps.requests[2].destination.id, walk.destination.id);
    final returning = walk.maps.requests[3];
    expect(returning.start.latitude, walk.destination.location.latitude);
    expect(returning.destination.location.latitude, walk.home.latitude);
    expect(returning.destination.location.longitude, walk.home.longitude);
    expect(walk.page.plannedRoute!.samples.last.latitude, walk.home.latitude);
    expect(tester.takeException(), isNull);
  });

  testWidgets('departing the return leg reroutes directly to original home', (
    tester,
  ) async {
    final walk = await mountWalk(tester);
    walk.session.status = WalkStatus.recording;
    walk.session.current = walk.destination.location;
    walk.session.changed();
    expect(walk.page.returningHome, true);
    await tester.pumpAndSettle();
    walk.session.current = position(37.501, 127.002);

    expect(
      walk.page.navigator!.update(walk.session.current!).offRoute,
      true,
      reason: 'The simulated position must be over 60m from the return path.',
    );
    walk.session.changed();
    expect(
      walk.page.lastReroute,
      isNotNull,
      reason: 'A GPS notification must schedule a reroute when off route.',
    );
    await tester.pumpAndSettle();

    expect(walk.maps.requests, hasLength(3));
    final rerouted = walk.maps.requests.last;
    expect(rerouted.destination.location.latitude, walk.home.latitude);
    expect(rerouted.destination.location.longitude, walk.home.longitude);
    expect(walk.page.routeIsReturnOnly, true);
    expect(walk.page.plannedRoute!.samples.last.latitude, walk.home.latitude);
    expect(walk.page.plannedRoute!.samples.first.longitude, 127.002);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed return lookup during reroute does not invent a new home',
    (tester) async {
      final walk = await mountWalk(tester);
      walk.session.current = position(37.5007, 127.001);
      walk.maps.failHomeRoute = true;

      await walk.page.routeTo(
        walk.destination,
        closeSheet: false,
        rerouting: true,
      );
      await tester.pumpAndSettle();

      expect(walk.page.error, isNotNull);
      expect(walk.page.plannedRoute, isNull);
      expect(walk.page.routeOrigin!.latitude, walk.home.latitude);
      expect(
        walk.maps.requests.last.destination.location.latitude,
        walk.home.latitude,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
