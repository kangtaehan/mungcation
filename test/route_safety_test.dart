import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/walk_data.dart';
import 'package:mungcation/services/route_safety.dart';

WalkingRoute route(List<String> instructions) =>
    WalkingRoute('경로', 500, 400, const [], instructions);

void main() {
  test('unknown route is never presented as safe', () {
    final report = assessWalkingRoute(route(['이름 없는 도로 · 500m 이동']));
    expect(report.level, RouteSafetyLevel.unknown);
    expect(report.knownFraction, 0);
    expect(report.label, contains('부족'));
  });

  test('road names never confirm sidewalk safety', () {
    final report = assessWalkingRoute(
      route(['공원 산책로 · 200m 이동', '보행로 · 300m 이동']),
    );
    expect(report.level, RouteSafetyLevel.unknown);
    expect(report.knownFraction, 0);
  });

  test('motorway evidence marks route to avoid', () {
    final report = assessWalkingRoute(route(['자동차전용도로 · 300m 이동']));
    expect(report.level, RouteSafetyLevel.avoid);
    expect(report.score, lessThan(50));
  });
}
