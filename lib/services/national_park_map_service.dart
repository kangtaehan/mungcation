import '../models/walk_data.dart';
import 'android_map_service.dart';
import 'map_service.dart';
import 'national_park_catalog.dart';

/// Supplies official urban-park names while preserving platform routing and POIs.
class NationalParkMapService implements MapService {
  final MapService delegate;
  final Future<NationalParkCatalog> Function() loadCatalog;
  Future<NationalParkCatalog>? _catalog;
  NationalParkMapService(
    this.delegate, {
    Future<NationalParkCatalog> Function()? loadCatalog,
  }) : loadCatalog = loadCatalog ?? NationalParkCatalog.load;

  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    final cleaned = NationalParkCatalog.cleanQuery(query);
    final parkQuery = cleaned.endsWith('공원');
    if (!parkQuery) return delegate.search(query, center);
    if (cleaned == '공원' && (center == null || !center.valid)) {
      throw const MapServiceFailure('주변 공원은 현재 위치를 확인하거나 지역 이름을 함께 입력해 주세요.');
    }
    try {
      final catalog = await (_catalog ??= loadCatalog());
      final parks = catalog.search(cleaned, center);
      if (parks.isNotEmpty) return parks;
    } catch (_) {
      // A failed asset load can be retried; never invent park names on failure.
      _catalog = null;
    }
    final results = await delegate.search(query, center);
    return results
        .where(
          (place) =>
              place.rewardEligible &&
              place.name.trim().isNotEmpty &&
              place.name != place.address &&
              !RegExp(r'^[가-힣0-9·.\s]+(?:동|읍|면|리)$').hasMatch(place.name),
        )
        .toList();
  }

  @override
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end) =>
      delegate.directions(start, end);
  @override
  Future<void> openPlace(PlaceInfo place) => delegate.openPlace(place);
  void close() {
    if (delegate case final AndroidMapService service) service.close();
  }
}
