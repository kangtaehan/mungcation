import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/main_preview.dart';

void main() {
  testWidgets(
    'web preview exposes the core tabs and marks native-only features',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MungcationPreviewApp());
      await tester.pumpAndSettle();
      expect(
        find.text('Safari 미리보기 · GPS, 카메라, 파일 저장은 실제 iOS 앱에서 확인'),
        findsOneWidget,
      );
      expect(find.text('멍케이션'), findsOneWidget);
      expect(find.text('산책 시작하기'), findsOneWidget);
      expect(find.text('오늘의 산책 기록'), findsOneWidget);
      await tester.tap(find.text('상점'));
      await tester.pumpAndSettle();
      expect(find.text('핑크 리본'), findsOneWidget);
      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진과 픽셀 캐릭터'));
      await tester.pump();
      expect(find.textContaining('TestFlight'), findsOneWidget);
    },
  );
}
