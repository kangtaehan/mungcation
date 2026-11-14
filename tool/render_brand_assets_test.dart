import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/widgets/pet_room.dart';

void drawIcon(Canvas c, double scale) {
  c.scale(scale / 128);
  void r(double x, double y, double w, double h, Color color) => c.drawRect(
    Rect.fromLTWH(x, y, w, h),
    Paint()
      ..color = color
      ..isAntiAlias = false,
  );
  r(0, 0, 128, 128, const Color(0xFF205C40));
  const dark = Color(0xFF49342A),
      fur = Color(0xFFE8B982),
      cream = Color(0xFFFFE8C7);
  r(34, 33, 60, 68, dark);
  r(40, 29, 48, 72, dark);
  r(24, 39, 18, 51, dark);
  r(86, 39, 18, 51, dark);
  r(40, 36, 48, 59, fur);
  r(30, 44, 11, 39, fur);
  r(87, 44, 11, 39, fur);
  r(42, 39, 20, 47, cream);
  r(45, 54, 8, 10, dark);
  r(75, 54, 8, 10, dark);
  r(58, 72, 14, 10, dark);
  r(53, 87, 23, 4, dark);
  r(92, 23, 9, 7, const Color(0xFFE68A9D));
  r(101, 23, 9, 7, const Color(0xFFE68A9D));
  r(95, 30, 12, 7, const Color(0xFFE68A9D));
  r(99, 37, 4, 4, const Color(0xFFE68A9D));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render app icon sizes', () async {
    final directory = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    final data =
        jsonDecode(await File('${directory.path}/Contents.json').readAsString())
            as Map;
    for (final entry in data['images'] as List) {
      final size =
          (double.parse((entry['size'] as String).split('x').first) *
                  double.parse((entry['scale'] as String).replaceAll('x', '')))
              .round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      drawIcon(canvas, size.toDouble());
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${directory.path}/${entry['filename']}',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
  test('render Android launcher icon densities', () async {
    for (final density in {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    }.entries) {
      final directory = Directory(
        'android/app/src/main/res/mipmap-${density.key}',
      );
      await directory.create(recursive: true);
      for (final asset in {
        'ic_launcher': 48,
        'ic_launcher_foreground': 108,
      }.entries) {
        final size = (asset.value * density.value).round(),
            recorder = ui.PictureRecorder();
        drawIcon(Canvas(recorder), size.toDouble());
        final picture = recorder.endRecording(),
            image = await picture.toImage(size, size);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/${asset.key}.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    }
  });
  test('render launch image variants', () async {
    for (var scale = 1; scale <= 3; scale++) {
      final size = 128 * scale, recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFAF8F4), BlendMode.src);
      canvas.translate(size * .2, size * .2);
      drawIcon(canvas, size * .6);
      final picture = recorder.endRecording(),
          image = await picture.toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final suffix = scale == 1 ? '' : '@${scale}x';
      await File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
  testWidgets('render room and layered accessories for visual QA', (
    tester,
  ) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(869, 515);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const PetRoom(
            equipped: 'cap',
            equipment: {'cap', 'ribbon', 'glasses', 'necklace'},
            name: '몽이',
            character: 'cream',
            furniture: {
              'plant': [.1, .6],
              'bed': [.75, .65],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts').create();
      await File(
        'artifacts/room_preview.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}
