import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/app_data.dart';
import '../models/catalog.dart';
import '../models/walk_data.dart';
import 'app_controller.dart';
import 'file_transfer.dart';
import 'media_store.dart';

class BackupPackage {
  final AppData data;
  final Map<String, Uint8List> media;
  final DateTime createdAt;
  BackupPackage(this.data, Map<String, Uint8List> media, this.createdAt)
    : media = Map.unmodifiable(media);
}

class BackupService {
  static const maxBytes = 32 * 1024 * 1024;
  final MediaStore media;
  final FileTransfer transfer;
  final Directory? temporaryRoot;
  BackupService({MediaStore? media, FileTransfer? transfer, this.temporaryRoot})
    : media = media ?? MediaStore.instance,
      transfer = transfer ?? PlatformFileTransfer();
  static Set<String> photoNames(AppData data) => {
    if (data.pet?.photo.isNotEmpty == true) data.pet!.photo,
    if (data.pet?.pixelPhoto.isNotEmpty == true) data.pet!.pixelPhoto,
  };
  static void validate(AppData data) {
    final pet = data.pet;
    if (pet == null ||
        pet.name.trim().isEmpty ||
        pet.name.length > 20 ||
        pet.breed.length > 40 ||
        pet.age < 0 ||
        pet.age > 40 ||
        !pet.weight.isFinite ||
        pet.weight < 0 ||
        pet.weight > 150 ||
        !['소형견', '중형견', '대형견'].contains(pet.size) ||
        !['느긋함', '보통', '활발함'].contains(pet.temperament) ||
        !['original', 'brown', 'cream', 'black'].contains(pet.character))
      throw const FormatException('반려견 정보가 올바르지 않아요.');
    if (data.coins < 0 || data.xp < 0 || data.draft != null)
      throw const FormatException('완료된 기록만 담긴 백업이 필요해요.');
    final known = {
      'none',
      ...cosmetics.map((i) => i.id),
      ...furnitureCatalog.map((i) => i.id),
    };
    if (!known.containsAll(data.owned) ||
        !data.owned.containsAll(data.equipment) ||
        data.equipment.any((id) => !cosmetics.any((item) => item.id == id)) ||
        data.equipment.map(slotFor).toSet().length != data.equipment.length)
      throw const FormatException('아이템 정보가 올바르지 않아요.');
    for (final entry in data.furniture.entries) {
      if (!data.owned.contains(entry.key) ||
          !furnitureCatalog.any((i) => i.id == entry.key) ||
          entry.value.length != 2 ||
          entry.value.any((n) => !n.isFinite || n < 0 || n > 1))
        throw const FormatException('가구 배치 정보가 올바르지 않아요.');
    }
    final ids = <String>{};
    for (final walk in data.realWalks) {
      if (walk.id.isEmpty ||
          !ids.add(walk.id) ||
          walk.seconds < 0 ||
          walk.points < 0 ||
          walk.xp < 0 ||
          walk.samples.any((p) => !p.valid || p.mocked))
        throw const FormatException('산책 기록이 올바르지 않아요.');
    }
    for (final name in photoNames(data)) {
      if (!RegExp(r'^[a-zA-Z0-9_-]+\.(jpg|png|jpeg)$').hasMatch(name))
        throw const FormatException('사진 파일 이름이 올바르지 않아요.');
    }
  }

