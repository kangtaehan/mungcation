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
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  @override
  Future<String?> load() => preferences.getString('mungcation.android.maps.v1');
  @override
  Future<void> save(String value) =>
      preferences.setString('mungcation.android.maps.v1', value);
}

class AndroidMapConfiguration extends ChangeNotifier {
  static final instance = AndroidMapConfiguration();
  final MapSettingsStore store;
  AndroidMapConfiguration({MapSettingsStore? store})
    : store = store ?? PreferencesMapSettings();
  AndroidMapEndpoints value = const AndroidMapEndpoints();
  String? error;
  Future<void> load() async {
    try {
      final raw = await store.load();
      if (raw != null)
        value = AndroidMapEndpoints.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
    } catch (_) {
      error = '지도 설정을 읽지 못해 기본 서비스를 사용해요.';
    }
    notifyListeners();
  }

  Future<void> save(AndroidMapEndpoints next) async {
    next.validate();
    await store.save(jsonEncode(next.toJson()));
    value = next;
    error = null;
    notifyListeners();
  }
}
