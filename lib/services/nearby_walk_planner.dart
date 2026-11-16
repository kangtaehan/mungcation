import '../models/walk_data.dart';

class NearbyPlaceSelection {
  final List<PlaceInfo> places;
  final int targetMinutes;
  final bool usedFallback;

  const NearbyPlaceSelection(
    this.places,
    this.targetMinutes, {
    this.usedFallback = false,
  });
}

int nearbyTargetMinutes(String dogSize) => switch (dogSize) {
  '대형견' => 60,
  '중형견' => 45,
  _ => 30,
};

/// Uses a conservative 1.3 road-distance factor and a relaxed walking pace.
/// Exact route time is calculated only after the user chooses a destination.
double estimatedRoundTripMinutes(
  GeoSample current,
  PlaceInfo place, {
  double walkingMetersPerMinute = 75,
}) =>
    distanceBetween(current, place.location) * 2 * 1.3 / walkingMetersPerMinute;

NearbyPlaceSelection selectNearbyWalkPlaces(
  GeoSample current,
  Iterable<PlaceInfo> candidates,
  String dogSize,
) {
  final target = nearbyTargetMinutes(dogSize);
  final ranked =
      candidates
          .where((place) => place.location.valid)
          .map(
            (place) => (
              place: place,
              minutes: estimatedRoundTripMinutes(current, place),
            ),
          )
          .where((item) => item.minutes.isFinite && item.minutes > 0)
          .toList()
        ..sort((a, b) => a.minutes.compareTo(b.minutes));
  final preferred = ranked
      .where((item) => item.minutes <= target)
      .map((item) => item.place)
      .take(30)
      .toList();
  if (preferred.isNotEmpty) {
    return NearbyPlaceSelection(preferred, target);
  }
  return NearbyPlaceSelection(
    (ranked.toList()..sort(
          (a, b) =>
              (a.minutes - target).abs().compareTo((b.minutes - target).abs()),
        ))
        .map((item) => item.place)
        .take(10)
        .toList(),
    target,
    usedFallback: ranked.isNotEmpty,
  );
}
