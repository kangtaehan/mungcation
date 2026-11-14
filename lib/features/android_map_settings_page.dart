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
  late final TextEditingController tiles, search, routing, attribution, link;
  bool saving = false, walkingConfirmed = true;
  String? error;
  @override
  void initState() {
    super.initState();
    final value = configuration.value;
    tiles = TextEditingController(text: value.tiles);
    search = TextEditingController(text: value.search);
    routing = TextEditingController(text: value.routing);
    attribution = TextEditingController(text: value.attribution);
    link = TextEditingController(text: value.attributionUrl);
  }

  @override
  void dispose() {
    for (final controller in [tiles, search, routing, attribution, link]) {
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
      await configuration.save(
        AndroidMapEndpoints(
          tiles: tiles.text.trim(),
          search: search.text.trim(),
          routing: routing.text.trim(),
          attribution: attribution.text.trim(),
          attributionUrl: link.text.trim(),
        ),
      );
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
        title: const Text('Android 지도 서비스'),
        automaticallyImplyLeading: !saving,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '기본 지도는 OpenStreetMap, 검색은 Nominatim, 도보 경로는 FOSSGIS의 보행자 OSRM 서비스를 사용해요. 검색어·위치·목적지는 해당 제공자로 전송돼요.',
          ),
          const SizedBox(height: 12),
          const Text(
            '기본 공개 서버는 개인 개발·시험용으로 사용하세요. 앱 전체 요청 한도가 있어 여러 사용자에게 배포할 때는 자체 서버나 계약한 서비스를 설정해야 해요. 이 설정에서 앱 업데이트 없이 제공자를 변경할 수 있어요.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
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
            decoration: const InputDecoration(labelText: 'Nominatim 호환 검색 주소'),
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
          TextField(
            controller: attribution,
            enabled: !saving,
            maxLength: 120,
            decoration: const InputDecoration(labelText: '지도 출처 표시'),
          ),
          TextField(
            controller: link,
            enabled: !saving,
            decoration: const InputDecoration(labelText: '출처·라이선스 HTTPS 링크'),
            maxLines: 2,
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
