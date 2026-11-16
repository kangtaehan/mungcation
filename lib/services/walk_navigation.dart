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
          outbound.instructions.reversed.map((step) => '귀환 · $step')),
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

WalkGuidance navigationGuidance(WalkingRoute route, GeoSample current) {
  if (route.samples.isEmpty) {
    return const WalkGuidance(
      remainingMeters: 0,
      remainingSeconds: 0,
      instruction: '경로 정보를 확인하는 중이에요.',
      offRoute: false,
    );
  }
  var nearest = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < route.samples.length; i++) {
    final distance = distanceBetween(current, route.samples[i]);
    if (distance < nearestDistance) {
      nearest = i;
      nearestDistance = distance;
    }
  }
  var remaining = 0.0;
  for (var i = nearest + 1; i < route.samples.length; i++) {
    remaining += distanceBetween(route.samples[i - 1], route.samples[i]);
  }
  final fraction = route.samples.length < 2
      ? 1.0
      : nearest / (route.samples.length - 1);
  final instructionIndex = route.instructions.isEmpty
      ? 0
      : (fraction * route.instructions.length).floor().clamp(
          0,
          route.instructions.length - 1,
        );
  return WalkGuidance(
    remainingMeters: remaining,
    remainingSeconds: route.meters <= 0
        ? 0
        : (route.seconds * remaining / route.meters).round(),
    instruction: route.instructions.isEmpty
        ? '표시된 산책 경로를 따라 이동하세요.'
        : route.instructions[instructionIndex],
    offRoute: nearestDistance > 60,
  );
}
