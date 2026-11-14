import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/walk_data.dart';
import '../services/map_service.dart';
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
  bool loading = false, searched = false, savedOnly = false;
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
      _ => '반려동물 동반 $category',
    };
    final term = [
      query.text.trim(),
      suffix,
    ].where((v) => v.isNotEmpty).join(' ');
    final effectiveTerm = term.isEmpty ? '반려동물 동반' : term;
    final request = ++serial;
    setState(() {
      loading = true;
      error = null;
      searched = true;
    });
    try {
      final results = await widget.maps.search(
        effectiveTerm,
        widget.session.current,
      );
      if (mounted && request == serial) {
        setState(() => places = results);
        widget.session.places = results;
      }
    } catch (_) {
      if (mounted && request == serial)
        setState(() => error = '장소 검색을 완료하지 못했어요. 기기의 네트워크와 지도 서비스를 확인해 주세요.');
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
            (s) =>
                query.text.trim().isEmpty ||
                '${s.place.name} ${s.place.address} ${s.note}'
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
          const Text('실제 검색 결과예요. 반려견 동반 조건은 각 장소에 직접 확인해 주세요.'),
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
            Wrap(
              spacing: 8,
              children: [
                for (final c in ['전체', '카페', '식당', '숙소', '공원', '놀이터', '동물병원'])
                  ChoiceChip(
                    label: Text(c),
                    selected: category == c,
                    onSelected: loading
                        ? null
                        : (_) {
                            setState(() => category = c);
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
              child: Text('검색 결과가 없어요. 지역이나 검색어를 바꿔 보세요.'),
            ),
          for (final place in visible)
            Card(
              color: beige,
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  place.rewardEligible ? Icons.park : Icons.storefront_outlined,
                ),
                title: Text(place.name),
                subtitle: Text('${place.address}\n반려견 동반: 확인 필요'),
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
