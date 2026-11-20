import unittest
import json
import tempfile
from pathlib import Path
from update_pet_tour import normalize_tour, normalized_detail, detail_record, read_pages


def listing(**changes):
    return dict(contentid='123', title='테스트 카페 성수점', contenttypeid='39',
                addr1='서울특별시 성동구 왕십리로 10', addr2='1층',
                mapx='127', mapy='37.5', showflag='1', modifiedtime='20261119162958',
                lclsSystm2='FD05', **changes)


class PetTourImportTest(unittest.TestCase):
    def test_complete_pagination_is_required_before_a_snapshot_can_be_built(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            for page, ids in [(1, ['1', '2']), (2, ['3'])]:
                payload = {'response': {'header': {'resultCode': '0000'}, 'body': {
                    'totalCount': 3, 'items': {'item': [{'contentid': key} for key in ids]}}}}
                (folder / f'page-{page}.json').write_text(json.dumps(payload))
            self.assertEqual(len(read_pages('unused', folder, download=False)), 3)
            duplicate = {'response': {'header': {'resultCode': '0000'}, 'body': {
                'totalCount': 3, 'items': {'item': [{'contentid': '2'}]}}}}
            (folder / 'page-2.json').write_text(json.dumps(duplicate))
            with self.assertRaises(ValueError):
                read_pages('unused', folder, download=False)

    def test_changed_listing_does_not_relabel_old_detail_as_newly_checked(self):
        details = {'123': {'detail': {'contentid': '123', 'acmpyTypeCd': '일부구역 동반가능',
                    'acmpyNeedMtr': '유모차 또는 캐리어'}, 'modifiedTime': '20250101000000',
                    'checkedAt': '2025-01-02T00:00:00Z'}}
        places, _ = normalize_tour([listing()], details, '2026-11-20T08:00:00Z')
        self.assertEqual(places[0]['admission']['checkedAt'], '2025-01-02T00:00:00Z')
        self.assertIn('이전에 확인한 규정', places[0]['admission']['conditions'])
        self.assertEqual(places[0]['admission']['transportRule'], '유모차 또는 캐리어')
    def test_successful_empty_detail_remains_a_listing_without_invented_rules(self):
        cached = detail_record([], '123', '20261119', '2026-11-20T08:00:00Z')
        places, report = normalize_tour([listing()], {'123': cached}, '2026-11-20T08:00:00Z')
        self.assertFalse(places[0]['detailVerified'])
        self.assertEqual(places[0]['admission']['transportRule'], '')
        self.assertEqual(report['detailVerified'], 0)
        self.assertEqual(report['detailUnavailable'], 1)
        with self.assertRaises(ValueError):
            detail_record([{'contentid':'other'}], '123', '', '2026-11-20T08:00:00Z')
    def test_published_pet_service_listing_has_real_coordinates_and_unconfirmed_rules(self):
        places, report = normalize_tour([listing()], {}, '2026-11-20T08:00:00+00:00')
        self.assertEqual(places[0]['id'], 'tour-pet-123')
        self.assertEqual(places[0]['category'], 'cafe')
        self.assertEqual(places[0]['lat'], 37.5)
        self.assertEqual(places[0]['admission']['status'], 'conditional')
        self.assertIn('목록 등재', places[0]['admission']['conditions'])
        self.assertEqual(places[0]['admission']['transportRule'], '')
        self.assertNotIn('referenceDate', places[0]['admission'])
        self.assertEqual(report['accepted'], 1)

    def test_original_or_conditions_and_explicit_denial_are_preserved(self):
        detail = dict(contentid='123', acmpyTypeCd='일부구역 동반가능',
                      acmpyNeedMtr='유모차 또는 이동장 이용', acmpyPsblCpam='5kg 미만',
                      relaRntlPrdlst='대여 없음', etcAcmpyInfo='식당 구역 동반 불가')
        policy = normalized_detail(detail, '2026-11-20T08:00:00+00:00')
        self.assertEqual(policy['transportRule'], '유모차 또는 이동장 이용')
        self.assertEqual(policy['status'], 'conditional')
        self.assertEqual(policy['areaRule'], '일부구역 동반가능')
        self.assertIn('식당 구역 동반 불가', policy['conditions'])
        self.assertEqual(policy['rentalRule'], '대여 없음')
        self.assertEqual(normalized_detail({'acmpyTypeCd': '동반불가'}, '2026-11-20T08:00:00Z')['status'], 'notAllowed')

    def test_hidden_missing_coordinates_and_wrong_detail_identity_are_not_inferred(self):
        hidden = listing(); hidden['showflag'] = '0'
        invalid = listing(); invalid['mapx'] = ''
        places, report = normalize_tour([hidden, invalid], {}, '2026-11-20T08:00:00Z')
        self.assertEqual(places, [])
        self.assertEqual(report['hidden'], 1)
        self.assertEqual(report['invalid'], 1)
        with self.assertRaises(ValueError):
            normalize_tour([listing()], {'123': {'detail': {'contentid': 'other'}}}, '2026-11-20T08:00:00Z')


if __name__ == '__main__':
    unittest.main()
