import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/pet_admission.dart';
import 'package:mungcation/models/walk_data.dart';

void main() {
  test(
    'alternative transport conditions remain alternatives through storage',
    () {
      final policy = PetAdmission.fromJson({
        'status': 'conditional',
        'conditions': '유모차 또는 캐리어 중 하나를 지참',
        'transportRule': '유모차 또는 캐리어 중 하나를 지참',
        'sourceName': '공식 안내',
        'sourceUrl': 'https://example.org/policy',
        'referenceDate': '2025-03-24',
      });
      final place = PlaceInfo(
        id: 'test',
        name: '동반 카페',
        address: '서울',
        category: 'cafe',
        location: GeoSample(37.5, 127, 0, DateTime.now()),
        fetchedAt: DateTime.now(),
        admission: policy,
        roadName: '왕십리로',
        buildingNumber: '10',
      );
      final restored = PlaceInfo.fromJson(place.toJson());
      expect(restored.admission!.transportRule, '유모차 또는 캐리어 중 하나를 지참');
      expect(restored.admission!.status, PetAdmissionStatus.conditional);
      expect(restored.admission!.referenceDate, DateTime(2025, 3, 24));
      expect(restored.roadName, '왕십리로');
      expect(restored.buildingNumber, '10');
    },
  );
  test('missing conditions stay unknown rather than becoming unnecessary', () {
    final policy = PetAdmission.fromJson({
      'status': 'allowed',
      'sourceName': '공개 자료',
      'sourceUrl': 'https://example.org/policy',
    });
    expect(policy.transportRule, isEmpty);
    expect(policy.rentalRule, isEmpty);
    expect(policy.isAllowed, true);
    final old = PlaceInfo.fromJson({
      'id': 'old',
      'name': '카페',
      'lat': 37.5,
      'lon': 127,
    });
    expect(old.admission, isNull);
  });
  test(
    'denial, unsupported status and missing evidence never count as allowed',
    () {
      expect(
        PetAdmission.fromJson({
          'status': 'notAllowed',
          'sourceName': '공개 자료',
          'sourceUrl': 'https://example.org/policy',
        }).isAllowed,
        false,
      );
      expect(
        const PetAdmission(status: PetAdmissionStatus.allowed).isAllowed,
        false,
      );
      expect(
        () => PetAdmission.fromJson({'status': 'definitelyAllowed'}),
        throwsFormatException,
      );
    },
  );
}
