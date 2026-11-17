import 'dart:math' as math;

class GeoSample {
  final double latitude, longitude, accuracy;
  final DateTime time;
  final bool breakBefore, mocked;
  const GeoSample(
    this.latitude,
    this.longitude,
    this.accuracy,
    this.time, {
    this.breakBefore = false,
    this.mocked = false,
  });
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      accuracy.isFinite &&
      accuracy >= 0;
  GeoSample withBreak() => GeoSample(
    latitude,
    longitude,
    accuracy,
    time,
    breakBefore: true,
    mocked: mocked,
  );
  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'accuracy': accuracy,
    'time': time.toIso8601String(),
    'break': breakBefore,
    'mocked': mocked,
  };
  factory GeoSample.fromJson(Map<String, dynamic> j) => GeoSample(
    (j['lat'] as num).toDouble(),
    (j['lon'] as num).toDouble(),
    (j['accuracy'] as num).toDouble(),
    DateTime.parse(j['time'] as String),
    breakBefore: j['break'] == true,
    mocked: j['mocked'] == true,
  );
}

double distanceBetween(GeoSample a, GeoSample b) {
  const r = 6371000.0;
  final lat1 = a.latitude * math.pi / 180, lat2 = b.latitude * math.pi / 180;
  final dlat = lat2 - lat1, dlon = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.pow(math.sin(dlat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
  return r *
      2 *
      math.atan2(math.sqrt(h.clamp(0, 1)), math.sqrt((1 - h).clamp(0, 1)));
}

double trackDistance(List<GeoSample> samples) {
  double meters = 0;
  for (var i = 1; i < samples.length; i++) {
    if (!samples[i].breakBefore)
      meters += distanceBetween(samples[i - 1], samples[i]);
  }
  return meters;
}

class Visit {
  final String id, name;
  final DateTime time;
  final int points;
  const Visit(this.id, this.name, this.time, this.points);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'time': time.toIso8601String(),
    'points': points,
  };
  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
    j['id'] as String,
    j['name'] as String,
    DateTime.parse(j['time'] as String),
    j['points'] as int,
  );
}

class WalkRecord {
  final String id;
  final DateTime startedAt, endedAt;
  final int seconds, points, xp;
  final List<GeoSample> samples;
  final List<Visit> visits;
  WalkRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.seconds,
    required this.points,
    required this.xp,
    required List<GeoSample> samples,
    required List<Visit> visits,
  }) : samples = List.unmodifiable(samples),
       visits = List.unmodifiable(visits);
  double get meters => trackDistance(samples);
  Map<String, dynamic> toJson() => {
    'id': id,
    'start': startedAt.toIso8601String(),
    'end': endedAt.toIso8601String(),
    'seconds': seconds,
    'points': points,
    'xp': xp,
    'samples': samples.map((e) => e.toJson()).toList(),
    'visits': visits.map((e) => e.toJson()).toList(),
  };
  factory WalkRecord.fromJson(Map<String, dynamic> j) => WalkRecord(
    id: j['id'] as String,
    startedAt: DateTime.parse(j['start'] as String),
    endedAt: DateTime.parse(j['end'] as String),
    seconds: j['seconds'] as int,
    points: j['points'] as int,
    xp: j['xp'] as int,
    samples: (j['samples'] as List)
        .map((e) => GeoSample.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    visits: (j['visits'] as List)
        .map((e) => Visit.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class WalkDraft {
  final String id;
  final DateTime startedAt;
  final int seconds;
  final List<GeoSample> samples;
  final List<Visit> visits;
  WalkDraft({
    required this.id,
    required this.startedAt,
    required this.seconds,
    required List<GeoSample> samples,
    required List<Visit> visits,
  }) : samples = List.unmodifiable(samples),
       visits = List.unmodifiable(visits);
  Map<String, dynamic> toJson() => {
    'id': id,
    'start': startedAt.toIso8601String(),
    'seconds': seconds,
    'samples': samples.map((e) => e.toJson()).toList(),
    'visits': visits.map((e) => e.toJson()).toList(),
  };
  factory WalkDraft.fromJson(Map<String, dynamic> j) => WalkDraft(
    id: j['id'] as String,
    startedAt: DateTime.parse(j['start'] as String),
    seconds: j['seconds'] as int,
    samples: (j['samples'] as List)
        .map((e) => GeoSample.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    visits: (j['visits'] as List)
        .map((e) => Visit.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class PlaceInfo {
  final String id, name, address, category, phone, url, source;
  final GeoSample location;
  final DateTime fetchedAt;
  const PlaceInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.location,
    required this.fetchedAt,
    this.phone = '',
    this.url = '',
    this.source = 'Apple 지도',
  });
  bool get rewardEligible => category == 'park';
  String get displayName => name.trim().isNotEmpty
      ? name.trim()
      : address.trim().isNotEmpty
      ? address.trim()
      : '이름 정보 없음';
  factory PlaceInfo.fromJson(Map<String, dynamic> j) => PlaceInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    address: j['address'] as String? ?? '',
    category: j['category'] as String? ?? '',
    location: GeoSample(
      (j['lat'] as num).toDouble(),
      (j['lon'] as num).toDouble(),
      0,
      DateTime.now(),
    ),
    fetchedAt: j['fetchedAt'] == null
        ? DateTime.now()
        : DateTime.parse(j['fetchedAt'] as String),
    phone: j['phone'] as String? ?? '',
    url: j['url'] as String? ?? '',
    source: j['source'] as String? ?? 'Apple 지도',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'category': category,
    'phone': phone,
    'url': url,
    'lat': location.latitude,
    'lon': location.longitude,
    'fetchedAt': fetchedAt.toIso8601String(),
    'source': source,
  };
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': displayName,
    'lat': location.latitude,
    'lon': location.longitude,
    'points': rewardEligible ? 30 : 0,
  };
}

class WalkingRoute {
  final String name, source;
  final double meters, seconds;
  final List<GeoSample> samples;
  final List<String> instructions;
  WalkingRoute(
    this.name,
    this.meters,
    this.seconds,
    this.samples,
    this.instructions, {
    this.source = 'Apple 지도',
  });
  factory WalkingRoute.fromJson(Map<String, dynamic> j) => WalkingRoute(
    j['name'] as String,
    (j['meters'] as num).toDouble(),
    (j['seconds'] as num).toDouble(),
    (j['coordinates'] as List)
        .map(
          (e) => GeoSample(
            (e['lat'] as num).toDouble(),
            (e['lon'] as num).toDouble(),
            0,
            DateTime.now(),
          ),
        )
        .toList(),
    List<String>.from(j['instructions'] as List),
  );
}
