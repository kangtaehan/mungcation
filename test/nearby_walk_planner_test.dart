import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/nearby_walk_planner.dart';

PlaceInfo place(String id, double latitude) => PlaceInfo(
  id: id,
  name: id,
  address: '',
  category: 'park',
  location: GeoSample(latitude, 127, 0, DateTime(2026)),
  fetchedAt: DateTime(2026),
);

void main() {
  final current = GeoSample(37, 127, 5, DateTime(2026));

  test('dog size chooses 30, 45 and 60 minute round-trip targets', () {
    expect(nearbyTargetMinutes('소형견'), 30);
    expect(nearbyTargetMinutes('중형견'), 45);
    expect(nearbyTargetMinutes('대형견'), 60);
  });

  test('larger dog sizes include every shorter walking range', () {
    final candidates = [
      place('30-minute', 37.0077),
      place('45-minute', 37.0116),
      place('60-minute', 37.0154),
    ];
    final small = selectNearbyWalkPlaces(current, candidates, '소형견');
    final medium = selectNearbyWalkPlaces(current, candidates, '중형견');
    final large = selectNearbyWalkPlaces(current, candidates, '대형견');
    expect(small.places.map((item) => item.id), ['30-minute']);
    expect(medium.places.map((item) => item.id), ['30-minute', '45-minute']);
    expect(large.places.map((item) => item.id), [
      '30-minute',
      '45-minute',
      '60-minute',
    ]);
  });

  test('closest-time fallback avoids an empty result', () {
    final selection = selectNearbyWalkPlaces(current, [
      place('too-far', 37.03),
    ], '대형견');
    expect(selection.usedFallback, true);
    expect(selection.places.single.id, 'too-far');
  });
}
