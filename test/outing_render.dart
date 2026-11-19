// Manual QA: set MUNGCATION_RENDER_DIR, then run this file explicitly.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/core/ui.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/saved_place.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/widgets/outing_checklist.dart';
import 'additional_features_test.dart' show savedFixture;
import 'controller_test.dart' show MemoryRepository;

void main() {
  testWidgets('render actual outing checklist at phone width', (tester) async {
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
    tester.view.physicalSize = const Size(320, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final place = savedFixture();
    final app = AppController(
      MemoryRepository(
        AppData(
          savedPlaces: {
            place.id: SavedPlace(
              place: place,
              preparation: {'water', 'leash'},
              preparedAt: DateTime.now(),
            ),
          },
        ),
      ),
    );
    await app.load();
    final frame = GlobalKey();
    final theme = mungcationTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Preview'),
        ),
        home: RepaintBoundary(
          key: frame,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: OutingChecklist(controller: app, place: place),
            ),
          ),
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
        '$destination/outing-checklist-320.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
