import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/korea.dart';
import '../models/walk_data.dart';

/// An offline snapshot of data.go.kr dataset 15012890, not a live Naver feed.
class NationalParkCatalog {
  final List<PlaceInfo> _parks;
  NationalParkCatalog._(this._parks);
  static Future<NationalParkCatalog> load() async =>
      NationalParkCatalog.fromJson(
        await rootBundle.loadString('assets/data/national_parks.json'),
      );

  factory NationalParkCatalog.fromJson(String value) {
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (data['schema'] != 1) throw const FormatException('지원하지 않는 공원 데이터');
    final retrieved = DateTime.parse(data['retrievedAt'] as String);
    final parks = <PlaceInfo>[];
    for (final row in data['parks'] as List) {
      final lat = (row[4] as num).toDouble(), lon = (row[5] as num).toDouble();
      final name = (row[1] as String).trim();
      if (name.isEmpty || !isInKorea(lat, lon))
        throw const FormatException('잘못된 공원 데이터');
      parks.add(
        PlaceInfo(
          id: row[0] as String,
          name: name,
          address: row[3] as String,
          category: 'park',
          location: GeoSample(lat, lon, 0, retrieved),
          fetchedAt: retrieved,
          referenceDate: DateTime.parse(row[7] as String),
          phone: row[6] as String,
          source: '공공데이터포털 · 전국도시공원정보표준데이터 · ${row[8]}',
        ),
      );
    }
    return NationalParkCatalog._(List.unmodifiable(parks));
  }

  static String cleanQuery(String query) =>
      query.replaceAll('반려동물 동반', '').replaceAll('반려견', '').trim();
  static String compact(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  List<PlaceInfo> search(String query, GeoSample? center, {int limit = 60}) {
    final cleaned = cleanQuery(query);
    final nearby = cleaned == '공원';
    if (nearby && (center == null || !center.valid)) return [];
    final terms = cleaned
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty && term != '공원')
        .map(compact)
        .toList();
    if (!nearby && terms.isEmpty) return [];
    final matches = _parks.where((park) {
      if (nearby) return distanceBetween(center!, park.location) <= 8000;
      final text = compact('${park.name} ${park.address}');
      return terms.every(text.contains);
    }).toList();
    if (center != null && center.valid) {
      matches.sort(
        (a, b) => distanceBetween(
          center,
          a.location,
        ).compareTo(distanceBetween(center, b.location)),
      );
    }
    final searched = DateTime.now();
    return matches
        .take(limit)
        .map(
          (park) => PlaceInfo(
            id: park.id,
            name: park.name,
            address: park.address,
            category: park.category,
            location: park.location,
            fetchedAt: searched,
            referenceDate: park.referenceDate,
            phone: park.phone,
            source: park.source,
          ),
        )
        .toList();
  }
}
