import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/local_repository.dart';
import 'package:mungcation/services/location_source.dart';
import 'package:mungcation/services/map_service.dart';
import 'package:mungcation/services/walk_session.dart';
import 'controller_test.dart' show MemoryRepository;

class FakeLocation implements LocationSource {
  GeoSample fix;
  bool denied = false;
  final events = StreamController<GeoSample>.broadcast(sync: true);
  FakeLocation(this.fix);
  @override
  Future<GeoSample> prepare({required bool background}) async {
    if (denied) throw const LocationFailure('위치 권한이 필요해요.');
    return fix;
  }

  @override
  Stream<GeoSample> watch({required bool background}) => events.stream;
  @override
  Future<bool> settings() async => true;
}

List<GeoSample> walkingSamples(DateTime start) => List.generate(
  13,
  (i) => GeoSample(
    37 + i * .0001,
    127,
    5,
    start.add(Duration(seconds: i * 10)),
    breakBefore: i == 0,
  ),
);
WalkDraft makeDraft(
  String id,
  DateTime start, {
  List<Visit> visits = const [],
  int seconds = 120,
}) => WalkDraft(
  id: id,
  startedAt: start,
  seconds: seconds,
  samples: walkingSamples(start),
  visits: visits,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('manual location reports whether a fresh fix was received', () async {
    final now = DateTime(2026, 11, 16, 10);
    final source = FakeLocation(GeoSample(37.5, 127, 8, now));
    final app = AppController(MemoryRepository());
    await app.load();
    final session = WalkSession(app, source: source, now: () => now);
    expect(await session.locate(), true);
    expect(session.current?.accuracy, 8);
    source.denied = true;
    expect(await session.locate(), false);
    expect(session.error, isNotNull);
    session.dispose();
    app.dispose();
    await source.events.close();
  });

  test(
    'GPS rejects stale, mock, imprecise, duplicate, jitter and teleport samples',
    () async {
      var now = DateTime(2026, 11, 12, 10);
      final source = FakeLocation(GeoSample(37, 127, 5, now));
      final app = AppController(MemoryRepository());
      await app.load();
      final session = WalkSession(app, source: source, now: () => now);
      expect(await session.start(), true);
      expect(session.samples.length, 1);
      expect(
        session.accept(
          GeoSample(37.001, 127, 5, now.subtract(const Duration(minutes: 1))),
        ),
        false,
      );
      now = now.add(const Duration(seconds: 10));
      expect(session.accept(GeoSample(37.0001, 127, 50, now)), false);
      expect(
        session.accept(GeoSample(37.0001, 127, 5, now, mocked: true)),
        false,
      );
      expect(session.accept(GeoSample(38, 127, 5, now)), false);
      expect(session.accept(GeoSample(37.000001, 127, 5, now)), false);
      expect(session.accept(GeoSample(37.0001, 127, 5, now)), true);
      expect(session.meters, inExclusiveRange(10, 12));
      expect(session.accept(GeoSample(37.0002, 127, 5, now)), false);
      await session.pause();
      session.dispose();
      app.dispose();
      await source.events.close();
    },
  );
  test('pause and recovery never connect distant positions', () async {
    var now = DateTime(2026, 11, 12, 10);
    final source = FakeLocation(GeoSample(37, 127, 5, now));
    final repo = MemoryRepository();
    final app = AppController(repo);
    await app.load();
    final session = WalkSession(app, source: source, now: () => now);
    await session.start();
    now = now.add(const Duration(seconds: 10));
    session.accept(GeoSample(37.0001, 127, 5, now));
    final meters = session.meters;
    await session.pause();
    source.fix = GeoSample(
      37.1,
      127,
      5,
      now = now.add(const Duration(minutes: 5)),
    );
    await session.resume();
    expect(session.samples.last.breakBefore, true);
    expect(session.meters, closeTo(meters, .01));
    await session.pause();
    session.dispose();
    final restored = AppController(repo);
    await restored.load();
    final recovered = WalkSession(restored, source: source, now: () => now);
    recovered.recover();
    expect(recovered.status, WalkStatus.paused);
    expect(recovered.meters, closeTo(meters, .01));
    recovered.dispose();
    app.dispose();
    restored.dispose();
    await source.events.close();
  });
  test(
    'visit rewards require dwell and fresh accurate GPS, not taps',
    () async {
      var now = DateTime(2026, 11, 12, 10);
      final source = FakeLocation(GeoSample(37, 127, 5, now));
      final app = AppController(MemoryRepository());
      await app.load();
      final session = WalkSession(app, source: source, now: () => now);
      final park = PlaceInfo(
        id: 'park',
        name: '공원',
        address: '',
        category: 'park',
        location: source.fix,
        fetchedAt: now,
      );
      session.places = [park];
      await session.start();
      expect(session.visits, isEmpty);
      now = now.add(const Duration(seconds: 11));
      session.accept(GeoSample(37, 127, 5, now));
      expect(session.visits.length, 1);
      now = now.add(const Duration(seconds: 11));
      session.accept(GeoSample(37, 127, 5, now));
      expect(session.visits.length, 1);
      await session.pause();
      session.dispose();
      app.dispose();
      await source.events.close();
    },
  );
  test(
    'permission refusal and foreground lifecycle stop recording safely',
    () async {
      final source = FakeLocation(GeoSample(37, 127, 5, DateTime.now()))
        ..denied = true;
      final app = AppController(MemoryRepository());
      await app.load();
      final session = WalkSession(app, source: source);
      expect(await session.start(), false);
      expect(session.hasWalk, false);
      expect(session.error, contains('권한'));
      source.denied = false;
      await session.start();
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(session.status, WalkStatus.paused);
      session.dispose();
      app.dispose();
      await source.events.close();
    },
  );
  test(
    'completion is idempotent and daily visit ledger survives history deletion',
    () async {
      final now = DateTime(2026, 11, 12, 10);
      final app = AppController(MemoryRepository());
      await app.load();
      final draft = makeDraft(
        'one',
        now,
        visits: [Visit('park', '공원', now, 30)],
      );
      final first = await app.finishWalk(
        draft,
        now.add(const Duration(minutes: 2)),
      );
      expect(first!.points, 50);
      expect(app.data.xp, 20);
      await app.finishWalk(draft, now.add(const Duration(minutes: 2)));
      expect(app.data.coins, 70);
      expect(app.data.realWalks.length, 1);
      await app.deleteWalk('one');
      final second = await app.finishWalk(
        makeDraft('two', now, visits: [Visit('park', '공원', now, 30)]),
        now,
      );
      expect(second!.points, 20);
      expect(second.visits, isEmpty);
      expect(app.data.rewardedPlaces['park'], RewardPolicy.day(now));
    },
  );
  test('daily cap and minimum distance prevent unlimited rewards', () async {
    final now = DateTime(2026, 11, 12, 10);
    final app = AppController(MemoryRepository());
    await app.load();
    final short = await app.finishWalk(
      makeDraft('short', now, seconds: 20),
      now,
    );
    expect(short!.points, 0);
    expect(short.xp, 0);
    for (var i = 0; i < 8; i++) {
      await app.finishWalk(
        makeDraft('walk$i', now, visits: [Visit('park$i', '공원', now, 30)]),
        now,
      );
    }
    expect(app.data.dailyRewards[RewardPolicy.day(now)], 120);
    expect(app.data.coins, 140);
    final capped = await app.finishWalk(makeDraft('cap', now), now);
    expect(capped!.points, 0);
    expect(capped.xp, 0);
  });
  test('concurrent checkpoint and purchase keep both changes', () async {
    final app = AppController(MemoryRepository(AppData(coins: 100)));
    await app.load();
    final purchase = app.purchase('cap', '모자', 50);
    final draft = makeDraft('draft', DateTime(2026, 11, 12));
    await Future.wait([purchase, app.checkpoint(draft)]);
    expect(app.data.coins, 50);
    expect(app.data.equipment, contains('cap'));
    expect(app.data.draft!.id, 'draft');
  });
  test('multi-slot equipment and level locks are enforced', () async {
    final app = AppController(MemoryRepository(AppData(coins: 500)));
    await app.load();
    expect(await app.purchase('crown', '왕관', 100), false);
    await app.purchase('cap', '모자', 50);
    await app.purchase('ribbon', '리본', 30);
    expect(app.data.equipment, containsAll(['cap', 'ribbon']));
    await app.update((d) => d.copyWith(xp: 100));
    expect(await app.purchase('crown', '왕관', 100), true);
    expect(app.data.equipment, containsAll(['crown', 'ribbon']));
    expect(app.data.equipment, isNot(contains('cap')));
  });
  test('version one data migrates without losing the wallet', () {
    final json = AppData(coins: 70, owned: {'cap'}, equipped: 'cap').toJson()
      ..['version'] = 1
      ..remove('equipment')
      ..remove('realWalks')
      ..remove('xp');
    final restored = AppData.fromJson(json);
    expect(restored.coins, 70);
    expect(restored.equipment, {'cap'});
    expect(restored.realWalks, isEmpty);
  });
  test(
    'real file store roundtrips and deletes all route coordinates',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'mungcation_repository_',
      );
      try {
        final repo = LocalRepository(directory: dir);
        final app = AppController(repo);
        await app.load();
        await app.finishWalk(
          makeDraft('saved', DateTime(2026, 11, 12)),
          DateTime(2026, 11, 12),
        );
        final restored = await repo.load();
        expect(restored.realWalks.single.samples.length, 13);
        await app.deleteAllLocationData();
        final raw = await (await repo.file).readAsString();
        expect(raw, isNot(contains('"lat":')));
        expect((await repo.load()).realWalks, isEmpty);
        expect(await File('${(await repo.file).path}.pending').exists(), false);
      } finally {
        if (!dir.absolute.path.startsWith(Directory.systemTemp.absolute.path))
          throw StateError('unexpected temporary directory');
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'safety evaluator excludes forbidden roads and preserves unknown status',
    () {
      final unknown = evaluateSafety([
        const SafetySegment(100, true, SidewalkStatus.unknown),
      ]);
      expect(unknown.permitted, true);
      expect(unknown.knownFraction, 0);
      final forbidden = evaluateSafety([
        const SafetySegment(100, false, SidewalkStatus.confirmed),
      ]);
      expect(forbidden.permitted, false);
      final absent = evaluateSafety([
        const SafetySegment(100, true, SidewalkStatus.absent),
      ]);
      expect(absent.score, greaterThan(unknown.score));
      expect(absent.knownFraction, 1);
    },
  );
}
