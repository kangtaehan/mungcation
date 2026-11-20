import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/korea.dart';
import '../models/pet_admission.dart';
import '../models/walk_data.dart';

String petNameKey(String value) => value
    .replaceFirst(RegExp(r'^\s*(?:\(주\)|주식회사)\s*'), '')
    .replaceAll(RegExp(r'[\s().,·\-]'), '')
    .toLowerCase();
String _compact(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

class PetPlaceQuery {
  final String term, category;
  final bool onlyAllowed;
  PetPlaceQuery(String query)
    : onlyAllowed = RegExp(r'반려동물\s*동반|동반\s*가능').hasMatch(query),
      term = _term(query),
      category = _category(query);
  static const categories = {
    '숙소': 'stay',
    '호텔': 'stay',
    '펜션': 'stay',
    '공공시설': 'civic',
    '문화시설': 'civic',
    '대형마트': 'shopping',
    '음식점': 'restaurant',
    '카페': 'cafe',
    '식당': 'restaurant',
    '마트': 'shopping',
    '쇼핑': 'shopping',
  };
  static String clean(String value) =>
      value.replaceAll(RegExp(r'반려동물\s*동반|동반\s*가능'), '').trim();
  static String _category(String value) {
    final cleanValue = clean(value);
    return categories.entries
            .where((e) => cleanValue.endsWith(e.key))
            .firstOrNull
            ?.value ??
        '';
  }

  static String _term(String value) {
    final cleaned = clean(value);
    final suffix = categories.keys.where(cleaned.endsWith).firstOrNull;
    return suffix == null
        ? cleaned
        : cleaned.substring(0, cleaned.length - suffix.length).trim();
  }
}

class PetPlaceCatalog {
  final List<PlaceInfo> places;
  final Set<String> _parkPolicyIds;
  late final Map<String, List<PlaceInfo>> _names = _index(places);
  static Map<String, List<PlaceInfo>> _index(List<PlaceInfo> places) {
    final names = <String, List<PlaceInfo>>{};
    for (final place in places) {
      names.putIfAbsent(petNameKey(place.name), () => []).add(place);
    }
    return names;
  }

  PetPlaceCatalog._(this.places, this._parkPolicyIds);
  static Future<PetPlaceCatalog> load() async => PetPlaceCatalog.fromJson(
    await rootBundle.loadString('assets/data/pet_places.json'),
  );
  factory PetPlaceCatalog.fromJson(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['schema'] != 1) throw const FormatException('잘못된 동반 장소 자료');
    final policies = (data['policies'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(
        key,
        PetAdmission.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    final now = DateTime.now();
    final places = <PlaceInfo>[];
    final parkPolicyIds = <String>{};
    for (final entry in data['places'] as List) {
      final row = Map<String, dynamic>.from(entry as Map);
      final lat = (row['lat'] as num).toDouble(),
          lon = (row['lon'] as num).toDouble();
      final name = (row['name'] as String).trim();
      if (row['kind'] == '여행지' || row['category'] == 'park')
        parkPolicyIds.add(row['id'] as String);
      if (name.isEmpty || !isInKorea(lat, lon))
        throw const FormatException('잘못된 장소 좌표 또는 이름');
      final policy = row['admissionKey'] == null
          ? PetAdmission.fromJson(
              Map<String, dynamic>.from(row['admission'] as Map),
            )
          : policies[row['admissionKey']];
      if (policy == null) throw const FormatException('장소의 동반 출처가 없어요.');
      places.add(
        PlaceInfo(
          id: row['id'] as String,
          name: name,
          category: row['category'] as String,
          address: row['address'] as String? ?? '',
          phone: row['phone'] as String? ?? '',
          roadName: row['roadName'] as String? ?? '',
          buildingNumber: row['buildingNumber'] as String? ?? '',
          source: policy.sourceName,
          admission: policy,
          location: GeoSample(lat, lon, 0, now),
          fetchedAt: now,
        ),
      );
    }
    return PetPlaceCatalog._(
      List.unmodifiable(places),
      Set.unmodifiable(parkPolicyIds),
    );
  }

  List<PlaceInfo> search(
    String text,
    GeoSample? center, {
    bool onlyAllowed = true,
    int limit = 60,
  }) {
    final query = PetPlaceQuery(text);
    if (query.term.isEmpty && (center == null || !center.valid)) return [];
    final terms = query.term
        .split(RegExp(r'\s+'))
        .where((v) => v.isNotEmpty)
        .map(_compact)
        .toList();
    final found = places.where((place) {
      if (onlyAllowed && place.admission?.isAllowed != true) return false;
      if (query.category.isNotEmpty && place.category != query.category)
        return false;
      if (query.term.isEmpty)
        return distanceBetween(center!, place.location) <= 8000;
      final value = _compact('${place.name} ${place.address}');
      return terms.every(value.contains);
    }).toList();
    if (center != null && center.valid)
      found.sort(
        (a, b) => distanceBetween(
          center,
          a.location,
        ).compareTo(distanceBetween(center, b.location)),
      );
    return found.take(limit).toList();
  }

  PlaceInfo? match(PlaceInfo place) {
    final matches = (_names[petNameKey(place.name)] ?? []).where((candidate) {
      if (place.category == 'park' && !_parkPolicyIds.contains(candidate.id))
        return false;
      if (distanceBetween(candidate.location, place.location) > 100)
        return false;
      final sameStreet =
          place.roadName.isNotEmpty &&
          place.buildingNumber.isNotEmpty &&
          _compact(candidate.roadName) == _compact(place.roadName) &&
          candidate.buildingNumber.trim() == place.buildingNumber.trim();
      final sameFullAddress =
          place.address.trim().isNotEmpty &&
          _compact(candidate.address) == _compact(place.address);
      return candidate.id == place.id || sameStreet || sameFullAddress;
    }).toList();
    return matches.length == 1 ? matches.single : null;
  }
}

class PetFoodRegistry {
  final Map<String, List<Map<String, dynamic>>> _names;
  final DateTime retrievedAt;
  final String sourceUrl;
  PetFoodRegistry._(this._names, this.retrievedAt, this.sourceUrl);
  static Future<PetFoodRegistry> load() async => PetFoodRegistry.fromJson(
    await rootBundle.loadString('assets/data/pet_food_registry.json'),
  );
  factory PetFoodRegistry.fromJson(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['schema'] != 1) throw const FormatException('잘못된 동반 음식점 등록 자료');
    final names = <String, List<Map<String, dynamic>>>{};
    for (final row in data['places'] as List) {
      final place = Map<String, dynamic>.from(row as Map);
      names
          .putIfAbsent(petNameKey(place['name'] as String), () => [])
          .add(place);
    }
    return PetFoodRegistry._(
      names,
      DateTime.parse(data['retrievedAt'] as String),
      data['sourceUrl'] as String,
    );
  }
  static String _address(String value) {
    for (final entry in const {
      '충청북도': '충북',
      '충청남도': '충남',
      '전라북도': '전북',
      '전북특별자치도': '전북',
      '전라남도': '전남',
      '경상북도': '경북',
      '경상남도': '경남',
    }.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return _compact(value);
  }

  PetAdmission? match(PlaceInfo place) {
    if (place.category != 'cafe' && place.category != 'restaurant') return null;
    if (place.roadName.isEmpty ||
        place.buildingNumber.isEmpty ||
        place.address.isEmpty)
      return null;
    final candidates = (_names[petNameKey(place.name)] ?? [])
        .where(
          (row) =>
              _compact(row['road'] as String) == _compact(place.roadName) &&
              (row['number'] as String).trim() == place.buildingNumber.trim() &&
              _address(
                place.address,
              ).contains(_address(row['region'] as String)) &&
              (row['locality'] as String? ?? '').isNotEmpty &&
              _address(
                place.address,
              ).contains(_address(row['locality'] as String)),
        )
        .toList();
    if (candidates.length != 1) return null;
    return PetAdmission(
      status: PetAdmissionStatus.conditional,
      conditions:
          '식품안전나라에 반려동물 동반출입 업소로 등록되어 있습니다. 유모차·캐리어·동반 구역·크기 제한 등 세부 조건은 업소에 확인해 주세요.',
      sourceName: '식품안전나라 · 반려동물 동반출입 등록 현황',
      sourceUrl: sourceUrl,
      checkedAt: retrievedAt,
    );
  }
}
