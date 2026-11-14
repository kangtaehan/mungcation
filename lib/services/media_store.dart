import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class MediaStore {
  static final instance = MediaStore();
  final ImagePicker picker;
  final Directory? root;
  MediaStore({this.root, ImagePicker? picker})
    : picker = picker ?? ImagePicker();
  Future<Directory> get directory async {
    final base = root ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/pet_media');
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> resolve(String name) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.(jpg|png|jpeg)$').hasMatch(name))
      throw const FormatException('잘못된 사진 경로');
    return File('${(await directory).path}/$name');
  }

  static Future<void> validateImage(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width < 1 ||
            descriptor.height < 1 ||
            descriptor.width > 4096 ||
            descriptor.height > 4096)
          throw const FormatException('사진 해상도가 지원 범위를 벗어났어요.');
        final codec = await descriptor.instantiateCodec(
          targetWidth: 48,
          targetHeight: 48,
        );
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } catch (_) {
      throw const FormatException('사진 파일이 손상되었거나 지원하지 않는 형식이에요.');
    } finally {
      buffer.dispose();
    }
  }

  Future<String?> pick(ImageSource source) async {
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    return persistPicked(image);
  }

  Future<String?> recoverLostPhoto() async {
    final response = await picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) throw response.exception!;
    if (response.type == RetrieveType.video) return null;
    final file = response.files?.firstOrNull ?? response.file;
    return file == null ? null : persistPicked(file);
  }

  Future<String> persistPicked(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > 15 * 1024 * 1024)
      throw const FormatException('사진은 15MB 이하로 선택해 주세요.');
    await validateImage(bytes);
    final name = 'pet_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await (await resolve(name)).writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<String> pixelate(String original) async {
    final bytes = await (await resolve(original)).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 48,
      targetHeight: 48,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) throw StateError('사진 변환 실패');
        return writePng(png.buffer.asUint8List());
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<String> writePng(Uint8List bytes) async {
    final name = 'pixel_${DateTime.now().microsecondsSinceEpoch}.png';
    await (await resolve(name)).writeAsBytes(bytes, flush: true);
    return name;
  }

  Future<void> delete(String name) async {
    if (name.isEmpty) return;
    final file = await resolve(name);
    if (await file.exists()) await file.delete();
  }

  Future<void> removeUnreferenced(Set<String> retained) async {
    final dir = await directory;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (!retained.contains(name)) await entity.delete();
      }
    }
  }
}
