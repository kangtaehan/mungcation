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

  test('small and large dogs receive different walking-distance places', () {
    final candidates = [place('near', 37.0078), place('far', 37.0156)];
    final small = selectNearbyWalkPlaces(current, candidates, '소형견');
    final large = selectNearbyWalkPlaces(current, candidates, '대형견');
    expect(small.places.map((item) => item.id), contains('near'));
    expect(small.places.map((item) => item.id), isNot(contains('far')));
    expect(large.places.map((item) => item.id), contains('far'));
    expect(large.places.map((item) => item.id), isNot(contains('near')));
  });

  test('closest-time fallback avoids an empty result', () {
    final selection = selectNearbyWalkPlaces(current, [
      place('very-near', 37.0001),
    ], '대형견');
    expect(selection.usedFallback, true);
    expect(selection.places.single.id, 'very-near');
  });
}
