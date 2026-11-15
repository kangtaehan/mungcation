import 'package:flutter/material.dart';

import 'main.dart' show MungcationApp;
import 'services/android_map_configuration.dart';
import 'services/android_map_service.dart';
import 'services/location_source.dart';
import 'services/web_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidMapConfiguration.instance.load();
  runApp(
    MungcationApp(
      repository: WebRepository(),
      locationSource: DeviceLocation(),
      maps: AndroidMapService(),
    ),
  );
}
