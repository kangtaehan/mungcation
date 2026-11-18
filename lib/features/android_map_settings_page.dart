import 'package:flutter/material.dart';
import '../services/android_map_configuration.dart';

class AndroidMapSettingsPage extends StatefulWidget {
  final AndroidMapConfiguration? configuration;
  const AndroidMapSettingsPage({super.key, this.configuration});
  @override
  State<AndroidMapSettingsPage> createState() => _AndroidMapSettingsPageState();
}

class _AndroidMapSettingsPageState extends State<AndroidMapSettingsPage> {
  late final AndroidMapConfiguration configuration =
      widget.configuration ?? AndroidMapConfiguration.instance;
  late final TextEditingController tiles,
      search,
      routing,
      attribution,
      link,
      vworldKey;
  late String basemap;
  bool saving = false, walkingConfirmed = true;
  String? error;
  @override
  void initState() {
    super.initState();
    final value = configuration.value;
    basemap = value.isVWorld
        ? 'vworld'
        : value.tiles == const AndroidMapEndpoints().tiles
        ? 'default'
        : 'custom';
    vworldKey = TextEditingController(
      text: value.isVWorld
          ? RegExp(
                  r'/req/wmts/1\.0\.0/([^/]+)/',
                ).firstMatch(value.tiles)?.group(1) ??
                ''
          : '',
    );
    tiles = TextEditingController(text: value.tiles);
    search = TextEditingController(text: value.search);
    routing = TextEditingController(text: value.routing);
    attribution = TextEditingController(text: value.attribution);
    link = TextEditingController(text: value.attributionUrl);
  }

  @override
  void dispose() {
    for (final controller in [
      tiles,
      search,
      routing,
      attribution,
      link,
      vworldKey,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!walkingConfirmed) {
      setState(() => error = '도보 전용 서버인지 확인해 주세요.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      var next = AndroidMapEndpoints(
        tiles: tiles.text.trim(),
        search: search.text.trim(),
        routing: routing.text.trim(),
        attribution: attribution.text.trim(),
        attributionUrl: link.text.trim(),
      );
      if (basemap == 'vworld') next = next.withVWorld(vworldKey.text);
      if (basemap == 'default') next = next.withOpenStreetMap();
      await configuration.save(next);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FormatException ? e.message : '지도 설정을 저장하지 못했어요.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('지도 서비스 설정'),
        automaticallyImplyLeading: !saving,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '배경 지도만 바꿀 수 있어요. 공원 이름·위치는 공공데이터를 사용하고, 기존 장소 검색과 도보 길찾기는 유지해요.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'vworld': '브이월드',
                'default': '기본 지도',
                'custom': '사용자 지정',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: basemap == entry.key,
                  onSelected: saving
                      ? null
                      : (_) => setState(() {
                          basemap = entry.key;
                          error = null;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (basemap == 'vworld') ...[
            TextField(
              key: const ValueKey('vworld-key'),
              controller: vworldKey,
              enabled: !saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '브이월드 인증키',
                hintText: '발급받은 인증키 입력',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '브이월드에서 발급받은 키가 필요해요. 웹용 키에는 사용할 사이트 주소를 등록해 주세요. 저장하면 이 기기의 지도에 적용돼요.',
            ),
          ] else if (basemap == 'default')
            const Text('기본 배경은 OpenStreetMap이며, iPhone에서는 Apple 지도를 사용해요.'),
          const SizedBox(height: 20),
          ExpansionTile(
            title: const Text('고급 서비스 설정'),
            children: [
              const Text(
                '검색·경로 주소 변경은 웹·Android에 적용돼요. iPhone의 검색·도보 경로는 Apple 지도를 유지해요. 검색어·위치·목적지는 해당 제공자로 전송되며 사용 한도와 조건을 확인해 주세요.',
              ),
              if (basemap == 'custom')
                TextField(
                  controller: tiles,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'XYZ 래스터 타일 HTTPS 주소',
                    helperText: '{z} · {x} · {y}를 포함해야 해요.',
                  ),
                  maxLines: 2,
                ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Nominatim 호환 검색 주소',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: routing,
                enabled: !saving,
                onChanged: (_) => setState(() => walkingConfirmed = false),
                decoration: const InputDecoration(
                  labelText: 'OSRM 보행자 전용 서버 기본 주소',
                ),
                maxLines: 2,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: walkingConfirmed,
                onChanged: saving
                    ? null
                    : (v) => setState(() => walkingConfirmed = v ?? false),
                title: const Text('입력한 경로 서버가 보행자 전용임을 확인했어요.'),
                subtitle: const Text('차량 서버에 foot 문자열만 붙여도 도보 경로가 되는 것은 아니에요.'),
              ),
              if (basemap == 'custom')
                TextField(
                  controller: attribution,
                  enabled: !saving,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: '지도 출처 표시'),
                ),
              if (basemap == 'custom')
                TextField(
                  controller: link,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: '출처·라이선스 HTTPS 링크',
                  ),
                  maxLines: 2,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.brown)),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '저장 중…' : '지도 설정 저장'),
          ),
          TextButton(
            onPressed: saving
                ? null
                : () {
                    const defaults = AndroidMapEndpoints();
                    setState(() {
                      basemap = 'default';
                      vworldKey.clear();
                      tiles.text = defaults.tiles;
                      search.text = defaults.search;
                      routing.text = defaults.routing;
                      attribution.text = defaults.attribution;
                      link.text = defaults.attributionUrl;
                      walkingConfirmed = true;
                    });
                  },
            child: const Text('기본값 불러오기'),
          ),
        ],
      ),
    ),
  );
}
