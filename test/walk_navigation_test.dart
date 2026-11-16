import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/walk_navigation.dart';

GeoSample point(double latitude) => GeoSample(latitude, 127, 5, DateTime(2026));

void main() {
  test('round trip combines a distinct return route', () {
    final out = WalkingRoute(
      '가는 길',
      100,
      80,
      [point(37), point(37.001)],
      ['직진'],
      source: 'test',
    );
    final back = WalkingRoute(
      '오는 길',
      120,
      100,
      [point(37.001), point(37.0005), point(37)],
      ['공원길'],
    );
    final combined = roundTripRoute(out, returning: back);
    expect(combined.meters, 220);
    expect(combined.seconds, 180);
    expect(combined.samples.length, 4);
    expect(combined.instructions, contains('공원길'));
  });

  test('round trip reverses outbound when return route is unavailable', () {
    final out = WalkingRoute(
      '가는 길',
      100,
      80,
      [point(37), point(37.001)],
      ['직진'],
    );
    final combined = roundTripRoute(out);
    expect(combined.meters, 200);
    expect(combined.samples.last.latitude, 37);
    expect(combined.source, contains('같은 길'));
  });

  test('navigation reports remaining distance and route departure', () {
    final route = WalkingRoute(
      '왕복',
      222,
      180,
      [point(37), point(37.001), point(37.002)],
      ['출발', '도착'],
    );
    final onRoute = navigationGuidance(route, point(37.001));
    expect(onRoute.offRoute, false);
    expect(onRoute.remainingMeters, greaterThan(100));
    final away = navigationGuidance(route, point(37.01));
    expect(away.offRoute, true);
  });
}
