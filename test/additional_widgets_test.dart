import 'package:mungcation/services/media_store.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/features/data_tools_page.dart';
import 'package:mungcation/features/place_details.dart';
import 'package:mungcation/features/places_page.dart';
import 'package:mungcation/features/walk_history_page.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/saved_place.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/backup_service.dart';
import 'package:mungcation/services/map_service.dart';
import 'package:mungcation/services/walk_session.dart';
import 'additional_features_test.dart'
    show FakeTransfer, savedFixture, historyFixture;
import 'controller_test.dart' show MemoryRepository;
import 'walk_test.dart' show FakeLocation;

class NoPhotoMediaStore extends MediaStore {
  @override
  Future<void> removeUnreferenced(Set<String> retained) async {}
}

class FakeMaps implements MapService {
  final List<String> queries = [];
  @override
  Future<List<PlaceInfo>> search(String query, GeoSample? center) async {
    queries.add(query);
    return [savedFixture()];
  }

  @override
  Future<List<WalkingRoute>> directions(GeoSample start, PlaceInfo end) async =>
      [];
  @override
  Future<void> openPlace(PlaceInfo place) async {}
}

void phoneSize(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('search combines region and category, favorites stay offline', (
    tester,
  ) async {
    phoneSize(tester);
    final maps = FakeMaps(),
        app = AppController(
          MemoryRepository(
            AppData(
              pet: const PetProfile(name: '몽이'),
              savedPlaces: {'park': SavedPlace(place: savedFixture())},
            ),
          ),
        );
    await app.load();
    final source = FakeLocation(GeoSample(37, 127, 5, DateTime.now())),
        session = WalkSession(app, source: source);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesSearchPage(
            maps: maps,
            controller: app,
            session: session,
            onDestination: (_) {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '강남');
    await tester.tap(find.text('카페'));
    await tester.pumpAndSettle();
    expect(maps.queries.single, '강남 반려동물 동반 카페');
    await tester.tap(find.text('즐겨찾기'));
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('내 공원'), findsOneWidget);
    expect(maps.queries.length, 1);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    app.dispose();
    await source.events.close();
  });
  testWidgets('personal place notes save without implying an official policy', (
    tester,
  ) async {
    phoneSize(tester);
    final app = AppController(
      MemoryRepository(AppData(pet: const PetProfile(name: '몽이'))),
    );
    await app.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetails(
            place: savedFixture(),
            maps: FakeMaps(),
            controller: app,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('내 동반 조건 메모'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 동반 조건 메모'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '목줄 필수, 실외 좌석 문의');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('즐겨찾기와 메모 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('즐겨찾기와 메모 저장'));
    await tester.pumpAndSettle();
    expect(app.data.savedPlaces['park']!.note, '목줄 필수, 실외 좌석 문의');
    expect(app.data.savedPlaces['park']!.access, PetAccess.unknown);
    await tester.scrollUntilVisible(
      find.text('내가 기록한 정보 · 공식 확인 아님'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('내가 기록한 정보 · 공식 확인 아님'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('calendar and statistics fit a small screen and select one day', (
    tester,
  ) async {
    phoneSize(tester, size: const Size(320, 568));
    final semantics = tester.ensureSemantics();
    final now = DateTime.now(),
        day = DateTime(now.year, now.month, now.day, 10);
    final app = AppController(
      MemoryRepository(
        AppData(
          pet: const PetProfile(name: '몽이'),
          realWalks: [
            historyFixture('today', day),
            historyFixture(
              'previous',
              DateTime(day.year, day.month, day.day - 1),
            ),
          ],
        ),
      ),
    );
    await app.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: WalkHistoryPage(controller: app),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.bySemanticsLabel(
      RegExp('${day.month}월 ${day.day}일, 산책 1회'),
    );
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('${day.month}월 ${day.day}일 기록'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('${day.month}월 ${day.day}일 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
    app.dispose();
  });
  testWidgets('backup restore requires confirmation and updates current data', (
    tester,
  ) async {
    phoneSize(tester);
    final app = AppController(
      MemoryRepository(AppData(pet: const PetProfile(name: '현재'))),
    );
    await app.load();
    final source = FakeLocation(GeoSample(37, 127, 5, DateTime.now())),
        session = WalkSession(app, source: source),
        transfer = FakeTransfer();
    transfer.picked = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'mungcation-backup',
          'version': 1,
          'createdAt': DateTime.now().toIso8601String(),
          'data': AppData(
            pet: const PetProfile(name: '복원된 친구'),
            coins: 50,
          ).toJson(),
          'media': {},
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DataToolsPage(
          controller: app,
          session: session,
          backup: BackupService(transfer: transfer, media: NoPhotoMediaStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('백업 파일에서 복원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('이 백업으로 교체할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(app.data.pet!.name, '현재');
    await tester.tap(find.text('백업 파일에서 복원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('백업으로 교체'));
    await tester.pumpAndSettle();
    expect(app.data.pet!.name, '복원된 친구');
    expect(app.data.coins, 50);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    app.dispose();
    await source.events.close();
  });
}
