// Manual visual QA: set MUNGCATION_RENDER_DIR and run this file explicitly.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/core/ui.dart';
import 'package:mungcation/features/android_map_settings_page.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'android_services_test.dart' show MemoryMapSettings;

void main() {
  testWidgets('render VWorld settings at mobile widths', (tester) async {
    final destination = Platform.environment['MUNGCATION_RENDER_DIR'];
    if (destination == null) throw StateError('Set MUNGCATION_RENDER_DIR');
    for (final family in ['Preview', 'Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/malgun.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = AndroidMapConfiguration(
      store: MemoryMapSettings(),
      vworldKey: 'preview-key-12345',
    );
    final theme = mungcationTheme();
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      final frame = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Preview'),
          ),
          home: RepaintBoundary(
            key: frame,
            child: AndroidMapSettingsPage(configuration: config),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory(destination).create(recursive: true);
        await File(
          '$destination/vworld-settings-${width.toInt()}.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    config.dispose();
  });
}
