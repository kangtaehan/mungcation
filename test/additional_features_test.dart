import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/saved_place.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/backup_service.dart';
import 'package:mungcation/services/file_transfer.dart';
import 'package:mungcation/services/media_store.dart';
import 'package:mungcation/services/walk_statistics.dart';
import 'controller_test.dart' show MemoryRepository;

class FakeTransfer implements FileTransfer {
  bool complete = true, fail = false;
  String? lastPath;
  Uint8List? lastBytes, picked;
  @override
  Future<Uint8List?> pickBackup() async => picked;
  @override
  Future<bool> share(File file) async {
    lastPath = file.path;
    lastBytes = await file.readAsBytes();
    if (fail) throw StateError('share failed');
    return complete;
  }
}

PlaceInfo savedFixture() => PlaceInfo(
  id: 'park',
  name: '내 공원',
  address: '주소',
  category: 'park',
  location: GeoSample(37, 127, 0, DateTime(2026, 11, 12)),
  fetchedAt: DateTime(2026, 11, 10),
);
WalkRecord historyFixture(String id, DateTime date) => WalkRecord(
  id: id,
  startedAt: date,
  endedAt: date.add(const Duration(minutes: 2)),
  seconds: 120,
  points: 20,
  xp: 20,
  samples: [
    GeoSample(37, 127, 5, date, breakBefore: true),
    GeoSample(37.001, 127, 5, date.add(const Duration(seconds: 60))),
  ],
  visits: [],
);
Future<Directory> scratch() async {
  final dir = await Directory.systemTemp.createTemp('mungcation_features_');
  addTearDown(() async {
    if (!dir.absolute.path.startsWith(Directory.systemTemp.absolute.path))
      throw StateError('invalid temporary root');
    await dir.delete(recursive: true);
  });
  return dir;
}

