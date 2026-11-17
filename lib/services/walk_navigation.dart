import 'dart:math' as math;
import '../models/walk_data.dart';

WalkingRoute roundTripRoute(WalkingRoute outbound, {WalkingRoute? returning}) {
  final back = returning;
  final backSamples = back?.samples ?? outbound.samples.reversed.toList();
  return WalkingRoute(
    '${outbound.name} 왕복',
    outbound.meters + (back?.meters ?? outbound.meters),
    outbound.seconds + (back?.seconds ?? outbound.seconds),
    [...outbound.samples, ...backSamples.skip(backSamples.isEmpty ? 0 : 1)],
    [
      ...outbound.instructions,
      '목적지에서 돌아오는 길을 시작하세요.',
      ...(back?.instructions ??
          ['온 길을 따라 출발 위치로 돌아가세요. 현장 표지와 통행 방향을 확인해 주세요.']),
    ],
    source: back == null ? '${outbound.source} · 같은 길 귀환' : outbound.source,
  );
}

class WalkGuidance {
  final double remainingMeters;
  final int remainingSeconds;
  final String instruction;
  final bool offRoute;

  const WalkGuidance({
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.instruction,
    required this.offRoute,
  });
}

class WalkNavigator {
  WalkingRoute route;
  final GeoSample origin;
  double _progress = 0;
  WalkNavigator(this.route, {required this.origin});

  void replaceRoute(WalkingRoute replacement) {
    route = replacement;
    _progress = 0;
  }

  WalkGuidance update(GeoSample current) {
    if (route.samples.isEmpty) {
      return const WalkGuidance(
        remainingMeters: 0,
        remainingSeconds: 0,
        instruction: '경로 정보를 확인하는 중이에요.',
        offRoute: false,
      );
    }
    var nearestDistance = double.infinity, nearestProgress = _progress;
    var total = 0.0;
    // Project onto segments rather than vertices. Earlier progress wins ties
    // on overlapping outward/return paths, and completed segments stay behind.
    for (var i = 1; i < route.samples.length; i++) {
      final a = route.samples[i - 1], b = route.samples[i];
      final length = distanceBetween(a, b);
      if (length > 0 && total + length >= _progress) {
        final scale = math.cos(current.latitude * math.pi / 180);
        final dx = (b.longitude - a.longitude) * scale;
        final dy = b.latitude - a.latitude;
        final px = (current.longitude - a.longitude) * scale;
        final py = current.latitude - a.latitude;
        final t = ((px * dx + py * dy) / (dx * dx + dy * dy)).clamp(
          ((_progress - total) / length).clamp(0.0, 1.0),
          1.0,
        );
        final projected = GeoSample(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
          0,
          current.time,
        );
        final distance = distanceBetween(current, projected);
        if (distance < nearestDistance - .01) {
          nearestDistance = distance;
          nearestProgress = total + length * t;
        }
      }
      total += length;
    }
    if (route.samples.length == 1) {
      nearestDistance = distanceBetween(current, route.samples.first);
    }
    final offRoute = nearestDistance > 60;
    if (!offRoute) _progress = nearestProgress;
    final remaining = math.max(0.0, total - _progress);
    final fraction = total == 0 ? 1.0 : _progress / total;
    final instructionIndex = route.instructions.isEmpty
        ? 0
        : (fraction * route.instructions.length).floor().clamp(
            0,
            route.instructions.length - 1,
          );
    return WalkGuidance(
      remainingMeters: remaining,
      remainingSeconds: total <= 0
          ? 0
          : (route.seconds * remaining / total).round(),
      instruction: route.instructions.isEmpty
          ? '표시된 산책 경로를 따라 이동하세요.'
          : route.instructions[instructionIndex],
      offRoute: offRoute,
    );
  }
}

WalkGuidance navigationGuidance(WalkingRoute route, GeoSample current) =>
    WalkNavigator(
      route,
      origin: route.samples.firstOrNull ?? current,
    ).update(current);
