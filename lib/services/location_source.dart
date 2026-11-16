import 'dart:io';
import 'package:flutter/foundation.dart';
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
    if (background && !kIsWeb && Platform.isAndroid) {
      final enabled = await const MethodChannel(
        'mungcation/android',
      ).invokeMethod<bool>('requestNotifications');
      if (enabled != true)
        throw const LocationFailure(
          '잠금 화면 산책 기록에는 산책 중 알림 표시가 필요해요. 설정에서 알림을 허용하거나 잠금 화면 기록을 꺼 주세요.',
        );
    }
    final settings = settingsFor(
      android: !kIsWeb && Platform.isAndroid,
      background: false,
    );
    final first = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    );
    if (kIsWeb || first.accuracy <= 20) return convert(first);
    return convert(await _refine(first, settings));
  }

  Future<Position> _refine(Position first, LocationSettings settings) async {
    var best = first;
    final result = Completer<Position>();
    late final StreamSubscription<Position> subscription;
    Timer? timer;
    void complete() {
      if (!result.isCompleted) result.complete(best);
    }

    subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (candidate) {
            if (candidate.accuracy < best.accuracy) best = candidate;
            if (best.accuracy <= 20) complete();
          },
          onError: (_) => complete(),
          onDone: complete,
        );
    timer = Timer(const Duration(seconds: 6), complete);
    try {
      return await result.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
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
  }) => kIsWeb
      ? const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        )
      : android
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
          android: !kIsWeb && Platform.isAndroid,
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
