import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/map_service.dart';
import 'package:mungcation/services/media_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'photo filter is local, small and uses managed durable filenames',
    () async {
      final root = await Directory.systemTemp.createTemp('mungcation_media_');
      try {
        final store = MediaStore(root: root);
        final recorder = ui.PictureRecorder();
        final actualCanvas = Canvas(recorder);
        actualCanvas.drawColor(Colors.brown, BlendMode.src);
        final picture = recorder.endRecording(),
            image = await picture.toImage(120, 100);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await (await store.resolve(
          'original.jpg',
        )).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        final filtered = await store.pixelate('original.jpg');
        expect(filtered, startsWith('pixel_'));
        final codec = await ui.instantiateImageCodec(
          await (await store.resolve(filtered)).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, lessThanOrEqualTo(48));
        expect(frame.image.height, lessThanOrEqualTo(48));
        frame.image.dispose();
        codec.dispose();
        await expectLater(
          store.resolve('../outside.png'),
          throwsFormatException,
        );
        await store.removeUnreferenced({filtered});
        expect(await (await store.resolve('original.jpg')).exists(), false);
        expect(await (await store.resolve(filtered)).exists(), true);
        await store.delete(filtered);
        expect(await (await store.resolve(filtered)).exists(), false);
      } finally {
        if (!root.absolute.path.startsWith(Directory.systemTemp.absolute.path))
          throw StateError('unexpected directory');
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'MapKit bridge sends user coordinates and decodes actual source results',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AppleMapService.channel, (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        if (call.method == 'search') {
          expect(args['query'], '공원');
          expect(args['lat'], 37);
          return [
            {
              'id': 'place',
              'name': '검색된 공원',
              'lat': 37.1,
              'lon': 127.1,
              'category': 'park',
              'address': '주소',
            },
          ];
        }
        if (call.method == 'directions') {
          expect(args['endLat'], 37.1);
          return [
            {
              'name': '도보',
              'meters': 110.0,
              'seconds': 120.0,
              'coordinates': [
                {'lat': 37.0, 'lon': 127.0},
                {'lat': 37.1, 'lon': 127.1},
              ],
              'instructions': ['보행로를 따라 이동'],
            },
          ];
        }
        return true;
      });
      try {
        final maps = AppleMapService(),
            start = GeoSample(37, 127, 5, DateTime.now());
        final places = await maps.search('공원', start);
        expect(places.single.rewardEligible, true);
        final routes = await maps.directions(start, places.single);
        expect(routes.single.samples.length, 2);
        expect(routes.single.meters, 110);
        await maps.openPlace(places.single);
      } finally {
        messenger.setMockMethodCallHandler(AppleMapService.channel, null);
      }
    },
  );
}
