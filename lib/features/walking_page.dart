import '../services/android_map_service.dart';
import 'place_details.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/walk_data.dart';
import '../services/app_controller.dart';
import '../services/map_service.dart';
import '../services/walk_session.dart';
import '../widgets/walk_map.dart';
import 'history_page.dart';

class WalkingPage extends StatefulWidget {
  final AppController controller;
  final WalkSession session;
  final MapService maps;
  final bool visible;
  const WalkingPage({
    super.key,
    required this.controller,
    required this.session,
    required this.maps,
    this.visible = true,
  });
  @override
  State<WalkingPage> createState() => WalkingPageState();
}

class WalkingPageState extends State<WalkingPage> {
  final query = TextEditingController();
  List<PlaceInfo> places = [];
  List<WalkingRoute> routes = [];
  int selectedRoute = 0, centerRequest = 0, _request = 0;
  bool loading = false, finishing = false;
  String? error;
  PlaceInfo? destination;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (query.text.trim().isEmpty) return;
    final request = ++_request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final found = await widget.maps.search(
        query.text.trim(),
        widget.session.current,
      );
      if (mounted && request == _request) {
        setState(() => places = found);
        widget.session.places = found;
      }
    } catch (e) {
      if (mounted && request == _request)
        setState(
          () => error = e is MapServiceFailure
              ? e.message
              : '장소를 검색하지 못했어요. 네트워크와 지도 연결을 확인해 주세요.',
        );
    } finally {
      if (mounted && request == _request) setState(() => loading = false);
    }
  }

  Future<void> routeTo(PlaceInfo place, {bool closeSheet = true}) async {
    if (closeSheet) Navigator.maybePop(context);
    if (!places.any((p) => p.id == place.id)) places = [place, ...places];
    if (widget.session.current == null) {
      await widget.session.locate();
      if (!mounted) return;
    }
    final current = widget.session.current;
    if (current == null) {
      feedback(context, '현재 위치를 먼저 확인해 주세요.');
      return;
    }
    if (DateTime.now().difference(current.time) > const Duration(minutes: 2)) {
      await widget.session.locate();
      if (!mounted) return;
    }
    final request = ++_request;
    setState(() {
      loading = true;
      error = null;
      destination = place;
      routes = [];
      selectedRoute = 0;
    });
    try {
      final found = await widget.maps.directions(
        widget.session.current!,
        place,
      );
      if (mounted && request == _request)
        setState(() {
          routes = found;
          if (found.isEmpty) error = '이 지역의 도보 경로를 제공하지 못해요. 다른 목적지를 선택해 주세요.';
        });
    } catch (_) {
      if (mounted && request == _request)
        setState(
          () =>
              error = '도보 경로를 가져오지 못했어요. 이 지역에서는 제공되지 않거나 네트워크 연결이 필요할 수 있어요.',
        );
    } finally {
      if (mounted && request == _request) setState(() => loading = false);
    }
  }

  Future<void> showPlace(PlaceInfo place) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlaceDetails(
        place: place,
        maps: widget.maps,
        controller: widget.controller,
        onRoute: () => routeTo(place),
      ),
    );
  }

  Future<void> begin() async {
    final agreed = await confirm(
      context,
      '산책 위치 기록',
      '산책 중 위치·시간·이동 경로를 이 기기에 저장해요. 종료하면 위치 수집을 멈추며, 마이에서 기록을 삭제할 수 있어요.\n\n${widget.controller.data.backgroundLocation ? '화면을 잠가도 산책 중 위치 기록을 이어갑니다.' : '앱을 벗어나면 자동으로 일시정지해요. 마이에서 잠금 화면 기록을 켤 수 있어요.'}',
      action: '동의하고 시작',
    );
    if (agreed) await widget.session.start();
  }

  Future<void> finish() async {
    if (finishing) return;
    if (!await confirm(
          context,
          '산책을 마칠까요?',
          '현재까지 기록한 경로와 시간을 저장해요.',
          action: '산책 종료',
        ) ||
        !mounted)
      return;
    setState(() => finishing = true);
    final result = await widget.session.finish();
    if (!mounted) return;
    setState(() => finishing = false);
    if (result != null)
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              WalkResultPage(record: result, controller: widget.controller),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final walk = widget.session,
          active = walk.status == WalkStatus.recording,
          waiting =
              walk.status == WalkStatus.locating ||
              walk.status == WalkStatus.saving ||
              finishing;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('함께 걷는 길', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: '공원 · 카페 · 목적지 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: loading ? null : search,
                icon: const Icon(Icons.arrow_forward),
              ),
              filled: true,
              fillColor: beige,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: WalkMap(
                enabled: widget.visible,
                samples: walk.samples,
                current: walk.current,
                route: routes.isEmpty ? [] : routes[selectedRoute].samples,
                places: places,
                centerRequest: centerRequest,
                onPlace: (id) {
                  final place = places.where((p) => p.id == id).firstOrNull;
                  if (place != null) showPlace(place);
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: waiting
                  ? null
                  : () async {
                      await walk.locate();
                      if (mounted) setState(() => centerRequest++);
                    },
              icon: const Icon(Icons.my_location),
              label: const Text('현재 위치'),
            ),
          ),
          if (walk.current == null)
            const Text('현재 위치를 누르거나 산책을 시작하면 위치 권한을 요청해요.'),
          if (walk.current != null)
            Text(
              '마지막 위치 정확도 ±${walk.current!.accuracy.round()}m · ${dateLabel(walk.current!.time)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(error!, style: const TextStyle(color: Colors.brown)),
            ),
          if (walk.error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(walk.error!, style: const TextStyle(color: Colors.brown)),
                TextButton(
                  onPressed: walk.source.settings,
                  child: const Text('기기 설정 열기'),
                ),
              ],
            ),
          if (destination != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('목적지 · ${destination!.name}'),
              trailing: IconButton(
                tooltip: '목적지 해제',
                onPressed: () {
                  _request++;
                  setState(() {
                    destination = null;
                    routes = [];
                    loading = false;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ),
          if (routes.isNotEmpty)
            RadioGroup<int>(
              groupValue: selectedRoute,
              onChanged: (v) => setState(() => selectedRoute = v!),
              child: Column(
                children: [
                  for (var i = 0; i < routes.length; i++)
                    RadioListTile<int>(
                      value: i,
                      title: Text(
                        '${i == 0 ? '가장 빠른 제공 경로' : '대안 경로 $i'} · ${(routes[i].meters / 1000).toStringAsFixed(2)} km',
                      ),
                      subtitle: Text(
                        '약 ${(routes[i].seconds / 60).ceil()}분 · 인도 정보 미확인',
                      ),
                    ),
                ],
              ),
            ),
          if (routes.isNotEmpty)
            ExpansionTile(
              title: const Text('도보 안내'),
              children: [
                for (final instruction in routes[selectedRoute].instructions)
                  ListTile(title: Text(instruction)),
              ],
            ),
          if (routes.isNotEmpty)
            Text(
              '경로 출처: ${routes[selectedRoute].source}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          if (routes.isNotEmpty)
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) {
                  final report = evaluateSafety([
                    SafetySegment(
                      routes[selectedRoute].meters,
                      true,
                      SidewalkStatus.unknown,
                    ),
                  ]);
                  return AlertDialog(
                    title: const Text('인도 안전 정보'),
                    content: Text(
                      '인도 확인 데이터: ${(report.knownFraction * 100).round()}%\n\n인도 확인: 0%\n인도 없음 확인: 0%\n인도 정보 미확인: 100%\n\n미확인은 인도가 없다는 뜻이 아니에요. 현재 지도 공급자는 인도·횡단보도 정보를 제공하지 않아 안전 우선 경로를 비교할 수 없어요.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인'),
                      ),
                    ],
                  );
                },
              ),
              icon: const Icon(Icons.shield_outlined),
              label: const Text('인도 안전 정보 확인'),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '제공되는 도보 경로는 지도 서비스와 지역에 따라 달라질 수 있어요. 인도·횡단보도 안전성은 확인되지 않았으며, 안전 우선 경로를 보장하지 않아요.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          if (walk.hasWalk)
            Card(
              color: beige,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${(walk.meters / 1000).toStringAsFixed(2)} km · ${durationLabel(walk.seconds)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(active ? '산책 기록 중' : '산책 일시정지'),
                    Text('방문 인증 ${walk.visits.length}곳 · GPS로 자동 확인'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (!walk.hasWalk)
            FilledButton.icon(
              onPressed: waiting ? null : begin,
              icon: const Icon(Icons.pets),
              label: Text(waiting ? '위치 확인 중…' : '산책 시작하기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: waiting
                      ? null
                      : active
                      ? walk.pause
                      : walk.resume,
                  icon: Icon(active ? Icons.pause : Icons.play_arrow),
                  label: Text(active ? '일시정지' : '이어서 걷기'),
                ),
                OutlinedButton(
                  onPressed: waiting ? null : finish,
                  child: Text(finishing ? '저장 중…' : '산책 종료'),
                ),
                TextButton(
                  onPressed: waiting
                      ? null
                      : () async {
                          if (await confirm(
                                context,
                                '이 산책을 버릴까요?',
                                '현재 산책의 경로·시간을 삭제하며 보상은 지급하지 않아요.',
                                action: '버리기',
                              ) &&
                              mounted)
                            await saveAction(context, () async {
                              await walk.discard();
                              return true;
                            });
                        },
                  child: const Text('기록 버리기'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (places.isNotEmpty)
            const Text(
              '검색 결과 · 동반 조건은 방문 전 확인해 주세요.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          for (final place in places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                place.rewardEligible ? Icons.park : Icons.place_outlined,
              ),
              title: Text(place.name),
              subtitle: Text(
                place.rewardEligible
                    ? '공원 · 자동 방문 인증 시 최대 +30P'
                    : place.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => showPlace(place),
            ),
          if (!loading &&
              places.isEmpty &&
              query.text.isNotEmpty &&
              error == null)
            const Text('검색 결과가 없거나 아직 검색하지 않았어요.'),
        ],
      );
    },
  );
}
