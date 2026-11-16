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

const _walkFriendlyWords = <String>[
  '보행',
  '산책',
  '공원',
  '둘레길',
  '산책로',
  '보도',
  'pedestrian',
  'footway',
  'path',
  'trail',
  'park',
];
const _crossingWords = <String>['횡단보도', 'crossing'];
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

  var friendly = 0, crossings = 0, caution = 0, forbidden = 0;
  for (final direction in directions) {
    if (_forbiddenWords.any(direction.contains)) forbidden++;
    if (_walkFriendlyWords.any(direction.contains)) friendly++;
    if (_crossingWords.any(direction.contains)) crossings++;
    if (_cautionWords.any(direction.contains)) caution++;
  }
  final known = (friendly + crossings + caution + forbidden).clamp(
    0,
    directions.length,
  );
  final knownFraction = known / directions.length;
  var score = 50 + friendly * 15 + crossings * 3 - caution * 12;
  if (forbidden > 0) score -= 70;
  score = score.clamp(0, 100).toInt();

  final reasons = <String>[];
  if (forbidden > 0) reasons.add('보행자가 피해야 할 도로 표현이 감지됐어요.');
  if (friendly > 0) reasons.add('보행로·공원길 정보가 $friendly개 구간에서 확인됐어요.');
  if (crossings > 0) reasons.add('횡단 구간 정보가 $crossings개 있어 주변을 확인해야 해요.');
  if (caution > 0) reasons.add('큰길·교차로 등 주의 표현이 $caution개 있어요.');
  if (knownFraction < .5) reasons.add('절반 이상의 구간은 인도 정보가 확인되지 않았어요.');
  if (reasons.isEmpty) reasons.add('인도·횡단보도 정보가 확인되지 않았어요.');

  final level = forbidden > 0
      ? RouteSafetyLevel.avoid
      : caution > friendly
      ? RouteSafetyLevel.caution
      : knownFraction < .25
      ? RouteSafetyLevel.unknown
      : score >= 75 && knownFraction >= .5
      ? RouteSafetyLevel.preferred
      : RouteSafetyLevel.moderate;
  return RouteSafetyReport(
    score: score,
    knownFraction: knownFraction,
    level: level,
    reasons: reasons,
  );
}
