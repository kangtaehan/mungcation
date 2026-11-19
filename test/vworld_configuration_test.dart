import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/services/android_map_configuration.dart';
import 'android_services_test.dart' show MemoryMapSettings;

void main() {
  test(
    'legacy default maps migrate once to the deployed VWorld key, preserving routing',
    () async {
      final store = MemoryMapSettings()
        ..raw = jsonEncode(
          const AndroidMapEndpoints(
            routing: 'https://example.org/routed-foot',
          ).toJson(),
        );
      final config = AndroidMapConfiguration(
        store: store,
        vworldKey: 'release-key-12345',
      );
      await config.load();
      expect(config.value.isVWorld, true);
      expect(config.value.routing, 'https://example.org/routed-foot');
      expect(jsonDecode(store.raw!)['basemapDefaultsVersion'], 1);
      await config.save(config.value.withOpenStreetMap());
      final loaded = AndroidMapConfiguration(
        store: store,
        vworldKey: 'release-key-12345',
      );
      await loaded.load();
      expect(
        loaded.value.isVWorld,
        false,
        reason: 'A later explicit user choice remains respected.',
      );
      config.dispose();
      loaded.dispose();
    },
  );

  test(
    'migration can display the released basemap even when saving its marker fails',
    () async {
      final store = MemoryMapSettings()
        ..raw = jsonEncode(const AndroidMapEndpoints().toJson())
        ..fail = true;
      final config = AndroidMapConfiguration(
        store: store,
        vworldKey: 'release-key-12345',
      );
      await config.load();
      expect(config.value.isVWorld, true);
      config.dispose();
    },
  );
  test(
    'map configuration can be created before platform storage is accessed',
    () {
      final config = AndroidMapConfiguration();
      expect(config.value.tiles, isNotEmpty);
      config.dispose();
    },
  );
  test('VWorld changes only the basemap and uses WMTS row before column', () {
    const current = AndroidMapEndpoints(
      search: 'https://example.org/search',
      routing: 'https://example.org/routed-foot',
    );
    final next = current.withVWorld('test-key-12345');
    expect(
      next.tiles,
      'https://api.vworld.kr/req/wmts/1.0.0/test-key-12345/Base/{z}/{y}/{x}.png',
    );
    expect(next.isVWorld, true);
    expect(next.attribution, contains('브이월드'));
    expect(next.search, current.search);
    expect(next.routing, current.routing);
    expect(next.cacheTilesOnDisk, false);
    expect(next.withOpenStreetMap().routing, current.routing);
    expect(next.withOpenStreetMap().search, current.search);
    expect(next.withOpenStreetMap().isVWorld, false);
    next.validate();
  });

  test('invalid keys fail before being placed in a request URL', () {
    for (final key in ['', 'a/b/c', 'key?leak=true', 'a b', 'key#frag']) {
      expect(
        () => const AndroidMapEndpoints().withVWorld(key),
        throwsFormatException,
      );
    }
  });

  test(
    'legacy settings and build defaults preserve explicit user choices',
    () async {
      final store = MemoryMapSettings();
      final config = AndroidMapConfiguration(
        store: store,
        vworldKey: 'build-key-12345',
      );
      await config.load();
      expect(config.value.isVWorld, true);
      await config.save(config.value.withOpenStreetMap());
      final next = AndroidMapConfiguration(
        store: store,
        vworldKey: 'build-key-12345',
      );
      await next.load();
      expect(next.value.isVWorld, false);
      expect(jsonDecode(store.raw!)['tiles'], contains('openstreetmap'));
      store.raw = jsonEncode(
        const AndroidMapEndpoints().withVWorld('saved-key-12345').toJson(),
      );
      await next.load();
      expect(next.value.isVWorld, true);
      expect(next.value.cacheTilesOnDisk, false);
      config.dispose();
      next.dispose();
    },
  );
}
