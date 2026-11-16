import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/korea.dart';
import '../models/walk_data.dart';
import 'map_service.dart';
import 'android_map_configuration.dart';

class MapServiceFailure implements Exception {
  final String message;
  const MapServiceFailure(this.message);
  @override
  String toString() => message;
}

class AndroidMapService implements MapService {
  static const androidChannel = MethodChannel('mungcation/android');
  static const userAgent = 'Mungcation/0.4.0 (Android pet walking app)';
  final AndroidMapConfiguration configuration;
  final http.Client client;
  final Duration requestSpacing;
  final DateTime Function() now;
  AndroidMapService({
    AndroidMapConfiguration? configuration,
    http.Client? client,
    this.requestSpacing = const Duration(milliseconds: 1100),
    DateTime Function()? now,
  }) : configuration = configuration ?? AndroidMapConfiguration.instance,
       client = client ?? http.Client(),
       now = now ?? DateTime.now;
  final Map<String, ({DateTime at, Object data})> _cache = {};
  Future<void> _tail = Future.value();
  DateTime? _lastRequest;
  Future<Object> _get(Uri uri) async {
    final cached = _cache[uri.toString()];
    if (cached != null &&
        now().difference(cached.at) < const Duration(minutes: 10))
      return cached.data;
    final future = _tail.then((_) async {
      final again = _cache[uri.toString()];
      if (again != null &&
          now().difference(again.at) < const Duration(minutes: 10))
        return again.data;
      if (_lastRequest != null) {
        final wait = requestSpacing - now().difference(_lastRequest!);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequest = now();
      final response = await client
          .get(
            uri,
            headers: {
              'User-Agent': userAgent,
              'Accept': 'application/json',
              'Accept-Language': 'ko',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 429)
        throw const MapServiceFailure('지도 서비스 요청이 많아요. 잠시 후 다시 시도해 주세요.');
      if (response.statusCode != 200)
        throw const MapServiceFailure('지도 서비스에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
      if (response.bodyBytes.length > 8 * 1024 * 1024)
        throw const MapServiceFailure(
          '지도 응답이 너무 커요. 다른 검색어나 가까운 목적지를 선택해 주세요.',
        );
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Object;
      if (_cache.length >= 40) _cache.remove(_cache.keys.first);
      _cache[uri.toString()] = (at: now(), data: data);
      return data;
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    final cleaned = query
        .replaceAll('반려동물 동반', '')
        .replaceAll('반려견', '')
        .trim();
    if (cleaned.isEmpty)
      throw const MapServiceFailure('장소 이름이나 지역을 입력하거나 종류를 선택해 주세요.');
    if (cleaned.length > 200)
      throw const MapServiceFailure('검색어는 200자 이하로 입력해 주세요.');
    const categories = {
      '공원': 'park',
      '카페': 'cafe',
      '식당': 'restaurant',
      '숙소': 'hotel',
      '놀이터': 'playground',
      '동물병원': 'veterinary',
    };
    final category = categories.keys.where(cleaned.endsWith).firstOrNull;
    final region = category == null
        ? cleaned
        : cleaned.substring(0, cleaned.length - category.length).trim();
    final parameters = <String, String>{
      'format': 'jsonv2',
      'limit': '15',
      'addressdetails': '1',
      'extratags': '1',
      'accept-language': 'ko',
      'countrycodes': 'kr',
      'q': category == null
          ? cleaned
          : region.isEmpty
          ? '[${categories[category]}]'
          : '${categories[category]} $region',
    };
    if (category != null && region.isEmpty && center == null)
      throw const MapServiceFailure(
        '주변 장소를 찾으려면 현재 위치를 확인하거나 지역 이름을 함께 입력해 주세요.',
      );
    if (center != null && center.valid) {
      final dx = (.04 / math.max(.2, math.cos(center.latitude * math.pi / 180)))
          .clamp(.04, .2);
      parameters['viewbox'] =
          '${(center.longitude - dx).clamp(-180, 180)},${(center.latitude + .04).clamp(-90, 90)},${(center.longitude + dx).clamp(-180, 180)},${(center.latitude - .04).clamp(-90, 90)}';
      parameters['bounded'] = region.isEmpty && category != null ? '1' : '0';
    }
    final base = Uri.parse(configuration.value.search),
        uri = base.replace(
          queryParameters: {...base.queryParameters, ...parameters},
        );
    final raw = await _get(uri);
    if (raw is! List) throw const MapServiceFailure('장소 응답 형식을 확인하지 못했어요.');
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((e) {
          final lat = double.tryParse('${e['lat']}'),
              lon = double.tryParse('${e['lon']}');
          if (lat == null || lon == null) return null;
          final location = GeoSample(lat, lon, 0, now());
          if (!location.valid ||
              !isInKorea(location.latitude, location.longitude)) {
            return null;
          }
          final tags = Map<String, dynamic>.from(e['extratags'] as Map? ?? {}),
              address = '${e['display_name'] ?? ''}';
          final park = e['class'] == 'leisure' && e['type'] == 'park';
          return PlaceInfo(
            id: 'osm-${e['osm_type'] ?? 'place'}-${e['osm_id'] ?? e['place_id']}',
            name: '${e['name'] ?? address.split(',').first}',
            address: address,
            category: park ? 'park' : 'unknown',
            location: location,
            fetchedAt: now(),
            phone: '${tags['phone'] ?? tags['contact:phone'] ?? ''}',
            url: '${tags['website'] ?? tags['contact:website'] ?? ''}',
            source: 'OpenStreetMap · Nominatim',
          );
        })
        .whereType<PlaceInfo>()
        .toList();
  }

  @override
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end) async {
    if (!start.valid || !end.location.valid)
      throw const MapServiceFailure('유효한 출발지와 목적지가 필요해요.');
    if (!isInKorea(start.latitude, start.longitude) ||
        !isInKorea(end.location.latitude, end.location.longitude)) {
      throw const MapServiceFailure('국내 산책 경로만 안내할 수 있어요.');
    }
    configuration.value.validate();
    final base = configuration.value.routing.replaceAll(RegExp(r'/+$'), '');
    final uri =
        Uri.parse(
          '$base/route/v1/foot/${start.longitude},${start.latitude};${end.location.longitude},${end.location.latitude}',
        ).replace(
          queryParameters: {
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'true',
            'alternatives': 'true',
          },
        );
    final raw = await _get(uri);
    if (raw is! Map || raw['code'] != 'Ok')
      throw const MapServiceFailure('제공 가능한 도보 경로가 없어요. 다른 목적지를 선택해 주세요.');
    final routes = <WalkingRoute>[];
    for (final value in raw['routes'] as List? ?? []) {
      final route = Map<String, dynamic>.from(value as Map),
          meters = (route['distance'] as num).toDouble(),
          seconds = (route['duration'] as num).toDouble();
      final coordinates = (route['geometry']['coordinates'] as List)
          .map(
            (c) => GeoSample(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
              0,
              now(),
            ),
          )
          .toList();
      if (!meters.isFinite ||
          !seconds.isFinite ||
          meters < 0 ||
          seconds < 0 ||
          coordinates.length < 2 ||
          coordinates.any(
            (p) => !p.valid || !isInKorea(p.latitude, p.longitude),
          ))
        continue;
      final instructions = <String>[];
      for (final leg in route['legs'] as List? ?? []) {
        for (final step in leg['steps'] as List? ?? []) {
          final road = '${step['name'] ?? ''}',
              distance = (step['distance'] as num? ?? 0).round();
          if (distance > 0)
            instructions.add(
              '${road.isEmpty ? '이름 없는 구간' : road} · ${distance}m 이동',
            );
        }
      }
      routes.add(
        WalkingRoute(
          '도보 경로 ${routes.length + 1}',
          meters,
          seconds,
          coordinates,
          instructions,
          source: Uri.parse(base).host == 'routing.openstreetmap.de'
              ? 'OpenStreetMap · FOSSGIS OSRM 도보'
              : 'OpenStreetMap · OSRM 보행자 서버',
        ),
      );
    }
    routes.sort((a, b) => a.seconds.compareTo(b.seconds));
    return routes;
  }

  @override
  Future<void> openPlace(PlaceInfo place) async {
    final opened = await androidChannel.invokeMethod<bool>(
      'openMap',
      place.toMap(),
    );
    if (opened != true) throw const MapServiceFailure('지도를 열 수 있는 앱을 찾지 못했어요.');
  }

  static Future<void> openLink(String value) async {
    AndroidMapEndpoints.https(value);
    if (await androidChannel.invokeMethod<bool>('openUrl', {'url': value}) !=
        true)
      throw const MapServiceFailure('링크를 열지 못했어요.');
  }

  void close() => client.close();
}
