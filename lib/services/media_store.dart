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
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final side = frame.image.width < frame.image.height
            ? frame.image.width
            : frame.image.height;
        final source = ui.Rect.fromLTWH(
          (frame.image.width - side) / 2,
          (frame.image.height - side) / 2,
          side.toDouble(),
          side.toDouble(),
        );
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          frame.image,
          source,
          const ui.Rect.fromLTWH(0, 0, 40, 40),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        final small = await picture.toImage(40, 40);
        picture.dispose();
        try {
          final rgba = await small.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (rgba == null) throw StateError('사진 변환 실패');
          final styled = pixelArtRgba(rgba.buffer.asUint8List());
          final buffer = await ui.ImmutableBuffer.fromUint8List(styled);
          try {
            final descriptor = ui.ImageDescriptor.raw(
              buffer,
              width: 40,
              height: 40,
              pixelFormat: ui.PixelFormat.rgba8888,
            );
            try {
              final styledCodec = await descriptor.instantiateCodec();
              try {
                final styledFrame = await styledCodec.getNextFrame();
                try {
                  final outputRecorder = ui.PictureRecorder();
                  final outputCanvas = ui.Canvas(outputRecorder);
                  outputCanvas.drawColor(
                    const ui.Color(0xFFFFE8C7),
                    ui.BlendMode.src,
                  );
                  outputCanvas.drawImageRect(
                    styledFrame.image,
                    const ui.Rect.fromLTWH(0, 0, 40, 40),
                    const ui.Rect.fromLTWH(0, 0, 320, 320),
                    ui.Paint()..filterQuality = ui.FilterQuality.none,
                  );
                  final outputPicture = outputRecorder.endRecording();
                  final output = await outputPicture.toImage(320, 320);
                  outputPicture.dispose();
                  try {
                    final png = await output.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    if (png == null) throw StateError('사진 변환 실패');
                    return writePng(png.buffer.asUint8List());
                  } finally {
                    output.dispose();
                  }
                } finally {
                  styledFrame.image.dispose();
                }
              } finally {
                styledCodec.dispose();
              }
            } finally {
              descriptor.dispose();
            }
          } finally {
            buffer.dispose();
          }
        } finally {
          small.dispose();
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Adds a small palette and dark pixel edges without sending the photo to a
  /// server. Input and output use RGBA byte order.
  static Uint8List pixelArtRgba(Uint8List source, {int width = 40}) {
    if (source.length % 4 != 0 ||
        width < 1 ||
        source.length ~/ 4 % width != 0) {
      throw const FormatException('RGBA 사진 형식이 아니에요.');
    }
    final output = Uint8List.fromList(source);
    int channel(int value) {
      final contrasted = ((value - 128) * 1.16 + 128).round().clamp(0, 255);
      return ((contrasted / 32).round() * 32).clamp(0, 255).toInt();
    }

    for (var i = 0; i < output.length; i += 4) {
      output[i] = channel(output[i]);
      output[i + 1] = channel(output[i + 1]);
      output[i + 2] = channel(output[i + 2]);
    }
    final height = source.length ~/ 4 ~/ width;
    final shaded = Uint8List.fromList(output);
    int light(int index) =>
        (output[index] * 3 + output[index + 1] * 6 + output[index + 2]) ~/ 10;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final i = (y * width + x) * 4;
        final right = i + 4, below = i + width * 4;
        if ((light(i) - light(right)).abs() > 62 ||
            (light(i) - light(below)).abs() > 62) {
          shaded[i] = (output[i] * .58).round();
          shaded[i + 1] = (output[i + 1] * .58).round();
          shaded[i + 2] = (output[i + 2] * .58).round();
        }
      }
    }
    return shaded;
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
