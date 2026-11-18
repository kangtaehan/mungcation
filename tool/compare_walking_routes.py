"""Explicit developer comparison; never changes the app's selected route.

TMAP docs: https://tmap-skopenapi.readme.io/reference/보행자경로안내
Keys are read from the environment, never written to requests' URLs or reports.
No provider geometry is persisted. Review provider retention terms before use.
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_OSRM = 'https://routing.openstreetmap.de/routed-foot'


def check_point(point):
    lat, lon = point
    if not (math.isfinite(lat) and math.isfinite(lon) and 32.5 <= lat <= 38.7 and 124 <= lon <= 132):
        raise ValueError('Expected a valid Korean latitude/longitude pair')


def request_specs(start, end, tmap_key, osrm_url=DEFAULT_OSRM):
    check_point(start)
    check_point(end)
    base = urllib.parse.urlsplit(osrm_url)
    if (base.scheme != 'https' or not base.hostname or base.username or base.password
            or base.query or base.fragment or base.hostname == 'router.project-osrm.org'
            or any(token in base.path for token in ['routed-car', 'routed-bike', '/driving'])):
        raise ValueError('Expected an HTTPS pedestrian-only OSRM service')
    coords = f'{start[1]},{start[0]};{end[1]},{end[0]}'
    query = urllib.parse.urlencode({'overview': 'full', 'geometries': 'geojson', 'steps': 'false'})
    headers = {'Accept': 'application/json', 'User-Agent': 'MungcationRouteComparison/1.0'}
    result = [urllib.request.Request(f'{osrm_url.rstrip("/")}/route/v1/foot/{coords}?{query}', headers=headers)]
    if tmap_key:
        body = {'startX': start[1], 'startY': start[0], 'endX': end[1], 'endY': end[0],
                'startName': '출발지', 'endName': '목적지', 'reqCoordType': 'WGS84GEO', 'resCoordType': 'WGS84GEO'}
        result.append(urllib.request.Request('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1',
            data=json.dumps(body).encode('utf-8'),
            headers={**headers, 'Content-Type': 'application/json', 'appKey': tmap_key}, method='POST'))
    return result


def distance(a, b):
    lat1, lat2 = math.radians(a[0]), math.radians(b[0])
    dlat, dlon = lat2 - lat1, math.radians(b[1] - a[1])
    value = math.sin(dlat / 2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2)**2
    return 6371000 * 2 * math.asin(math.sqrt(min(1, value)))


def summarize(provider, raw, start, end):
    if provider == 'osrm':
        if raw.get('code') != 'Ok' or not raw.get('routes'):
            raise ValueError('No pedestrian route returned')
        route = raw['routes'][0]
        meters, seconds = route['distance'], route['duration']
        coords = route['geometry']['coordinates']
    elif provider == 'tmap':
        features = raw.get('features') or []
        totals = next((f['properties'] for f in features if 'totalDistance' in f.get('properties', {})), None)
        if totals is None:
            raise ValueError('No pedestrian route returned')
        meters, seconds = totals['totalDistance'], totals['totalTime']
        coords = [c for f in features if f.get('geometry', {}).get('type') == 'LineString'
                  for c in f['geometry']['coordinates']]
    else:
        raise ValueError('Unsupported pedestrian provider')
    if not all(isinstance(n, (int, float)) and math.isfinite(n) and n >= 0 for n in [meters, seconds]) or len(coords) < 2:
        raise ValueError('Invalid route measures or geometry')
    points = [(c[1], c[0]) for c in coords]
    for point in points:
        check_point(point)
    start_gap, end_gap = distance(start, points[0]), distance(end, points[-1])
    return {'status': 'ok', 'provider': provider, 'meters': meters, 'seconds': seconds,
            'startGapMeters': round(start_gap, 1), 'endGapMeters': round(end_gap, 1),
            'accessibility': 'not_verified',
            'warnings': ['endpoint_gap_over_100m'] if max(start_gap, end_gap) > 100 else []}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--start', nargs=2, type=float, required=True, metavar=('LAT', 'LON'))
    parser.add_argument('--end', nargs=2, type=float, required=True, metavar=('LAT', 'LON'))
    parser.add_argument('--osrm-url', default=DEFAULT_OSRM, help='Verified pedestrian-only endpoint')
    args = parser.parse_args()
    try:
        requests = request_specs(args.start, args.end, os.environ.get('TMAP_APP_KEY', '').strip(), args.osrm_url)
    except ValueError as error:
        parser.error(str(error))
    results = []
    for provider, request in zip(['osrm', 'tmap'], requests):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read(8 * 1024 * 1024 + 1)
                if len(body) > 8 * 1024 * 1024:
                    raise ValueError('Oversized route response')
                results.append(summarize(provider, json.loads(body), args.start, args.end))
        except urllib.error.HTTPError as error:
            results.append({'provider': provider, 'status': 'http_error', 'code': error.code})
        except (ValueError, KeyError, TypeError, IndexError, AttributeError, OSError):
            results.append({'provider': provider, 'status': 'unavailable_or_invalid'})
    if len(requests) == 1:
        results.append({'provider': 'tmap', 'status': 'skipped_key_not_configured'})
    print(json.dumps({'comparedAt': datetime.now(timezone.utc).isoformat(), 'results': results,
                      'note': 'Metrics do not establish walkability, pet access or stroller accessibility.'}))
    return 0 if all(result['status'] == 'ok' for result in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
