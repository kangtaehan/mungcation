import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/main.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/widgets/pet_room.dart';
import 'controller_test.dart' show MemoryRepository;
import 'walk_test.dart' show FakeLocation, makeDraft;
import 'package:mungcation/models/walk_data.dart';

void main() {
  testWidgets('first launch saves a pet and opens home', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository();
    await tester.pumpWidget(MungcationApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '몽이');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('기본 캐릭터로 시작하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본 캐릭터로 시작하기'));
    await tester.pumpAndSettle();
    expect((await repo.load()).pet?.name, '몽이', reason: '등록 데이터가 저장되어야 해요');
    expect(find.text('산책 시작하기'), findsOneWidget);
    expect((await repo.load()).pet!.name, '몽이');
    expect(tester.takeException(), isNull);
  });
  testWidgets('shop purchases a visual accessory and removes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository(
      AppData(pet: const PetProfile(name: '몽이'), coins: 100),
    );
    await tester.pumpWidget(MungcationApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상점'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('구매 · 장착').first);
    await tester.tap(find.text('구매 · 장착').first);
    await tester.pumpAndSettle();
    expect((await repo.load()).equipped, 'ribbon');
    expect((await repo.load()).coins, 70);
    await tester.scrollUntilVisible(
      find.byType(PetRoom),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PetRoom>(find.byType(PetRoom).last).equipped,
      'ribbon',
    );
    await tester.scrollUntilVisible(
      find.text('해제'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('해제'));
    await tester.pumpAndSettle();
    expect((await repo.load()).equipped, 'none');
    expect(tester.takeException(), isNull);
  });
  testWidgets('recovered walk can be finished and viewed as a real record', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final repo = MemoryRepository(
      AppData(
        pet: const PetProfile(name: '몽이'),
        draft: makeDraft('recovered', now.subtract(const Duration(minutes: 3))),
      ),
    );
    final source = FakeLocation(GeoSample(37, 127, 5, now));
    await tester.pumpWidget(
      MungcationApp(repository: repo, locationSource: source),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('산책 종료'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('산책 종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('산책 종료').last);
    await tester.pumpAndSettle();
    expect((await repo.load()).realWalks.single.id, 'recovered');
    expect((await repo.load()).coins, 40);
    expect(find.text('산책 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await source.events.close();
  });
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('main tabs fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MungcationApp(
          repository: MemoryRepository(
            AppData(pet: const PetProfile(name: '몽이')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in ['지도', '상점', '마이', '홈']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
