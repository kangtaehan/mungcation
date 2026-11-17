import 'package:flutter/material.dart';

import '../models/walk_data.dart';

enum RouteSafetyLevel { preferred, moderate, caution, unknown, avoid }

class RouteSafetyReport {
  final int score;
  final double knownFraction;
  final RouteSafetyLevel level;
  final List<String> reasons;

  const RouteSafetyReport({
    required this.score,
    required this.knownFraction,
    required this.level,
    required this.reasons,
  });

  String get label => switch (level) {
    RouteSafetyLevel.preferred => '안전 정보가 많은 경로',
    RouteSafetyLevel.moderate => '보행 적합 정보 있음',
    RouteSafetyLevel.caution => '주의 구간 가능성',
    RouteSafetyLevel.unknown => '안전 정보 부족',
    RouteSafetyLevel.avoid => '피해야 할 도로 감지',
  };

  Color get color => switch (level) {
    RouteSafetyLevel.preferred => const Color(0xFF1F7A4D),
    RouteSafetyLevel.moderate => const Color(0xFF5C8A3A),
    RouteSafetyLevel.caution => const Color(0xFFD28727),
    RouteSafetyLevel.unknown => const Color(0xFF687078),
    RouteSafetyLevel.avoid => const Color(0xFFC44536),
  };
}

const _cautionWords = <String>['대로', '교차로', '로터리', '터널', 'bridge', 'trunk'];
const _forbiddenWords = <String>['고속도로', '자동차전용', 'motorway', 'expressway'];

/// Rates only the evidence contained in the route provider's directions.
/// Unknown data must remain unknown; this is not a guarantee of real-world
/// sidewalk, lighting, construction or traffic conditions.
RouteSafetyReport assessWalkingRoute(WalkingRoute route) {
  final directions = route.instructions
      .map((value) => value.toLowerCase())
      .where((value) => value.trim().isNotEmpty)
      .toList();
  if (directions.isEmpty) {
    return const RouteSafetyReport(
      score: 50,
      knownFraction: 0,
      level: RouteSafetyLevel.unknown,
      reasons: ['경로 공급자에 인도·횡단보도 정보가 없어요.'],
    );
  }

  var caution = 0, forbidden = 0;
  for (final direction in directions) {
    if (_forbiddenWords.any(direction.contains)) forbidden++;
    if (_cautionWords.any(direction.contains)) caution++;
  }
  // Road names and instruction keywords are warnings, never verified
  // sidewalk coverage. Structured provider evidence is not connected yet.
  var score = 50 - caution * 12;
  if (forbidden > 0) score -= 70;
  score = score.clamp(0, 100).toInt();

  final reasons = <String>[];
  if (forbidden > 0) reasons.add('보행자가 피해야 할 도로 표현이 감지됐어요.');
  if (caution > 0) reasons.add('큰길·교차로 등 주의 표현이 $caution개 있어요.');
  reasons.add('도로 이름만으로 실제 인도·횡단보도 유무를 확인할 수 없어요.');

  final level = forbidden > 0
      ? RouteSafetyLevel.avoid
      : caution > 0
      ? RouteSafetyLevel.caution
      : RouteSafetyLevel.unknown;
  return RouteSafetyReport(
    score: score,
    knownFraction: 0,
    level: level,
    reasons: reasons,
  );
}
