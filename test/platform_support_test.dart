import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/features/account_pages.dart';
import 'package:mungcation/features/history_page.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/walk_session.dart';
import 'controller_test.dart' show MemoryRepository;

void main() {
  testWidgets('photo actions respect platform support', (tester) async {
    // This test checks platform capabilities, not scrolling. Keep the photo
    // controls mounted in both VM and browser font/layout environments.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(
      MemoryRepository(AppData(pet: const PetProfile(name: '몽이'))),
    );
    await app.load();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PetEditor(controller: app)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('촬영'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final camera = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '촬영'),
    );
    expect(camera.onPressed == null, kIsWeb);
    if (kIsWeb) {
      await tester.scrollUntilVisible(
        find.text('사진 선택·촬영·픽셀 변환은 모바일 앱에서 이용해 주세요.'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('사진 선택·촬영·픽셀 변환은 모바일 앱에서 이용해 주세요.'), findsOneWidget);
    }
  });

  testWidgets('web exposes no native backup or lock-screen action', (
    tester,
  ) async {
    final app = AppController(
      MemoryRepository(AppData(pet: const PetProfile(name: '몽이'))),
    );
    await app.load();
    final session = WalkSession(app);
    addTearDown(session.dispose);
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePage(controller: app, session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged == null, kIsWeb);
    if (kIsWeb) expect(find.text('백업과 복원'), findsNothing);
  });

  testWidgets('GPX gives a platform notice before invoking native files', (
    tester,
  ) async {
    final now = DateTime.now();
    final walk = WalkRecord(
      id: 'test',
      startedAt: now,
      endedAt: now,
      seconds: 10,
      points: 0,
      xp: 0,
      samples: [GeoSample(37, 127, 5, now)],
      visits: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalkExportButton(record: walk, petName: '몽이'),
        ),
      ),
    );
    expect(
      find.text('GPX 파일 내보내기는 모바일 앱에서 이용해 주세요.'),
      kIsWeb ? findsOneWidget : findsNothing,
    );
    expect(find.byType(OutlinedButton), kIsWeb ? findsNothing : findsOneWidget);
  });
}