  Future<Uint8List> encode(AppData data) async {
    validate(data);
    final photos = <String, String>{};
    for (final name in photoNames(data)) {
      final file = await media.resolve(name);
      if (!await file.exists())
        throw const FormatException(
          '등록된 사진 파일을 찾지 못했어요. 사진을 다시 등록하거나 삭제한 뒤 백업해 주세요.',
        );
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024)
        throw const FormatException('사진 파일 크기가 올바르지 않아요.');
      await MediaStore.validateImage(bytes);
      photos[name] = base64Encode(bytes);
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'mungcation-backup',
          'version': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'data': data.toJson(),
          'media': photos,
        }),
      ),
    );
    if (bytes.length > maxBytes)
      throw const FormatException('백업 파일은 32MB까지 지원해요. 개별 산책은 GPX로 내보낼 수 있어요.');
    return bytes;
  }

  BackupPackage decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes)
      throw const FormatException('32MB 이하의 멍케이션 백업을 선택해 주세요.');
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map ||
        json['format'] != 'mungcation-backup' ||
        json['version'] != 1)
      throw const FormatException('지원하는 멍케이션 백업 파일이 아니에요.');
    final data = AppData.fromJson(
      Map<String, dynamic>.from(json['data'] as Map),
    );
    validate(data);
    final names = photoNames(data),
        raw = Map<String, dynamic>.from(json['media'] as Map);
    if (raw.length != names.length || !names.containsAll(raw.keys))
      throw const FormatException('백업의 사진 정보가 일치하지 않아요.');
    final photos = <String, Uint8List>{};
    for (final entry in raw.entries) {
      final photo = base64Decode(entry.value as String);
      if (photo.isEmpty || photo.length > 15 * 1024 * 1024)
        throw const FormatException('사진 파일 크기가 올바르지 않아요.');
      photos[entry.key] = photo;
    }
    return BackupPackage(
      data,
      photos,
      DateTime.parse(json['createdAt'] as String),
    );
  }

  Future<void> restore(BackupPackage backup, AppController app) async {
    validate(backup.data);
    final expected = photoNames(backup.data);
    if (expected.length != backup.media.length ||
        !expected.containsAll(backup.media.keys) ||
        backup.media.values.any(
          (bytes) => bytes.isEmpty || bytes.length > 15 * 1024 * 1024,
        ))
      throw const FormatException('백업의 사진 정보가 올바르지 않아요.');
    if (app.busy || app.data.draft != null)
      throw const FormatException('진행 중인 산책을 종료하고 다시 시도해 주세요.');
    final staged = <String>[], mapping = <String, String>{};
    var committed = false;
    try {
      for (final entry in backup.media.entries) {
        await MediaStore.validateImage(entry.value);
        final extension = entry.key.split('.').last;
        final name =
            'restored_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.$extension';
        staged.add(name);
        await (await media.resolve(
          name,
        )).writeAsBytes(entry.value, flush: true);
        mapping[entry.key] = name;
      }
      final p = backup.data.pet!;
      final replacement = backup.data.copyWith(
        pet: p.copyWith(
          photo: mapping[p.photo] ?? '',
          pixelPhoto: mapping[p.pixelPhoto] ?? '',
        ),
        backgroundLocation: false,
        clearDraft: true,
      );
      final saved = await app.restoreData(replacement);
      if (!saved) throw StateError('backup restore unavailable');
      committed = true;
    } finally {
      if (committed) {
        try {
          await media.removeUnreferenced(photoNames(app.data));
        } catch (_) {}
      } else {
        for (final name in staged) {
          try {
            await media.delete(name);
          } catch (_) {}
        }
      }
    }
  }

  Future<bool> shareBackup(AppData data) async => _share(
    await encode(data),
    'mungcation_backup_${DateTime.now().microsecondsSinceEpoch}.json',
  );
  Future<bool> shareWalk(WalkRecord record, String petName) async => _share(
    Uint8List.fromList(utf8.encode(walkGpx(record, petName))),
    'mungcation_walk_${DateTime.now().microsecondsSinceEpoch}.gpx',
  );
  Future<bool> _share(Uint8List bytes, String filename) async {
    final root = temporaryRoot ?? await getTemporaryDirectory();
    final dir = Directory('${root.path}/mungcation_exports');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$filename');
    try {
      await file.writeAsBytes(bytes, flush: true);
      return await transfer.share(file);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}

String xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
String walkGpx(WalkRecord record, String petName) {
  final output = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>\n<gpx version="1.1" creator="Mungcation" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>${xmlEscape(petName)} 산책</name>',
  );
  var segment = false;
  for (final sample in record.samples) {
    if (!sample.valid || sample.mocked)
      throw const FormatException('내보낼 경로가 올바르지 않아요.');
    if (!segment || sample.breakBefore) {
      if (segment) output.write('</trkseg>');
      output.write('<trkseg>');
      segment = true;
    }
    output.write(
      '<trkpt lat="${sample.latitude}" lon="${sample.longitude}"><time>${sample.time.toUtc().toIso8601String()}</time></trkpt>',
    );
  }
  if (segment) output.write('</trkseg>');
  output.write('</trk></gpx>');
  return output.toString();
}
