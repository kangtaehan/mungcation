// Manual visual QA: set MUNGCATION_RENDER_DIR and run this file explicitly.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/core/ui.dart';
import 'package:mungcation/main.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'package:mungcation/widgets/android_walk_map.dart';
import 'package:mungcation/widgets/map_explorer_layout.dart';
import 'android_map_widget_test.dart' show MemoryTiles;
import 'android_services_test.dart' show MemoryMapSettings;
import 'controller_test.dart' show MemoryRepository;
import 'walking_reroute_test.dart' show mountWalk;

void main() {
  testWidgets('render actual home and map surfaces for visual inspection', (
    tester,
  ) async {
    final destination = Platform.environment['MUNGCATION_RENDER_DIR'];
    if (destination == null) throw StateError('Set MUNGCATION_RENDER_DIR');
    final fontFile = File('C:/Windows/Fonts/malgun.ttf');
    if (fontFile.existsSync()) {
      for (final family in ['DesignPreview', 'Roboto', 'Ahem']) {
        final font = FontLoader(family)
          ..addFont(
            Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
          );
        await font.load();
      }
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final theme = mungcationTheme();
    final previewTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'DesignPreview'),
    );
    final frame = GlobalKey();
    Future<void> capture(String name) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final boundary =
          frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory(destination).create(recursive: true);
        await File(
          '$destination/$name.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(390, 844);
    final walk = await mountWalk(tester, theme: previewTheme);
    final layout = tester.widget<MapExplorerLayout>(
      find.byType(MapExplorerLayout),
    );
    final original = tester.widget<MaterialApp>(find.byType(MaterialApp));
    // A schematic fixture tile keeps visual QA deterministic and offline.
    final recorder = ui.PictureRecorder();
    final tileCanvas = Canvas(recorder);
    tileCanvas.drawColor(const Color(0xFFF1F2ED), BlendMode.src);
    tileCanvas.drawRect(
      const Rect.fromLTWH(10, 20, 110, 110),
      Paint()..color = const Color(0xFFDDEACF),
    );
    for (var i = 0; i < 256; i += 64) {
      tileCanvas.drawRect(
        Rect.fromLTWH(i.toDouble(), 0, 13, 256),
        Paint()..color = Colors.white,
      );
      tileCanvas.drawRect(
        Rect.fromLTWH(0, i.toDouble(), 256, 13),
        Paint()..color = Colors.white,
      );
    }
    final recorded = recorder.endRecording();
    final bytes = (await tester.runAsync(() async {
      final tile = await recorded.toImage(256, 256);
      final bytes = (await tile.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      tile.dispose();
      return bytes;
    }))!;
    final config = AndroidMapConfiguration(store: MemoryMapSettings());
    for (final width in [390.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: previewTheme,
          home: Stack(
            children: [
              Offstage(child: original.home),
              RepaintBoundary(
                key: frame,
                child: Scaffold(
                  body: MapExplorerLayout(
                    map: AndroidWalkMap(
                      showBadge: false,
                      configuration: config,
                      tileProvider: MemoryTiles(bytes),
                      current: walk.home,
                      places: [walk.destination],
                      route: [walk.home, walk.destination.location],
                    ),
                    search: layout.search,
                    filters: layout.filters,
                    children: layout.children,
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: 1,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        label: '홈',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.map_outlined),
                        label: '지도',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.storefront_outlined),
                        label: '상점',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: '마이',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(bytes),
          tester.element(find.byType(AndroidWalkMap).last),
        ),
      );
      await capture('map-${width.toInt()}');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    config.dispose();
    recorded.dispose();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MungcationApp(
          repository: MemoryRepository(
            AppData(pet: const PetProfile(name: '몽이')),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/pixel_room.png'),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await capture('home-390');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
