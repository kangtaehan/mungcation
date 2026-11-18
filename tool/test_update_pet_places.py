import unittest
from update_pet_places import normalize_culture, normalize_food


class PetPlaceImportTest(unittest.TestCase):
    def row(self, **changes):
        return {
            '시설명': '테스트 카페', '카테고리3': '카페', '위도': '37.5', '경도': '127',
            '도로명주소': '서울특별시 성동구 왕십리로 10', '전화번호': '02-000-0000',
            '반려동물 동반 가능정보': 'Y', '반려동물 제한사항': '유모차 또는 케이지 이용',
            '입장 가능 동물 크기': '소형견', '최종작성일': '2025-03-24', **changes,
        }

    def test_preserves_alternatives_and_dates_without_making_both_mandatory(self):
        rows, report = normalize_culture([self.row()])
        self.assertEqual(rows[0]['admission']['conditions'], '유모차 또는 케이지 이용')
        self.assertEqual(rows[0]['admission']['status'], 'conditional')
        self.assertEqual(rows[0]['admission']['referenceDate'], '2025-03-24')
        self.assertEqual(report['accepted'], 1)

    def test_explicit_denial_is_not_changed_to_allowed(self):
        rows, _ = normalize_culture([self.row(**{'반려동물 동반 가능정보': 'N'})])
        self.assertEqual(rows[0]['admission']['status'], 'notAllowed')

    def test_invalid_coordinates_and_unrequested_businesses_are_excluded(self):
        rows, _ = normalize_culture([
            self.row(**{'위도': ''}), self.row(**{'경도': '1270'}),
            self.row(**{'카테고리3': '동물약국'}),
        ])
        self.assertEqual(rows, [])

    def test_same_brand_different_addresses_have_different_identities(self):
        rows, _ = normalize_culture([self.row(), self.row(**{'위도': '37.6'})])
        self.assertEqual(len(rows), 2)
        self.assertNotEqual(rows[0]['id'], rows[1]['id'])

    def test_food_registry_keeps_the_exact_branch_address_without_inventing_coordinates(self):
        rows, _ = normalize_food([
            {'bsshNm': '등록 식당', 'siteAddr': '서울특별시 성동구 왕십리로 10(1층)', 'lgaldngNm': '서울'},
            {'bsshNm': '등록 식당', 'siteAddr': '서울특별시 성동구 왕십리로 20', 'lgaldngNm': '서울'},
        ])
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]['road'], '왕십리로')
        self.assertNotIn('lat', rows[0])
        self.assertNotEqual(rows[0]['number'], rows[1]['number'])


if __name__ == '__main__':
    unittest.main()
