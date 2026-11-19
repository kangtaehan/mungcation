import 'walk_data.dart';

enum PetAccess { unknown, allowed, outdoorOnly, notAllowed }

extension PetAccessLabel on PetAccess {
  String get label => switch (this) {
    PetAccess.unknown => '미확인',
    PetAccess.allowed => '동반 가능으로 메모',
    PetAccess.outdoorOnly => '실외만 가능으로 메모',
    PetAccess.notAllowed => '동반 불가로 메모',
  };
}

class SavedPlace {
  static const preparationItems = {
    'leash': '목줄·하네스',
    'bags': '배변봉투',
    'water': '물·물그릇',
    'admission': '이동수단·입장 조건 확인',
  };
  final PlaceInfo place;
  final String note;
  final PetAccess access;
  final DateTime? notedAt;
  final Set<String> preparation;
  final DateTime? preparedAt;
  const SavedPlace({
    required this.place,
    this.note = '',
    this.access = PetAccess.unknown,
    this.notedAt,
    this.preparation = const {},
    this.preparedAt,
  });
  bool preparedOn(DateTime day) {
    final date = preparedAt?.toLocal();
    final local = day.toLocal();
    return date != null &&
        date.year == local.year &&
        date.month == local.month &&
        date.day == local.day;
  }

  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'note': note,
    'access': access.name,
    'notedAt': notedAt?.toIso8601String(),
    'preparation': preparation.toList(),
    'preparedAt': preparedAt?.toIso8601String(),
  };
  factory SavedPlace.fromJson(Map<String, dynamic> j) {
    final place = PlaceInfo.fromJson(
      Map<String, dynamic>.from(j['place'] as Map),
    );
    final access = PetAccess.values
        .where((v) => v.name == j['access'])
        .firstOrNull;
    final note = j['note'] as String? ?? '';
    final rawPreparation = j['preparation'];
    if (rawPreparation != null &&
        (rawPreparation is! List ||
            rawPreparation.any(
              (value) =>
                  value is! String || !preparationItems.containsKey(value),
            )))
      throw const FormatException('올바르지 않은 외출 준비 항목');
    if (place.id.isEmpty ||
        place.name.isEmpty ||
        !place.location.valid ||
        note.length > 2000 ||
        access == null)
      throw const FormatException('올바르지 않은 즐겨찾기 정보');
    return SavedPlace(
      place: place,
      note: note,
      access: access,
      notedAt: j['notedAt'] == null
          ? null
          : DateTime.parse(j['notedAt'] as String),
      preparation: Set.unmodifiable(
        List<String>.from(rawPreparation as List? ?? []),
      ),
      preparedAt: j['preparedAt'] == null
          ? null
          : DateTime.parse(j['preparedAt'] as String),
    );
  }
}
