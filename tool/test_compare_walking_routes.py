import unittest
from compare_walking_routes import request_specs, summarize


class WalkingComparisonTest(unittest.TestCase):
    def test_requests_use_pedestrian_services_and_longitude_first(self):
        specs = request_specs((37.5, 127.0), (37.501, 127.001), 'private-test-key')
        osm, tmap = specs
        self.assertIn('/routed-foot/route/v1/foot/127.0,37.5;127.001,37.501', osm.full_url)
        self.assertIn('/routes/pedestrian', tmap.full_url)
        import json
        body = json.loads(tmap.data)
        self.assertEqual(body['startX'], 127.0)
        self.assertEqual(body['startY'], 37.5)
        self.assertEqual(body['reqCoordType'], 'WGS84GEO')
        self.assertNotIn('private-test-key', tmap.full_url)

    def test_summaries_measure_endpoint_gaps_without_claiming_accessibility(self):
        raw = {'code': 'Ok', 'routes': [{'distance': 210, 'duration': 180,
            'geometry': {'coordinates': [[127, 37.5], [127.001, 37.501]]}}]}
        result = summarize('osrm', raw, (37.5, 127), (37.501, 127.001))
        self.assertEqual(result['meters'], 210)
        self.assertLess(result['endGapMeters'], 1)
        self.assertEqual(result['accessibility'], 'not_verified')
        self.assertNotIn('coordinates', result)
        self.assertNotIn('best', result)

    def test_tmap_lines_are_combined_but_not_retained_in_report(self):
        raw = {'features': [
            {'geometry': {'type': 'Point', 'coordinates': [127, 37.5]},
             'properties': {'totalDistance': 200, 'totalTime': 160}},
            {'geometry': {'type': 'LineString', 'coordinates': [[127, 37.5], [127.001, 37.501]]}, 'properties': {}}]}
        result = summarize('tmap', raw, (37.5, 127), (37.501, 127.001))
        self.assertEqual(result['seconds'], 160)
        self.assertLess(result['startGapMeters'], 1)

    def test_invalid_coordinates_and_vehicle_only_servers_are_rejected(self):
        with self.assertRaises(ValueError):
            request_specs((127, 37.5), (37.5, 127), '')
        with self.assertRaises(ValueError):
            request_specs((37.5, 127), (37.51, 127), '', 'https://router.project-osrm.org')
        with self.assertRaises(ValueError):
            summarize('osrm', {'code': 'Ok', 'routes': [{'distance': 100, 'duration': 100,
                'geometry': {'coordinates': [[127, 37.5], [float('nan'), 37.51]]}}]}, (37.5, 127), (37.51, 127))


if __name__ == '__main__':
    unittest.main()
