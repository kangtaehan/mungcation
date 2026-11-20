import '../models/walk_data.dart';
import 'android_map_service.dart';
import 'map_service.dart';
import 'national_park_map_service.dart';
import 'pet_place_catalog.dart';

class PetFriendlyMapService implements MapService, PlaceAdmissionResolver {
  final MapService delegate;
  final Future<PetPlaceCatalog> Function() loadPlaces;
  final Future<PetFoodRegistry> Function() loadRegistry;
  Future<PetPlaceCatalog>? _places;
  Future<PetFoodRegistry>? _registry;
  PetFriendlyMapService(
    this.delegate, {
    Future<PetPlaceCatalog> Function()? loadPlaces,
    Future<PetFoodRegistry> Function()? loadRegistry,
  }) : loadPlaces = loadPlaces ?? PetPlaceCatalog.load,
       loadRegistry = loadRegistry ?? PetFoodRegistry.load;

  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    final parsed = PetPlaceQuery(query);
    if (!parsed.onlyAllowed &&
        const ['공원', '동물병원', '놀이터'].any(query.trim().endsWith)) {
      final places = await delegate.search(query, center);
      return Future.wait(
        places.map((place) async {
          try {
            return await resolveAdmission(place);
          } catch (_) {
            return place;
          }
        }),
      );
    }
    if (parsed.term.isEmpty &&
        (parsed.onlyAllowed || parsed.category.isNotEmpty) &&
        (center == null || !center.valid)) {
      throw const MapServiceFailure('내 주변 동반 장소는 위치를 확인하거나 지역 이름을 함께 입력해 주세요.');
    }
    PetPlaceCatalog? catalog;
    PetFoodRegistry? registry;
    try {
      catalog = await (_places ??= loadPlaces());
    } catch (_) {
      _places = null;
    }
    final local =
        catalog?.search(query, center, onlyAllowed: false) ?? <PlaceInfo>[];
    final remote = <PlaceInfo>[];
    Object? providerError;
    // General pet discovery is offline. Explicit food/name searches can also
    // match live map points against the official registration list.
    final localOnly =
        parsed.onlyAllowed &&
        parsed.term.isEmpty &&
        (parsed.category.isEmpty ||
            parsed.category == 'civic' ||
            parsed.category == 'shopping' ||
            parsed.category == 'stay');
    if (!localOnly) {
      final suffix = switch (parsed.category) {
        'restaurant' => '식당',
        'cafe' => '카페',
        'civic' => '공공시설',
        'shopping' => '마트',
        'stay' => '숙소',
        _ => '',
      };
      final providerQuery = [
        parsed.term,
        suffix,
      ].where((v) => v.isNotEmpty).join(' ');
      try {
        remote.addAll(
          await delegate.search(
            providerQuery.isEmpty ? query : providerQuery,
            center,
          ),
        );
      } catch (error) {
        providerError = error;
      }
    }
    if (remote.isNotEmpty ||
        parsed.category == 'restaurant' ||
        parsed.category == 'cafe') {
      try {
        registry = await (_registry ??= loadRegistry());
      } catch (_) {
        _registry = null;
      }
    }
    final results = <String, PlaceInfo>{};
    for (final candidate in [...local, ...remote]) {
      final matched = catalog?.match(candidate);
      var place = matched == null
          ? candidate
          : candidate.category == 'park'
          ? candidate.withAdmission(matched.admission!)
          : matched;
      final registered = registry?.match(place);
      // Registration supplies eligibility only; it must not erase a facility's
      // published equipment, area restrictions or explicit denial.
      if (registered != null && place.admission?.hasEvidence != true)
        place = place.withAdmission(registered);
      if (parsed.onlyAllowed && place.admission?.isAllowed != true) continue;
      final identity = matched?.id ?? place.id;
      if (candidate.category == 'park' && matched != null) {
        results[identity] = place;
      } else {
        results.putIfAbsent(identity, () => place);
      }
    }
    if (results.isEmpty && providerError != null) throw providerError;
    if (catalog == null && results.isEmpty && parsed.onlyAllowed) {
      throw const MapServiceFailure('동반 장소 자료를 읽지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
    final found = results.values.toList();
    if (center != null && center.valid)
      found.sort(
        (a, b) => distanceBetween(
          center,
          a.location,
        ).compareTo(distanceBetween(center, b.location)),
      );
    return found.take(60).toList();
  }

  @override
  Future<PlaceInfo> resolveAdmission(PlaceInfo place) async {
    PetPlaceCatalog catalog;
    try {
      catalog = await (_places ??= loadPlaces());
    } catch (_) {
      _places = null;
      throw const MapServiceFailure('동반 장소 자료를 읽지 못했어요. 다시 시도해 주세요.');
    }
    final policy = catalog.match(place)?.admission;
    var resolved = policy == null ? place : place.withAdmission(policy);
    if ((place.category == 'cafe' || place.category == 'restaurant') &&
        resolved.admission?.hasEvidence != true) {
      try {
        final registry = await (_registry ??= loadRegistry());
        final registered = registry.match(resolved);
        if (registered != null) resolved = resolved.withAdmission(registered);
      } catch (_) {
        _registry = null;
        throw const MapServiceFailure('음식점 동반 등록 자료를 읽지 못했어요. 다시 시도해 주세요.');
      }
    }
    return resolved;
  }

  @override
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end) =>
      delegate.directions(start, end);
  @override
  Future<void> openPlace(PlaceInfo place) => delegate.openPlace(place);
  void close() {
    if (delegate case final NationalParkMapService service) {
      service.close();
    } else if (delegate case final AndroidMapService service) {
      service.close();
    }
  }
}
