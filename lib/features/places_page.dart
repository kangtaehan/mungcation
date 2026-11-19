import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/walk_data.dart';
import '../models/saved_place.dart';
import '../services/map_service.dart';
import '../services/android_map_service.dart' show MapServiceFailure;
import '../services/walk_session.dart';
import 'place_details.dart';
import '../services/app_controller.dart';

class PlacesSearchPage extends StatefulWidget {
  final AppController controller;
  final MapService maps;
  final WalkSession session;
  final ValueChanged<PlaceInfo> onDestination;
  final VoidCallback onBack;
  const PlacesSearchPage({
    super.key,
    required this.maps,
    required this.controller,
    required this.session,
    required this.onDestination,
    required this.onBack,
  });
  @override
  State<PlacesSearchPage> createState() => _PlacesSearchPageState();
}

class _PlacesSearchPageState extends State<PlacesSearchPage> {
  final query = TextEditingController();
  String category = '전체';
  String savedCategory = '전체';
  static const savedKinds = {
    '카페': {'cafe'},
    '식당': {'restaurant'},
    '공공·문화': {'civic'},
    '마트·쇼핑': {'shopping'},
    '숙소': {'stay', 'hotel'},
    '공원': {'park'},
    '놀이터': {'playground'},
    '동물병원': {'hospital', 'veterinary'},
  };
  bool loading = false, searched = false, savedOnly = false;
  bool onlyAllowed = true;
  int serial = 0;
  String? error;
  List<PlaceInfo> places = [];
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (savedOnly) {
      setState(() {});
      return;
    }
    final suffix = switch (category) {
      '전체' => '',
      '공원' => '공원',
      '놀이터' => '반려견 놀이터',
      '동물병원' => '동물병원',
      '공공·문화' => '공공시설',
      '마트·쇼핑' => '마트',
      _ => category,
    };
    final term = [
      query.text.trim(),
      suffix,
    ].where((v) => v.isNotEmpty).join(' ');
    if (!onlyAllowed && term.isEmpty) {
      setState(() => error = '일반 검색은 지역·시설 이름이나 종류를 선택해 주세요.');
      return;
    }
    final effectiveTerm = onlyAllowed
        ? [
            query.text.trim(),
            '반려동물 동반',
            suffix,
          ].where((value) => value.isNotEmpty).join(' ')
        : term;
    final request = ++serial;
    setState(() {
      loading = true;
      error = null;
      searched = true;
    });
    try {
      if (widget.session.current == null && query.text.trim().isEmpty) {
        if (!await widget.session.locate()) {
          if (mounted)
            setState(
              () => error =
                  widget.session.error ?? '현재 위치를 확인하거나 지역을 함께 입력해 주세요.',
            );
          return;
        }
      }
      if (!mounted || request != serial) return;
      final results = await widget.maps.search(
        effectiveTerm,
        widget.session.current,
      );
      if (mounted && request == serial) {
        setState(() => places = results);
        widget.session.places = results;
      }
    } catch (failure) {
      if (mounted && request == serial)
        setState(
          () => error = failure is MapServiceFailure
              ? failure.message
              : '장소 검색을 완료하지 못했어요. 기기의 네트워크와 지도 서비스를 확인해 주세요.',
        );
    } finally {
      if (mounted && request == serial) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final savedPlaces = widget.controller.data.savedPlaces.values
          .where(
            (saved) =>
                savedCategory == '전체' ||
                (savedKinds[savedCategory]?.contains(saved.place.category) ??
                    false),
          )
          .where(
            (s) =>
                query.text.trim().isEmpty ||
                '${s.place.displayName} ${s.place.address} ${s.note}'
                    .toLowerCase()
                    .contains(query.text.trim().toLowerCase()),
          )
          .map((s) => s.place)
          .toList();
      final visible = savedOnly ? savedPlaces : places;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackButton(onPressed: widget.onBack),
          ),
          Text('동반 장소 찾기', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            '공개 자료의 동반 가능 여부와 입장 조건을 보여드려요. 기준일과 지점별 최신 규정은 방문 전 확인해 주세요.',
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('장소 검색'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: true,
                label: Text('즐겨찾기'),
                icon: Icon(Icons.star_border),
              ),
            ],
            selected: {savedOnly},
            onSelectionChanged: (v) => setState(() => savedOnly = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: query,
            onChanged: (_) {
              if (savedOnly) setState(() {});
            },
            onSubmitted: (_) => search(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '지역 · 매장 이름 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: loading ? null : search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          if (!savedOnly)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('동반 가능 자료가 있는 곳만'),
              subtitle: const Text('일반 검색 결과와 개인 메모는 동반 가능의 근거로 사용하지 않아요.'),
              value: onlyAllowed,
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() => onlyAllowed = value);
                      if (query.text.trim().isNotEmpty ||
                          category != '전체' ||
                          value)
                        search();
                    },
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final c in [
                '전체',
                '카페',
                '식당',
                '공공·문화',
                '마트·쇼핑',
                '숙소',
                '공원',
                '놀이터',
                '동물병원',
              ])
                ChoiceChip(
                  label: Text(c),
                  selected: (savedOnly ? savedCategory : category) == c,
                  onSelected: loading && !savedOnly
                      ? null
                      : (_) {
                          if (savedOnly) {
                            setState(() => savedCategory = c);
                            return;
                          }
                          setState(() {
                            category = c;
                            if (c == '동물병원' || c == '놀이터') onlyAllowed = false;
                          });
                          search();
                        },
                ),
            ],
          ),
          if (!savedOnly)
            TextButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                      await widget.session.locate();
                      if (!mounted) return;
                      if (widget.session.current == null) {
                        feedback(
                          context,
                          widget.session.error ?? '위치를 확인하지 못했어요.',
                        );
                      } else {
                        await search();
                      }
                    },
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('현재 위치 주변에서 찾기'),
            ),
          if (loading && !savedOnly) const LinearProgressIndicator(),
          if (error != null && !savedOnly)
            Text(error!, style: const TextStyle(color: Colors.brown)),
          if (!searched && !savedOnly)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('검색어를 입력하거나 장소 종류를 선택해 주세요.'),
            ),
          if (savedOnly && visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '저장한 장소가 없거나 검색어에 맞는 즐겨찾기가 없어요. 장소 상세에서 별을 눌러 저장할 수 있어요.',
              ),
            ),
          if (!savedOnly &&
              searched &&
              !loading &&
              error == null &&
              places.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '해당 조건의 공개 자료를 찾지 못했어요. 자료에 없다는 것이 동반 불가를 뜻하지는 않아요. 지역·시설 이름을 바꾸거나 일반 검색을 이용해 주세요.',
              ),
            ),
          for (final place in visible)
            Card(
              color: beige,
              elevation: 0,
              child: ListTile(
                leading: Icon(placeCategoryIcon(place.category)),
                title: Text(place.displayName),
                subtitle: Text(
                  [
                    place.address,
                    place.admission?.label ?? '동반 여부 미확인',
                    if (place.admission?.hasTransportInfo == true)
                      '유모차·이동장 관련 조건 있음',
                    if (savedOnly &&
                        widget
                                .controller
                                .data
                                .savedPlaces[place.id]
                                ?.preparedAt !=
                            null)
                      widget.controller.data.savedPlaces[place.id]!.preparedOn(
                            DateTime.now(),
                          )
                          ? '오늘 준비 ${widget.controller.data.savedPlaces[place.id]!.preparation.length}/${SavedPlace.preparationItems.length}'
                          : '준비 상태 다시 확인',
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => PlaceDetails(
                    place: place,
                    maps: widget.maps,
                    controller: widget.controller,
                    onRoute: () {
                      Navigator.pop(context);
                      widget.onDestination(place);
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
