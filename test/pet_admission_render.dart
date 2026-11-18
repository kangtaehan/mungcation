// Manual visual QA: run explicitly with MUNGCATION_RENDER_DIR set.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/core/ui.dart';
import 'package:mungcation/services/pet_place_catalog.dart';
import 'package:mungcation/widgets/pet_admission_panel.dart';

void main() {
  testWidgets('render sourced retail admission details', (tester) async {
    final destination = Platform.environment['MUNGCATION_RENDER_DIR'];
    if (destination == null) throw StateError('Set MUNGCATION_RENDER_DIR');
    for (final family in ['Preview', 'Ahem', 'Roboto']) {
      final font = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/Windows/Fonts/malgun.ttf').readAsBytesSync(),
            ),
          ),
        );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final catalog = (await tester.runAsync(PetPlaceCatalog.load))!;
    final place = catalog.places.firstWhere(
      (p) => p.category == 'shopping' && p.name.contains('동탄'),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: theme.textTheme.headlineSmall),
                  Text(place.address),
                  const SizedBox(height: 12),
                  PetAdmissionPanel(policy: place.admission),
                ],
              ),
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
        '$destination/pet-admission-dongtan.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  });
}
