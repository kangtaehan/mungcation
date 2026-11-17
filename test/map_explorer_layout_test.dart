import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/widgets/map_explorer_layout.dart';

const fullPlaceName = '서울숲 반려견과 함께 걷는 무장애 산책길 중앙 생태공원';
const detailsKey = ValueKey('walk-details-list');
const mapKey = ValueKey('map-canvas');
const searchKey = ValueKey('explorer-search-field');

Future<void> mountExplorer(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
  ValueChanged<String>? onSearch,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MapExplorerLayout(
            map: const ColoredBox(key: mapKey, color: Color(0xFFE8F0E7)),
            search: TextField(
              key: searchKey,
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: '장소를 검색하세요',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
            filters: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final label in ['공원', '카페', '동물병원'])
                  FilterChip(label: Text(label), onSelected: (_) {}),
              ],
            ),
            children: [
              for (var i = 0; i < 24; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('산책 후보 ${i + 1} · 가까운 반려견 산책 장소'),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(fullPlaceName),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expectDetailsReachable(WidgetTester tester) async {
  final list = find.byKey(detailsKey);
  expect(list, findsOneWidget);
  expect(tester.widget(list), isA<ListView>());
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(
    find.text(fullPlaceName),
    180,
    scrollable: scrollable,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  expect(
    find.text(fullPlaceName).hitTestable(),
    findsOneWidget,
    reason: '긴 장소명도 상세 목록 끝까지 스크롤해 읽을 수 있어야 합니다.',
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'phone $size keeps the map behind an expandable details sheet',
      (tester) async {
        var enteredSearch = '';
        await mountExplorer(
          tester,
          size,
          onSearch: (value) => enteredSearch = value,
        );

        expect(
          tester.getRect(find.byKey(mapKey)),
          Rect.fromLTWH(0, 0, size.width, size.height),
          reason: '모바일 지도는 상세 시트 뒤까지 전체 화면을 차지해야 합니다.',
        );
        final sheet = tester.widget<DraggableScrollableSheet>(
          find.byType(DraggableScrollableSheet),
        );
        expect(sheet.initialChildSize, .38);
        expect(sheet.minChildSize, .18);
        expect(sheet.maxChildSize, .9);
        await tester.enterText(find.byKey(searchKey), '서울숲');
        expect(enteredSearch, '서울숲');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        final initialHeight = tester.getSize(find.byKey(detailsKey)).height;
        final initialInset = tester
            .widget<MapSheetInset>(find.byType(MapSheetInset))
            .bottom;
        await tester.tap(find.byTooltip('산책 정보 펼치기'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(detailsKey)).height,
          greaterThan(initialHeight),
          reason: '펼치기 버튼으로 실제 상세 영역이 커져야 합니다.',
        );
        expect(
          tester.widget<MapSheetInset>(find.byType(MapSheetInset)).bottom,
          greaterThan(initialInset),
          reason: 'Map attribution must follow the expanded sheet.',
        );
        await expectDetailsReachable(tester);
      },
    );
  }

  testWidgets('small phone supports double text size without overflow', (
    tester,
  ) async {
    await mountExplorer(tester, const Size(320, 568), textScale: 2);

    expect(find.byKey(searchKey).hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byKey(mapKey)), const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('산책 정보 펼치기'));
    await tester.pumpAndSettle();
    await expectDetailsReachable(tester);
  });

  testWidgets(
    'desktop uses a 360px side panel with independently scrollable details',
    (tester) async {
      await mountExplorer(tester, const Size(1024, 768));

      expect(find.byType(DraggableScrollableSheet), findsNothing);
      final mapBounds = tester.getRect(find.byKey(mapKey));
      expect(mapBounds.width, closeTo(1024 - 360, 1));
      expect(mapBounds.height, 768);
      final detailsBounds = tester.getRect(find.byKey(detailsKey));
      expect(detailsBounds.width, lessThanOrEqualTo(360));
      expect(
        detailsBounds.width,
        greaterThanOrEqualTo(312),
        reason: '상세 목록은 360px 사이드 패널 안에서 충분한 읽기 너비가 필요합니다.',
      );
      await tester.enterText(find.byKey(searchKey), '중앙공원');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, '중앙공원');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectDetailsReachable(tester);
    },
  );
}
