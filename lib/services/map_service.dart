import 'package:flutter/services.dart';
import '../models/walk_data.dart';

abstract interface class MapService {
  Future<List<PlaceInfo>> search(String query, GeoSample? center);
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end);
  Future<void> openPlace(PlaceInfo place);
}

class AppleMapService implements MapService {
  static const channel = MethodChannel('mungcation/maps');
  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    final items = await channel
        .invokeListMethod<dynamic>('search', {
          'query': query,
          if (center != null) 'lat': center.latitude,
          if (center != null) 'lon': center.longitude,
        })
        .timeout(const Duration(seconds: 25));
    return (items ?? [])
        .map((e) => PlaceInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end) async {
    final items = await channel
        .invokeListMethod<dynamic>('directions', {
          'lat': start.latitude,
          'lon': start.longitude,
          'endLat': end.location.latitude,
          'endLon': end.location.longitude,
        })
        .timeout(const Duration(seconds: 30));
    return (items ?? [])
        .map((e) => WalkingRoute.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.seconds.compareTo(b.seconds));
  }

  @override
  Future<void> openPlace(PlaceInfo place) async {
    await channel.invokeMethod<bool>('openPlace', place.toMap());
  }
}

// Provider-independent evaluation. Production MapKit routes have no sidewalk
// dataset: their status stays unknown and they are never labelled safe.
enum SidewalkStatus { confirmed, absent, unknown }

class SafetySegment {
  final double meters;
  final bool pedestrianAllowed;
  final SidewalkStatus sidewalk;
  const SafetySegment(this.meters, this.pedestrianAllowed, this.sidewalk);
}

class SafetyEvaluation {
  final bool permitted;
  final double score, knownFraction;
  const SafetyEvaluation(this.permitted, this.score, this.knownFraction);
}

SafetyEvaluation evaluateSafety(List<SafetySegment> segments) {
  if (segments.isEmpty)
    return const SafetyEvaluation(false, double.infinity, 0);
  var meters = 0.0, known = 0.0, score = 0.0;
  for (final s in segments) {
    if (!s.pedestrianAllowed || !s.meters.isFinite || s.meters <= 0)
      return const SafetyEvaluation(false, double.infinity, 0);
    meters += s.meters;
    if (s.sidewalk != SidewalkStatus.unknown) known += s.meters;
    score +=
        s.meters *
        switch (s.sidewalk) {
          SidewalkStatus.confirmed => 1,
          SidewalkStatus.absent => 5,
          SidewalkStatus.unknown => 2.5,
        };
  }
  return SafetyEvaluation(true, score, known / meters);
}
