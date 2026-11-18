import 'dart:io';
import 'package:flutter/foundation.dart';
import 'android_map_configuration.dart';
import 'android_map_service.dart';
import 'map_service.dart';

/// Opens an HTTPS data-source link using the current platform's link handler.
Future<void> openSourceLink(String value) async {
  AndroidMapEndpoints.https(value);
  if (kIsWeb || Platform.isAndroid) return AndroidMapService.openLink(value);
  if (Platform.isIOS &&
      await AppleMapService.channel.invokeMethod<bool>('openUrl', {
            'url': value,
          }) ==
          true)
    return;
  throw const MapServiceFailure('원문 링크를 열지 못했어요.');
}