Future<Uint8List> picture() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.brown, BlendMode.src);
  final p = recorder.endRecording(), image = await p.toImage(4, 4);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
    p.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'saved places persist personal notes and the original fetch date',
    () async {
      final repo = MemoryRepository();
      final c = AppController(repo);
      await c.load();
      final place = savedFixture();
      await c.toggleSavedPlace(place);
      await c.savePlaceNote(place, '실외만, 전화 확인', PetAccess.outdoorOnly);
      final restored = AppController(repo);
      await restored.load();
      final saved = restored.data.savedPlaces['park']!;
      expect(saved.note, '실외만, 전화 확인');
      expect(saved.access, PetAccess.outdoorOnly);
      expect(saved.place.fetchedAt, DateTime(2026, 11, 10));
      expect(saved.notedAt, isNotNull);
      await restored.toggleSavedPlace(place);
      expect((await repo.load()).savedPlaces, isEmpty);
    },
  );
  test('statistics respect inclusive start, exclusive end and active days', () {
    final day = DateTime(2026, 11, 12);
    final stats = WalkStatistics([
      historyFixture('one', day),
      historyFixture('two', day.add(const Duration(hours: 23, minutes: 59))),
      historyFixture('tomorrow', DateTime(2026, 11, 13)),
    ]);
    final selected = stats.onDay(day);
    expect(selected.count, 2);
    expect(selected.seconds, 240);
    expect(selected.activeDays, 1);
    expect(selected.meters, inExclusiveRange(220, 225));
    expect(stats.recentDays(day, 7).last.count, 2);
    expect(stats.recentDays(day, 7).length, 7);
    expect(() => stats.recentDays(day, 0), throwsArgumentError);
  });
  test('GPX preserves pause breaks, UTC times and escaped names', () {
    final date = DateTime(2026, 11, 12);
    final record = WalkRecord(
      id: 'gpx',
      startedAt: date,
      endedAt: date,
      seconds: 1,
      points: 0,
      xp: 0,
      samples: [
        GeoSample(37, 127, 5, date, breakBefore: true),
        GeoSample(37.001, 127, 5, date),
        GeoSample(38, 127, 5, date, breakBefore: true),
      ],
      visits: [],
    );
    final xml = walkGpx(record, '몽이 & <친구>');
    expect(RegExp('<trkseg>').allMatches(xml).length, 2);
    expect(RegExp('<trkpt ').allMatches(xml).length, 3);
    expect(xml, contains('몽이 &amp; &lt;친구&gt;'));
    expect(xml, contains(date.toUtc().toIso8601String()));
    expect(xml, endsWith('</trk></gpx>'));
  });
  test(
    'backup restores photos, records, wallet and favorites with new file names',
    () async {
      final root = await scratch(),
          media = MediaStore(root: root),
          transfer = FakeTransfer(),
          service = BackupService(
            media: MediaStore(root: root),
            transfer: FakeTransfer(),
            temporaryRoot: root,
          );
      final png = await picture();
      await (await media.resolve('source.png')).writeAsBytes(png);
      final initial = AppData(
        pet: const PetProfile(
          name: '몽이',
          photo: 'source.png',
          pixelPhoto: 'source.png',
        ),
        coins: 80,
        xp: 100,
        owned: {'cap'},
        equipment: {'cap'},
        realWalks: [historyFixture('one', DateTime(2026, 11, 12))],
        backgroundLocation: true,
        savedPlaces: {'park': SavedPlace(place: savedFixture(), note: '내 메모')},
      );
      final encoded = await service.encode(initial),
          preview = service.decode(encoded);
      expect(preview.media.length, 1);
      final repo = MemoryRepository(
            AppData(pet: const PetProfile(name: '다른 친구')),
          ),
          app = AppController(repo);
      await app.load();
      await service.restore(preview, app);
      expect(app.data.pet!.name, '몽이');
      expect(app.data.pet!.photo, startsWith('restored_'));
      expect(app.data.pet!.pixelPhoto, app.data.pet!.photo);
      expect(
        await (await media.resolve(app.data.pet!.photo)).readAsBytes(),
        png,
      );
      expect(app.data.coins, 80);
      expect(app.data.savedPlaces['park']!.note, '내 메모');
      expect(app.data.realWalks.length, 1);
      expect(app.data.backgroundLocation, false);
      final check = AppController(repo);
      await check.load();
      expect(check.data.pet!.photo, app.data.pet!.photo);
      expect(transfer.lastPath, isNull);
    },
  );
  test(
    'invalid backups reject extra files, negative wallet and malformed JSON',
    () async {
      final root = await scratch(),
          service = BackupService(
            media: MediaStore(root: root),
            transfer: FakeTransfer(),
            temporaryRoot: root,
          );
      final good = await service.encode(
        AppData(pet: const PetProfile(name: '몽이')),
      );
      Map<String, dynamic> modified() =>
          jsonDecode(utf8.decode(good)) as Map<String, dynamic>;
      final extra = modified();
      extra['media'] = {
        '../outside.png': base64Encode([1]),
      };
      expect(
        () =>
            service.decode(Uint8List.fromList(utf8.encode(jsonEncode(extra)))),
        throwsFormatException,
      );
      final negative = modified();
      negative['data']['coins'] = -10;
      expect(
        () => service.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(negative))),
        ),
        throwsFormatException,
      );
      expect(
        () => service.decode(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(
        () => service.decode(Uint8List(BackupService.maxBytes + 1)),
        throwsFormatException,
      );
    },
  );
  test(
    'restore write failure retains current state and removes staged photos',
    () async {
      final root = await scratch(),
          media = MediaStore(root: root),
          service = BackupService(
            media: MediaStore(root: root),
            transfer: FakeTransfer(),
            temporaryRoot: root,
          ),
          png = await picture();
      await (await media.resolve('current.png')).writeAsBytes(png);
      final repo = MemoryRepository(
            AppData(
              pet: const PetProfile(name: '현재', photo: 'current.png'),
            ),
          ),
          app = AppController(repo);
      await app.load();
      repo.fail = true;
      final incoming = BackupPackage(
        AppData(
          pet: const PetProfile(name: '복원', photo: 'incoming.png'),
        ),
        {'incoming.png': png},
        DateTime.now(),
      );
      await expectLater(service.restore(incoming, app), throwsException);
      expect(app.data.pet!.name, '현재');
      expect(await (await media.resolve('current.png')).exists(), true);
      final files = await (await media.directory).list().toList();
      expect(files.length, 1);
    },
  );
  test('corrupt photos cannot replace the profile', () async {
    final root = await scratch(),
        service = BackupService(
          media: MediaStore(root: root),
          transfer: FakeTransfer(),
          temporaryRoot: root,
        ),
        app = AppController(
          MemoryRepository(AppData(pet: const PetProfile(name: '현재'))),
        );
    await app.load();
    final incoming = BackupPackage(
      AppData(
        pet: const PetProfile(name: '복원', photo: 'incoming.png'),
      ),
      {
        'incoming.png': Uint8List.fromList([1, 2, 3]),
      },
      DateTime.now(),
    );
    await expectLater(service.restore(incoming, app), throwsFormatException);
    expect(app.data.pet!.name, '현재');
  });
  test('a validated backup can recover a corrupt primary store', () async {
    final root = await scratch(),
        service = BackupService(
          media: MediaStore(root: root),
          transfer: FakeTransfer(),
          temporaryRoot: root,
        ),
        repo = MemoryRepository()..raw = 'broken';
    final app = AppController(repo);
    await app.load();
    expect(app.error, isNotNull);
    await service.restore(
      BackupPackage(
        AppData(pet: const PetProfile(name: '복구')),
        {},
        DateTime.now(),
      ),
      app,
    );
    expect(app.error, isNull);
    expect((await repo.load()).pet!.name, '복구');
  });
  test('cancelled and failed exports remove temporary private files', () async {
    final root = await scratch(),
        transfer = FakeTransfer()..complete = false,
        service = BackupService(
          media: MediaStore(root: root),
          transfer: FakeTransfer(),
          temporaryRoot: root,
        );
    final actual = BackupService(
          media: MediaStore(root: root),
          transfer: transfer,
          temporaryRoot: root,
        ),
        data = AppData(pet: const PetProfile(name: '몽이'));
    expect(await actual.shareBackup(data), false);
    expect(await File(transfer.lastPath!).exists(), false);
    expect(service.decode(transfer.lastBytes!).data.pet!.name, '몽이');
    transfer.fail = true;
    await expectLater(
      actual.shareWalk(historyFixture('one', DateTime.now()), '몽이'),
      throwsStateError,
    );
    expect(await File(transfer.lastPath!).exists(), false);
  });
  test('active walk backups and restores are blocked', () async {
    final root = await scratch(),
        service = BackupService(
          media: MediaStore(root: root),
          transfer: FakeTransfer(),
          temporaryRoot: root,
        ),
        data = AppData(
          pet: const PetProfile(name: '몽이'),
          draft: WalkDraft(
            id: 'draft',
            startedAt: DateTime.now(),
            seconds: 0,
            samples: [],
            visits: [],
          ),
        );
    final app = AppController(MemoryRepository(data));
    await app.load();
    await expectLater(service.encode(data), throwsFormatException);
    await expectLater(
      service.restore(
        BackupPackage(
          AppData(pet: const PetProfile(name: '복원')),
          {},
          DateTime.now(),
        ),
        app,
      ),
      throwsFormatException,
    );
    expect(app.data.draft!.id, 'draft');
  });
  test(
    'successful recovery removes unreferenced private photo copies',
    () async {
      final root = await scratch(),
          media = MediaStore(root: root),
          service = BackupService(
            media: MediaStore(root: root),
            transfer: FakeTransfer(),
            temporaryRoot: root,
          );
      await (await media.resolve('orphan.png')).writeAsBytes(await picture());
      final repo = MemoryRepository()..raw = 'corrupt';
      final app = AppController(repo);
      await app.load();
      await service.restore(
        BackupPackage(
          AppData(pet: const PetProfile(name: '복구')),
          {},
          DateTime.now(),
        ),
        app,
      );
      expect(await (await media.directory).list().toList(), isEmpty);
      expect(app.error, isNull);
    },
  );
  test('version two storage gains an empty favorites collection', () {
    final json =
        AppData(pet: const PetProfile(name: '몽이'), coins: 90, xp: 40).toJson()
          ..['version'] = 2
          ..remove('savedPlaces');
    final restored = AppData.fromJson(json);
    expect(restored.coins, 90);
    expect(restored.xp, 40);
    expect(restored.savedPlaces, isEmpty);
  });
}
