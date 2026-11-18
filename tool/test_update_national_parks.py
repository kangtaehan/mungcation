import unittest
from update_national_parks import normalize_records


class NationalParkImportTest(unittest.TestCase):
    def record(self, name='독서당공원', **overrides):
        return dict(PARK_NM=name, MANAGE_NO='11170-00038', INSTT_CODE='3020000',
                    LATITUDE='37.5345083', LONGITUDE='127.012481',
                    RDNMADR='', LNMADR='서울특별시 용산구 한남동 1-32',
                    PARK_SE='소공원', REFERENCE_DATE='2026-09-22',
                    PHONE_NUMBER='02-2199-7605', INSTITUTION_NM='서울특별시 용산구청',
                    **overrides)

    def test_keeps_real_name_and_reference_date(self):
        parks, report = normalize_records([self.record()])
        self.assertEqual(parks[0][1], '독서당공원')
        self.assertEqual(parks[0][7], '2026-09-22')
        self.assertEqual(report['accepted'], 1)

    def test_same_management_number_does_not_merge_distinct_parks(self):
        parks, _ = normalize_records([self.record(), self.record('다른공원', **{}) | {'LATITUDE': '37.54'}])
        self.assertEqual(len(parks), 2)
        self.assertNotEqual(parks[0][0], parks[1][0])

    def test_rejects_administrative_names_and_bad_coordinates(self):
        parks, report = normalize_records([
            self.record('한남동'), self.record(' '),
            self.record() | {'LONGITUDE': '1296'},
            self.record() | {'REFERENCE_DATE': 'not-a-date'},
        ])
        self.assertEqual(parks, [])
        self.assertEqual(report['rejected'], 4)

    def test_duplicate_uses_latest_reference_date(self):
        parks, report = normalize_records([
            self.record() | {'REFERENCE_DATE': '2020-01-01'}, self.record(),
        ])
        self.assertEqual(len(parks), 1)
        self.assertEqual(parks[0][7], '2026-09-22')
        self.assertEqual(report['duplicates'], 1)

    def test_generic_category_is_not_a_real_park_name(self):
        parks, report = normalize_records([self.record('공원'), self.record('미정')])
        self.assertEqual(parks, [])
        self.assertEqual(report['rejected'], 2)


if __name__ == '__main__':
    unittest.main()
