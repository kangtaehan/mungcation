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
  final PlaceInfo place;
  final String note;
  final PetAccess access;
  final DateTime? notedAt;
  const SavedPlace({
    required this.place,
    this.note = '',
    this.access = PetAccess.unknown,
    this.notedAt,
  });
  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'note': note,
    'access': access.name,
    'notedAt': notedAt?.toIso8601String(),
  };
  factory SavedPlace.fromJson(Map<String, dynamic> j) {
    final place = PlaceInfo.fromJson(
      Map<String, dynamic>.from(j['place'] as Map),
    );
    final access = PetAccess.values
        .where((v) => v.name == j['access'])
        .firstOrNull;
    final note = j['note'] as String? ?? '';
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
    );
  }
}
