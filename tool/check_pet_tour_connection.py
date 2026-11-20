"""Test the approved TourAPI key without logging credentials or changing map assets."""
import argparse
import json
import math
import os
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = 'https://apis.data.go.kr/B551011/KorPetTourService2/locationBasedList2'


def load_key(environment, path):
    key = environment.get('TOUR_API_KEY', '').strip()
    if not key:
        try:
            key = json.loads(Path(path).read_text(encoding='utf-8-sig')).get('TOUR_API_KEY', '').strip()
        except (OSError, ValueError, AttributeError):
            raise ValueError('Add TOUR_API_KEY to ignored config/app_keys.json or the environment.') from None
    if not key or any(char.isspace() for char in key):
        raise ValueError('A non-empty TourAPI key is required.')
    return urllib.parse.unquote(key)


def request_url(key, *, latitude, longitude, radius):
    if not (math.isfinite(latitude) and math.isfinite(longitude) and
            32.5 <= latitude <= 38.7 and 124 <= longitude <= 132 and 1 <= radius <= 20000):
        raise ValueError('Use Korean latitude/longitude coordinates and a radius of 1..20000 metres.')
    return ENDPOINT + '?' + urllib.parse.urlencode(dict(
        serviceKey=key, MobileOS='ETC', MobileApp='Mungcation', _type='json',
        numOfRows=20, pageNo=1, mapX=longitude, mapY=latitude, radius=radius, arrange='E'))


def response_items(payload):
    if not isinstance(payload, dict):
        raise ValueError('Unexpected TourAPI response format.')
    response = payload.get('response', {})
    if not isinstance(response, dict):
        raise ValueError('Unexpected TourAPI response format.')
    header = response.get('header', {})
    if not isinstance(header, dict) or str(header.get('resultCode', '')) not in {'00', '0000'}:
        raise ValueError('TourAPI rejected the request. Check approval, service access, key and quota.')
    body = response.get('body', {})
    if not isinstance(body, dict):
        raise ValueError('Unexpected TourAPI response format.')
    items = body.get('items') or {}
    if not isinstance(items, dict):
        raise ValueError('Unexpected TourAPI response format.')
    items = items.get('item', [])
    if isinstance(items, dict):
        items = [items]
    if not isinstance(items, list):
        raise ValueError('Unexpected TourAPI response format.')
    return items


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--keys-file', type=Path, default=ROOT / 'config/app_keys.json')
    parser.add_argument('--lat', type=float, default=37.445)
    parser.add_argument('--lon', type=float, default=129.165)
    parser.add_argument('--radius', type=int, default=8000)
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/verification/pet_tour_probe.json')
    args = parser.parse_args()
    try:
        url = request_url(load_key(os.environ, args.keys_file), latitude=args.lat, longitude=args.lon, radius=args.radius)
        request = urllib.request.Request(url, headers={'User-Agent': 'Mungcation-TourAPI-Check/1.0'})
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read())
        items = response_items(payload)
    except (OSError, ValueError, urllib.error.URLError):
        # Network exceptions may include the full URL and key. Never print them.
        parser.exit(1, 'TourAPI check failed. Verify TOUR_API_KEY, approval, parameters and network. No credentials were logged.\n')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'TourAPI connection succeeded. Returned {len(items)} nearby records; public response saved to {args.output.name}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
