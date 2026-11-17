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

  test('same-road round trip progresses through the return leg to home', () {
    final home = point(37);
    final midpoint = point(37.001);
    final destination = point(37.002);
    final outbound = WalkingRoute(
      '같은 길 왕복',
      222,
      180,
      [home, midpoint, destination],
      ['출발', '목적지'],
    );
    final navigator = WalkNavigator(roundTripRoute(outbound), origin: home);

    final start = navigator.update(home);
    final going = navigator.update(midpoint);
    final turning = navigator.update(destination);
    final returning = navigator.update(midpoint);
    final arrived = navigator.update(home);

    expect(start.remainingMeters, greaterThan(400));
    expect(going.remainingMeters, lessThan(start.remainingMeters));
    expect(turning.remainingMeters, lessThan(going.remainingMeters));
    expect(returning.remainingMeters, lessThan(turning.remainingMeters));
    expect(returning.remainingMeters, closeTo(111, 2));
    expect(arrived.remainingMeters, closeTo(0, 1));
    expect(arrived.remainingSeconds, 0);
    expect(arrived.offRoute, false);
  });

  test('rerouting retains the original home instead of the current position', () {
    final home = point(37);
    final destination = point(37.002);
    final route = WalkingRoute(
      '처음 경로',
      444,
      360,
      [home, point(37.001), destination, point(37.001), home],
      ['출발', '귀환'],
    );
    final navigator = WalkNavigator(route, origin: home);
    navigator.update(destination);
    final current = point(37.0015);
    final rerouted = WalkingRoute(
      '재탐색 경로',
      167,
      135,
      [current, point(37.001), home],
      ['집으로 돌아가세요'],
    );

    navigator.replaceRoute(rerouted);
    final guidance = navigator.update(current);

    expect(navigator.origin.latitude, home.latitude);
    expect(navigator.origin.longitude, home.longitude);
    expect(guidance.remainingMeters, greaterThan(150));
    expect(navigator.update(home).remainingMeters, closeTo(0, 1));
  });

  test('a position on a long sparse segment remains on route', () {
    final home = point(37);
    final route = WalkingRoute(
      '긴 직선 구간',
      1112,
      900,
      [home, point(37.01)],
      ['직진'],
    );
    final navigator = WalkNavigator(route, origin: home);

    final halfway = navigator.update(point(37.005));

    expect(halfway.offRoute, false);
    expect(halfway.remainingMeters, closeTo(556, 5));
    expect(halfway.remainingSeconds, closeTo(450, 5));
  });
}
