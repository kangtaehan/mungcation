import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/pet_admission.dart';
import 'package:mungcation/widgets/pet_admission_panel.dart';

void main() {
  testWidgets(
    'small screen shows complete admission alternatives, areas and source dates',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final policy = PetAdmission(
        status: PetAdmissionStatus.conditional,
        conditions: '유모차 또는 캐리어 중 하나를 지참해 덮개를 닫아 주세요.',
        transportRule: '유모차 또는 캐리어 중 하나를 지참해 덮개를 닫아 주세요.',
        areaRule: '공용부 허용 · 식품매장 및 식당가 제외',
        sizeRule: '5kg 미만',
        rentalRule: '대여 없음',
        sourceName: '공식 운영사',
        sourceUrl: 'https://example.org/policy',
        referenceDate: DateTime(2025, 3, 24),
      );
      var opened = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PetAdmissionPanel(
                policy: policy,
                onOpenSource: (url) async {
                  opened = url;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(policy.transportRule), findsWidgets);
      expect(find.text('공용부 허용 · 식품매장 및 식당가 제외'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('원문 보기'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('원문 보기'));
      await tester.pumpAndSettle();
      expect(opened, policy.sourceUrl);
      expect(find.textContaining('2025-03-24'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unverified place does not appear allowed and missing gear rules stay unknown',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PetAdmissionPanel()),
          ),
        ),
      );
      expect(find.text('동반 여부 미확인'), findsOneWidget);
      expect(find.textContaining('유모차·캐리어 필요 여부 미확인'), findsOneWidget);
      expect(find.text('자료상 동반 가능'), findsNothing);
      expect(find.text('원문 보기'), findsNothing);
    },
  );
}
