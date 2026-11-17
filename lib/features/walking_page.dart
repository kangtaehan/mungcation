import '../services/android_map_service.dart';
import 'place_details.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/walk_data.dart';
import '../services/app_controller.dart';
import '../services/map_service.dart';
import '../services/nearby_walk_planner.dart';
import '../services/route_safety.dart';
import '../services/walk_session.dart';
import '../services/walk_navigation.dart';
import '../widgets/walk_map.dart';
import 'history_page.dart';
import '../widgets/map_explorer_layout.dart';

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
  List<PlaceInfo> nearbyCandidates = [];
  List<WalkingRoute> routes = [];
  List<WalkingRoute> returnRoutes = [];
  int selectedRoute = 0, centerRequest = 0, _request = 0;
  bool loading = false, finishing = false;
  bool discoveredNearby = false;
  String? error;
  String? nearbySummary;
  PlaceInfo? destination;
  GeoSample? nearbyCenter;
  late int nearbyMinutes;
  DateTime? lastReroute;
  WalkNavigator? navigator;
  GeoSample? routeOrigin;
  bool returningHome = false;
  bool routeIsReturnOnly = false;
  @override
  void initState() {
    super.initState();
    nearbyMinutes = nearbyTargetMinutes(
      widget.controller.data.pet?.size ?? '소형견',
    );
    widget.session.addListener(handleNavigationUpdate);
  }

  WalkingRoute? get plannedRoute {
    if (routes.isEmpty) return null;
    if (routeIsReturnOnly) return routes[selectedRoute];
    return roundTripRoute(
      routes[selectedRoute],
      returning:
          returnRoutes.elementAtOrNull(selectedRoute) ??
          returnRoutes.firstOrNull,
    );
  }

  void handleNavigationUpdate() {
    final route = plannedRoute, current = widget.session.current;
    if (route == null ||
        current == null ||
        destination == null ||
        widget.session.status != WalkStatus.recording ||
        loading) {
      return;
    }
    if (distanceBetween(current, destination!.location) <= 30)
      returningHome = true;
    final guidance =
        navigator?.update(current) ?? navigationGuidance(route, current);
    final now = DateTime.now();
    if (guidance.offRoute &&
        (lastReroute == null ||
            now.difference(lastReroute!) > const Duration(seconds: 45))) {
      lastReroute = now;
      final target = destination;
      final request = _request;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            target != null &&
            destination == target &&
            request == _request &&
            widget.session.isRecording) {
          routeTo(target, closeSheet: false, rerouting: true);
        }
      });
    }
  }

  void applyNearbyMinutes(int minutes) {
    final center = nearbyCenter;
    if (center == null) return;
    final selection = selectNearbyWalkPlacesForMinutes(
      center,
      nearbyCandidates,
      minutes,
    );
    setState(() {
      nearbyMinutes = minutes;
      places = selection.places;
      nearbySummary = selection.usedFallback
          ? '왕복 $minutes분 이내 장소가 없어 가장 가까운 후보를 보여드려요.'
          : '예상 왕복 $minutes분 이내 ${places.length}곳을 가까운 순서로 보여드려요.';
      centerRequest++;
    });
    widget.session.places = places;
  }

  @override
  void dispose() {
    widget.session.removeListener(handleNavigationUpdate);
    query.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WalkingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible &&
        !oldWidget.visible &&
        !discoveredNearby &&
        widget.session.current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => discoverNearby());
    }
  }

  Future<void> discoverNearby() async {
    if (loading || discoveredNearby) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!await widget.session.locate()) {
        if (mounted) {
          setState(() => error = widget.session.error ?? '현재 위치를 확인하지 못했어요.');
        }
        return;
      }
      if (!mounted) return;
      final center = widget.session.current;
      if (center == null) {
        setState(() => error = '현재 위치를 확인하면 주변 산책 장소를 보여드려요.');
        return;
      }
      final results = await Future.wait([
        widget.maps.search('공원', center),
        widget.maps.search('애견 카페', center),
        widget.maps.search('동물병원', center),
      ]);
      final unique = <String, PlaceInfo>{};
      for (final place in results.expand((items) => items)) {
        unique.putIfAbsent(place.id, () => place);
      }
      if (mounted) {
        final dogSize = widget.controller.data.pet?.size ?? '소형견';
        final selection = selectNearbyWalkPlaces(
          center,
          unique.values,
          dogSize,
        );
        setState(() {
          nearbyCandidates = unique.values.toList();
          nearbyCenter = center;
          nearbyMinutes = selection.targetMinutes;
          places = selection.places;
          discoveredNearby = true;
          centerRequest++;
          nearbySummary = selection.usedFallback
              ? '$dogSize 권장 왕복 ${selection.targetMinutes}분 이내 장소가 없어 가장 가까운 후보를 보여드려요.'
              : '$dogSize 기준 예상 왕복 ${selection.targetMinutes}분 이내 장소를 가까운 순서로 보여드려요.';
          if (places.isEmpty) error = '권장 산책 시간에 맞는 주변 장소를 찾지 못했어요.';
        });
        widget.session.places = places;
      }
    } catch (_) {
      if (mounted) setState(() => error = '주변 장소를 불러오지 못했어요. 검색으로 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
        setState(() {
          places = found;
          nearbySummary = null;
          nearbyCandidates = [];
          nearbyCenter = null;
        });
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

  Future<void> routeTo(
    PlaceInfo place, {
    bool closeSheet = true,
    bool rerouting = false,
  }) async {
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
    if (!rerouting) {
      routeOrigin = widget.session.current;
      returningHome = false;
      routeIsReturnOnly = false;
      navigator = null;
    }
    setState(() {
      loading = true;
      error = null;
      destination = place;
      routes = [];
      returnRoutes = [];
      selectedRoute = 0;
    });
    try {
      final start = widget.session.current!;
      final home = PlaceInfo(
        id: 'walk-start',
        name: '출발 위치',
        address: '',
        category: 'start',
        location: routeOrigin ?? start,
        fetchedAt: DateTime.now(),
        source: '기기 위치',
      );
      final found = await widget.maps.directions(
        start,
        returningHome ? home : place,
      );
      var returning = <WalkingRoute>[];
      if (found.isNotEmpty && !returningHome) {
        try {
          returning = await widget.maps.directions(place.location, home);
          if (rerouting && returning.isEmpty) {
            throw StateError('귀환 경로를 제공하지 못했어요.');
          }
        } catch (_) {
          // Reversing a rerouted outward leg would return to the wrong start.
          if (rerouting) rethrow;
          returning = [];
        }
      }
      if (mounted && request == _request)
        setState(() {
          routes = found;
          returnRoutes = returning;
          routeIsReturnOnly = returningHome;
          final planned = plannedRoute;
          if (planned != null) {
            navigator = WalkNavigator(planned, origin: routeOrigin ?? start);
          }
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

  Widget placeStrip(String title, List<PlaceInfo> items, {IconData? icon}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 20, color: forest),
              if (icon != null) const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final place in items)
            Card(
              key: ValueKey('suggestion-${place.id}'),
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Icon(
                  place.rewardEligible ? Icons.park : Icons.pets,
                  color: forest,
                ),
                title: Text(
                  place.displayName,
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.session.current == null
                      ? place.category
                      : '예상 왕복 ${estimatedRoundTripMinutes(widget.session.current!, place).ceil()}분',
                  softWrap: true,
                ),
                onTap: () => showPlace(place),
              ),
            ),
        ],
      ),
    );
  }

  Widget explorerSearch() => Material(
    color: paper,
    elevation: 3,
    shadowColor: const Color(0x160D2917),
    borderRadius: BorderRadius.circular(20),
    child: TextField(
      controller: query,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => search(),
      decoration: InputDecoration(
        hintText: '공원 · 카페 · 목적지 검색',
        prefixIcon: const Icon(Icons.search_rounded, color: forest, size: 22),
        suffixIcon: IconButton(
          tooltip: '검색',
          onPressed: loading ? null : search,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
        ),
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget explorerFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ActionChip(
          avatar: const Icon(Icons.near_me_outlined, size: 16),
          label: const Text('내 주변'),
          onPressed: loading
              ? null
              : () {
                  discoveredNearby = false;
                  discoverNearby();
                },
        ),
        for (final entry in const {
          '공원': Icons.park_outlined,
          '카페': Icons.local_cafe_outlined,
          '동물병원': Icons.local_hospital_outlined,
        }.entries) ...[
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(entry.value, size: 16),
            label: Text(entry.key),
            onPressed: loading
                ? null
                : () async {
                    query.text = entry.key;
                    if (widget.session.current == null &&
                        !await widget.session.locate())
                      return;
                    if (mounted) await search();
                  },
          ),
        ],
      ],
    ),
  );

  Widget explorerHeading() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text('함께 걷는 길', style: Theme.of(context).textTheme.titleLarge),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: mist,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            places.isEmpty ? '산책 준비' : '${places.length}곳',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: forest,
            ),
          ),
        ),
      ],
    ),
  );

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
    setState(() {
      finishing = false;
      if (result != null) {
        routes = [];
        returnRoutes = [];
        navigator = null;
        destination = null;
        returningHome = false;
        routeIsReturnOnly = false;
      }
    });
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
              finishing,
          safetyReports = routes.map(assessWalkingRoute).toList(),
          planned = plannedRoute,
          guidance = planned == null || walk.current == null
              ? null
              : navigator?.update(walk.current!) ??
                    navigationGuidance(planned, walk.current!),
          pointPlaces = places.where((place) => place.rewardEligible).toList(),
          recommendedPlaces = places
              .where((place) => !place.rewardEligible)
              .toList(),
          recentVisits = widget.controller.data.realWalks.reversed
              .expand((record) => record.visits.reversed)
              .map((visit) => visit.name)
              .toSet()
              .take(8)
              .toList();
      return MapExplorerLayout(
        map: WalkMap(
          showBadge: false,
          enabled: widget.visible,
          samples: walk.samples,
          current: walk.current,
          route: planned?.samples ?? const [],
          places: places,
          placeLabels: {
            if (walk.current case final current?)
              for (final place in places)
                place.id:
                    '왕복 약 ${estimatedRoundTripMinutes(current, place).ceil()}분',
          },
          centerRequest: centerRequest,
          routeColor: routes.isEmpty
              ? const Color(0xFF28734E)
              : safetyReports[selectedRoute].color,
          onPlace: (id) {
            final place = places.where((p) => p.id == id).firstOrNull;
            if (place != null) showPlace(place);
          },
        ),
        search: explorerSearch(),
        filters: explorerFilters(),
        children: [
          explorerHeading(),
          const SizedBox(height: 8),
          if (!walk.hasWalk)
            FilledButton.icon(
              onPressed: waiting ? null : begin,
              icon: const Icon(Icons.pets),
              label: Text(
                waiting
                    ? '위치 확인 중…'
                    : routes.isNotEmpty
                    ? '이 경로로 산책 시작'
                    : '산책 시작하기',
              ),
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
          if (nearbySummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                nearbySummary!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (discoveredNearby)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '주변 장소 시간은 직선거리 기반 예상값이에요. 선택 후 실제 도보 경로 시간을 확인해 주세요. 크기별 시간은 기본 필터이며 건강·나이에 맞춰 조절해 주세요.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (discoveredNearby && nearbyCandidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final minutes in const [30, 45, 60])
                    ChoiceChip(
                      label: Text('$minutes분 이내'),
                      selected: nearbyMinutes == minutes,
                      onSelected: loading
                          ? null
                          : (_) => applyNearbyMinutes(minutes),
                    ),
                ],
              ),
            ),
          if (planned != null && guidance != null)
            Card(
              margin: const EdgeInsets.only(top: 10),
              elevation: 0,
              color: guidance.offRoute
                  ? const Color(0xFFFFE7DF)
                  : const Color(0xFFE7F3EA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: guidance.offRoute
                          ? Colors.deepOrange
                          : forest,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.pets),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guidance.offRoute
                                ? '경로를 벗어나 다시 찾고 있어요'
                                : guidance.instruction,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '남은 ${(guidance.remainingMeters / 1000).toStringAsFixed(2)}km · 약 ${(guidance.remainingSeconds / 60).ceil()}분',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: waiting
                  ? null
                  : () async {
                      if (await walk.locate() && mounted) {
                        setState(() => centerRequest++);
                      } else if (mounted) {
                        feedback(context, walk.error ?? '현재 위치를 확인하지 못했어요.');
                      }
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
              title: Text('목적지 · ${destination!.displayName}'),
              trailing: IconButton(
                tooltip: '목적지 해제',
                onPressed: () {
                  _request++;
                  setState(() {
                    destination = null;
                    routes = [];
                    returnRoutes = [];
                    loading = false;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ),
          if (routes.isNotEmpty)
            Card(
              elevation: 0,
              color: const Color(0xFFF6F1E7),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.pets, color: forest, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routeIsReturnOnly
                                ? '출발 위치로 귀환'
                                : destination?.displayName ?? '선택한 산책 경로',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '편도 ${(routes[selectedRoute].meters / 1000).toStringAsFixed(2)} km · 약 ${(routes[selectedRoute].seconds / 60).ceil()}분',
                          ),
                          Text(
                            '${routeIsReturnOnly ? '귀환' : '왕복'} ${(planned!.meters / 1000).toStringAsFixed(2)} km · 약 ${(planned.seconds / 60).ceil()}분',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            routeIsReturnOnly
                                ? '원래 출발 위치로 돌아가는 경로'
                                : returnRoutes.isEmpty
                                ? '같은 길로 돌아오는 코스'
                                : '다른 귀환 경로를 포함한 코스',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            safetyReports[selectedRoute].label,
                            style: TextStyle(
                              color: safetyReports[selectedRoute].color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (routes.isNotEmpty)
            RadioGroup<int>(
              groupValue: selectedRoute,
              onChanged: (v) => setState(() {
                selectedRoute = v!;
                final route = plannedRoute;
                if (route != null && routeOrigin != null) {
                  navigator = WalkNavigator(route, origin: routeOrigin!);
                }
              }),
              child: Column(
                children: [
                  for (var i = 0; i < routes.length; i++)
                    RadioListTile<int>(
                      value: i,
                      title: Text(
                        '${i == 0 ? '가장 빠른 제공 경로' : '대안 경로 $i'} · ${(routes[i].meters / 1000).toStringAsFixed(2)} km',
                      ),
                      subtitle: Text(
                        '가는 길 약 ${(routes[i].seconds / 60).ceil()}분 · ${safetyReports[i].label}',
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: safetyReports[i].color,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.info_outline),
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
                  final report = safetyReports[selectedRoute];
                  return AlertDialog(
                    title: const Text('인도 안전 정보'),
                    content: Text(
                      '${report.label}\n\n${report.reasons.map((reason) => '• $reason').join('\n')}\n\n미확인은 인도가 없다는 뜻이 아니에요. 주의 표시는 경로 안내의 도로 표현에 따른 참고 정보이며 실제 인도와 현장 안전은 확인되지 않았어요.',
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
              '현재 공급자는 실제 인도·횡단보도 데이터를 제공하지 않아요. 안전 우선 경로를 보장하지 않으며 공사·조명·차량 상황을 직접 확인해 주세요.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          placeStrip(
            '${widget.controller.data.pet?.name ?? '강아지'}와 함께하는 추천 산책',
            recommendedPlaces,
            icon: Icons.route_outlined,
          ),
          placeStrip(
            '포인트를 받을 수 있는 산책 장소',
            pointPlaces,
            icon: Icons.stars_outlined,
          ),
          if (recentVisits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최근 방문한 장소',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in recentVisits)
                        Chip(
                          avatar: const Icon(Icons.history, size: 17),
                          label: Text(name),
                        ),
                    ],
                  ),
                ],
              ),
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
              title: Text(place.displayName),
              subtitle: Text(
                place.rewardEligible
                    ? '공원 · 자동 방문 인증 시 최대 +30P'
                    : place.address,
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
