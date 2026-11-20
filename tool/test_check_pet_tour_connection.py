import json
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from check_pet_tour_connection import load_key, request_url, response_items


class PetTourConnectionTest(unittest.TestCase):
    def test_reads_ignored_local_key_and_encodes_exactly_once(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'keys.json'
            path.write_text(json.dumps({'TOUR_API_KEY': 'abc%2Bdef%2Fghi%3D', 'VWORLD_API_KEY': 'other'}))
            key = load_key({}, path)
        url = request_url(key, latitude=37.445, longitude=129.165, radius=8000)
        query = parse_qs(urlsplit(url).query)
        self.assertEqual(query['serviceKey'], ['abc+def/ghi='])
        self.assertEqual(query['mapX'], ['129.165'])
        self.assertEqual(query['mapY'], ['37.445'])
        self.assertEqual(query['_type'], ['json'])
        self.assertIn('/KorPetTourService2/locationBasedList2', url)

    def test_missing_keys_wrong_coordinates_and_oversize_radius_fail_before_network(self):
        with self.assertRaises(ValueError):
            load_key({}, Path('missing-keys.json'))
        for lat, lon, radius in [(129, 37, 8000), (37.445, 129.165, 20001)]:
            with self.assertRaises(ValueError):
                request_url('example', latitude=lat, longitude=lon, radius=radius)

    def test_api_errors_are_not_reported_as_empty_success(self):
        self.assertEqual(response_items({'response': {'header': {'resultCode': '0000'}, 'body': {'items': ''}}}), [])
        with self.assertRaises(ValueError):
            response_items({'response': {'header': {'resultCode': '30'}}})


if __name__ == '__main__':
    unittest.main()
