import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AndroidMapEndpoints {
  final String tiles, search, routing, attribution, attributionUrl;
  const AndroidMapEndpoints({
    this.tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.search = 'https://nominatim.openstreetmap.org/search',
    this.routing = 'https://routing.openstreetmap.de/routed-foot',
    this.attribution = '© OpenStreetMap contributors',
    this.attributionUrl = 'https://www.openstreetmap.org/copyright',
  });

  bool get isVWorld {
    final host = Uri.tryParse(tiles)?.host ?? '';
    return host == 'vworld.kr' || host.endsWith('.vworld.kr');
  }

  bool get cacheTilesOnDisk => !isVWorld;

  /// WMTS uses zoom/row/column, unlike the OSM zoom/column/row URL.
  /// Source: V-world/V-world_API_sample, 2026 education README.
  AndroidMapEndpoints withVWorld(String key) {
    key = key.trim();
    if (!RegExp(r'^[A-Za-z0-9-]{10,128}$').hasMatch(key))
      throw const FormatException('발급받은 브이월드 인증키를 확인해 주세요.');
    return AndroidMapEndpoints(
      tiles: 'https://api.vworld.kr/req/wmts/1.0.0/$key/Base/{z}/{y}/{x}.png',
      attribution: '공간정보 오픈플랫폼(브이월드)',
      attributionUrl: 'https://www.vworld.kr/',
      search: search,
      routing: routing,
    );
  }

  AndroidMapEndpoints withOpenStreetMap() =>
      AndroidMapEndpoints(search: search, routing: routing);
  static void https(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty)
      throw const FormatException('계정 정보가 없는 HTTPS 주소를 입력해 주세요.');
  }

  void validate() {
    for (final value in [
      tiles
          .replaceAll('{z}', '0')
          .replaceAll('{x}', '0')
          .replaceAll('{y}', '0'),
      search,
      routing,
      attributionUrl,
    ]) {
      https(value);
    }
    if (!['{z}', '{x}', '{y}'].every(tiles.contains) ||
        attribution.trim().isEmpty ||
        attribution.length > 120)
      throw const FormatException('타일 주소의 {z}·{x}·{y}와 출처 표시가 필요해요.');
    final route = Uri.parse(routing);
    if (route.hasQuery ||
        route.host == 'router.project-osrm.org' ||
        route.path.contains('routed-car') ||
        route.path.contains('routed-bike') ||
        route.path.contains('/driving'))
      throw const FormatException(
        'OSRM 보행자 전용 서버의 기본 주소가 필요해요. 차량·자전거 서버는 사용할 수 없어요.',
      );
  }

  Map<String, dynamic> toJson() => {
    'tiles': tiles,
    'search': search,
    'routing': routing,
    'attribution': attribution,
    'attributionUrl': attributionUrl,
  };
  factory AndroidMapEndpoints.fromJson(Map<String, dynamic> j) {
    final value = AndroidMapEndpoints(
      tiles: j['tiles'] as String,
      search: j['search'] as String,
      routing: j['routing'] as String,
      attribution: j['attribution'] as String,
      attributionUrl: j['attributionUrl'] as String,
    );
    value.validate();
    return value;
  }
}

abstract interface class MapSettingsStore {
  Future<String?> load();
  Future<void> save(String value);
}

class PreferencesMapSettings implements MapSettingsStore {
  late final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  @override
  Future<String?> load() => preferences.getString('mungcation.android.maps.v1');
  @override
  Future<void> save(String value) =>
      preferences.setString('mungcation.android.maps.v1', value);
}

class AndroidMapConfiguration extends ChangeNotifier {
  static final instance = AndroidMapConfiguration();
  final MapSettingsStore store;
  late final AndroidMapEndpoints defaults;
  AndroidMapConfiguration({
    MapSettingsStore? store,
    String vworldKey = const String.fromEnvironment('VWORLD_API_KEY'),
  }) : store = store ?? PreferencesMapSettings() {
    if (vworldKey.trim().isNotEmpty) {
      try {
        value = value.withVWorld(vworldKey);
      } on FormatException {
        error = '브이월드 인증키 설정을 확인하지 못해 기본 지도를 사용해요.';
      }
    }
    defaults = value;
  }
  AndroidMapEndpoints value = const AndroidMapEndpoints();
  String? error;
  Future<void> load() async {
    try {
      final raw = await store.load();
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        value = AndroidMapEndpoints.fromJson(saved);
        // Upgrade the previous stock basemap once; preserve routing and later
        // explicit preferences. Never discard valid settings on write failure.
        if (defaults.isVWorld &&
            saved['basemapDefaultsVersion'] != 1 &&
            value.tiles == const AndroidMapEndpoints().tiles) {
          value = AndroidMapEndpoints(
            tiles: defaults.tiles,
            attribution: defaults.attribution,
            attributionUrl: defaults.attributionUrl,
            search: value.search,
            routing: value.routing,
          );
          try {
            await store.save(_encode(value));
          } catch (_) {
            error = '브이월드 기본 지도는 적용했지만 설정을 저장하지 못했어요.';
          }
        }
      }
    } catch (_) {
      error = '지도 설정을 읽지 못해 기본 서비스를 사용해요.';
    }
    notifyListeners();
  }

  String _encode(AndroidMapEndpoints next) =>
      jsonEncode({...next.toJson(), 'basemapDefaultsVersion': 1});

  Future<void> save(AndroidMapEndpoints next) async {
    next.validate();
    await store.save(_encode(next));
    value = next;
    error = null;
    notifyListeners();
  }
}
