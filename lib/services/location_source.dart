import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/walk_data.dart';

abstract interface class LocationSource {
  Future<GeoSample> prepare({required bool background});
  Stream<GeoSample> watch({required bool background});
  Future<bool> settings();
}

class DeviceLocation implements LocationSource {
  @override
  Future<GeoSample> prepare({required bool background}) async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw const LocationFailure('위치 서비스가 꺼져 있어요. 기기 설정에서 켜 주세요.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever)
      throw const LocationFailure('위치 권한이 차단되어 있어요. 설정에서 위치 접근을 허용해 주세요.');
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine)
      throw const LocationFailure('위치 권한이 필요해요. 허용 후 다시 시도해 주세요.');
    if (background && Platform.isAndroid) {
      final enabled = await const MethodChannel(
        'mungcation/android',
      ).invokeMethod<bool>('requestNotifications');
      if (enabled != true)
        throw const LocationFailure(
          '잠금 화면 산책 기록에는 산책 중 알림 표시가 필요해요. 설정에서 알림을 허용하거나 잠금 화면 기록을 꺼 주세요.',
        );
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 25),
      ),
    );
    return convert(p);
  }

  static GeoSample convert(Position p) => GeoSample(
    p.latitude,
    p.longitude,
    p.accuracy,
    p.timestamp,
    mocked: p.isMocked,
  );
  static LocationSettings settingsFor({
    required bool android,
    required bool background,
  }) => android
      ? AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: '멍케이션 산책 기록 중',
                  notificationChannelName: '산책 위치 기록',
                  notificationIcon: AndroidResource(name: 'ic_stat_paw'),
                  notificationText: '산책 경로를 기록하고 있어요. 앱에서 일시정지하거나 종료할 수 있어요.',
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        )
      : AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: background,
          allowBackgroundLocationUpdates: background,
        );
  @override
  Stream<GeoSample> watch({required bool background}) =>
      Geolocator.getPositionStream(
        locationSettings: settingsFor(
          android: Platform.isAndroid,
          background: background,
        ),
      ).map(convert);
  @override
  Future<bool> settings() => Geolocator.openAppSettings();
}

class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);
  @override
  String toString() => message;
}
