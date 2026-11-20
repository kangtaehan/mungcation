"""Import official KorPetTourService2 data; keys stay outside the app bundle.

Source contract: https://www.data.go.kr/data/15135102/openapi.do
"""
import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
import math
import os
from pathlib import Path
import re
import urllib.parse
import urllib.request

from check_pet_tour_connection import load_key, response_items
from update_pet_places import ROOT, ROAD

BASE = 'https://apis.data.go.kr/B551011/KorPetTourService2/'
SOURCE = 'https://www.data.go.kr/data/15135102/openapi.do'
KINDS = {'12': 'civic', '14': 'civic', '28': 'civic', '32': 'stay', '38': 'shopping', '39': 'restaurant'}


def clean(value):
    value = re.sub(r'<br\s*/?>', '\n', str(value or ''), flags=re.I)
    return html.unescape(re.sub(r'<[^>]+>', '', value)).strip()


def normalized_detail(detail, checked_at):
    scope = clean(detail.get('acmpyTypeCd'))
    compact = re.sub(r'\s+', '', scope)
    status = ('notAllowed' if compact in {'동반불가', '전구역동반불가', '출입불가', '동반불가능'} else
              'conditional' if '동반가능' in compact else 'unknown')
    labels = {'acmpyNeedMtr': '동반 시 준비·유의사항', 'acmpyPsblCpam': '동반 가능한 동물',
              'relaAcdntRiskMtr': '안전 유의사항', 'etcAcmpyInfo': '기타 동반 안내',
              'relaPosesFclty': '관련 시설', 'relaFrnshPrdlst': '제공 물품', 'relaPurcPrdlst': '구매 가능 물품'}
    conditions = '\n'.join(f'{label}: {clean(detail.get(key))}' for key, label in labels.items() if clean(detail.get(key)))
    transport = '\n'.join(clean(detail.get(key)) for key in ['acmpyNeedMtr', 'etcAcmpyInfo']
                          if re.search(r'유모차|이동장|캐리어|케이지|켄넬', clean(detail.get(key))))
    return dict(status=status, conditions=conditions, transportRule=transport, areaRule=scope,
                sizeRule=clean(detail.get('acmpyPsblCpam')), rentalRule=clean(detail.get('relaRntlPrdlst')),
                sourceName='한국관광공사 · 반려동물 동반여행', sourceUrl=SOURCE, checkedAt=checked_at)


def detail_record(items, content_id, modified_time, checked_at):
    if len(items) > 1 or (items and str(items[0].get('contentid')) != content_id):
        raise ValueError('Tour detail and place IDs do not match.')
    # A successful 0-row response means no detailed rules were supplied. The
    # published pet-travel listing remains; equipment requirements stay unknown.
    return dict(detail=items[0] if items else None, checkedAt=checked_at, modifiedTime=modified_time)


def normalize_tour(records, details, retrieved_at):
    found = {}
    report = dict(sourceRows=len(records), hidden=0, invalid=0, unsupported=0, detailVerified=0, detailUnavailable=0)
    for row in records:
        if str(row.get('showflag', '')) != '1':
            report['hidden'] += 1
            continue
        content_id, name = str(row.get('contentid', '')), clean(row.get('title'))
        kind = str(row.get('contenttypeid', ''))
        if kind not in KINDS:
            report['unsupported'] += 1
            continue
        try:
            lat, lon = float(row.get('mapy', '')), float(row.get('mapx', ''))
            if not (content_id.isdigit() and name and math.isfinite(lat) and math.isfinite(lon)
                    and 32.5 <= lat <= 38.7 and 124 <= lon <= 132):
                raise ValueError('Invalid place')
        except (TypeError, ValueError):
            report['invalid'] += 1
            continue
        category = 'cafe' if kind == '39' and (row.get('lclsSystm2') == 'FD05' or row.get('cat3') == 'A05020900') else KINDS[kind]
        cached = details.get(content_id)
        if cached is not None and cached.get('detail') is not None:
            detail = cached['detail']
            if str(detail.get('contentid')) != content_id:
                raise ValueError('Tour detail and place IDs do not match.')
            policy = normalized_detail(detail, cached.get('checkedAt', retrieved_at))
            if cached.get('modifiedTime') and cached['modifiedTime'] != row.get('modifiedtime'):
                policy['conditions'] = '관광정보 수정 후 동반 규정은 아직 다시 확인하지 못했습니다. 아래는 이전에 확인한 규정입니다.\n' + policy['conditions']
            report['detailVerified'] += 1
        else:
            if cached is not None:
                report['detailUnavailable'] += 1
            policy = dict(status='conditional', conditions='한국관광공사 반려동물 동반여행 전용 목록 등재 장소입니다. 세부 동반 구역·크기·유모차·캐리어 조건은 아직 확인하지 못했으므로 방문 전 시설에 확인해 주세요.',
                          transportRule='', sourceName='한국관광공사 · 반려동물 동반여행 목록', sourceUrl=SOURCE, checkedAt=retrieved_at)
        address = ' '.join(filter(None, [clean(row.get('addr1')), clean(row.get('addr2'))]))
        road = ROAD.search(address)
        found[content_id] = dict(id='tour-pet-' + content_id, contentId=content_id, name=name,
            category=category, kind='여행지' if kind in {'12', '28'} else '', address=address,
            lat=lat, lon=lon, phone=clean(row.get('tel')), roadName=road[1] if road else '',
            buildingNumber=road[2] if road else '', modifiedTime=row.get('modifiedtime', ''),
            detailVerified=cached is not None and cached.get('detail') is not None, admission=policy)
    places = sorted(found.values(), key=lambda row: row['id'])
    report.update(accepted=len(places), allowed=sum(row['admission']['status'] in {'allowed', 'conditional'} for row in places))
    return places, report


def api_request(key, operation, **parameters):
    query = urllib.parse.urlencode(dict(serviceKey=key, MobileOS='ETC', MobileApp='Mungcation', _type='json', **parameters))
    try:
        request = urllib.request.Request(BASE + operation + '?' + query, headers={'User-Agent': 'Mungcation-Tour-Snapshot/1.0'})
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
        response_items(payload)
        return payload
    except Exception:
        raise RuntimeError('TourAPI request failed; credentials were not logged.') from None


def read_pages(key, folder, *, download):
    folder.mkdir(parents=True, exist_ok=True)
    records = []
    total, page, seen_pages = None, 1, set()
    while total is None or len(records) < total:
        path = folder / f'page-{page}.json'
        payload = api_request(key, 'petTourSyncList2', numOfRows=1000, pageNo=page, arrange='C') if download else json.loads(path.read_text(encoding='utf-8'))
        rows = response_items(payload)
        total = int(payload['response']['body']['totalCount'])
        signature = tuple(row.get('contentid') for row in rows)
        if not rows or signature in seen_pages or page > 100:
            raise ValueError('Incomplete TourAPI pagination; previous map asset retained.')
        seen_pages.add(signature)
        records.extend(rows)
        if download:
            path.write_text(json.dumps(payload, ensure_ascii=False), encoding='utf-8')
        print(f'Tour listing page {page} verified.', flush=True)
        page += 1
    if len(records) != total or len({row['contentid'] for row in records}) != total:
        raise ValueError('TourAPI changed during pagination; retry without replacing the previous asset.')
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--keys-file', type=Path, default=ROOT / 'config/app_keys.json')
    parser.add_argument('--cache-dir', type=Path, default=ROOT / 'artifacts/tour-source')
    parser.add_argument('--from-cache', action='store_true', help='Use a complete downloaded list instead of new listing calls')
    parser.add_argument('--detail-limit', type=int, default=60, help='Maximum new detail requests; cached details are reused')
    parser.add_argument('--priority-region', default='삼척시')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/data/pet_tour_places.json')
    args = parser.parse_args()
    if not 0 <= args.detail_limit <= 900:
        parser.error('Detail request limit must be between 0 and 900.')
    key = load_key(os.environ, args.keys_file)
    records = read_pages(key, args.cache_dir, download=not args.from_cache)
    previous = json.loads(args.output.read_text(encoding='utf-8')) if args.output.exists() else {}
    details = previous.get('detailCache', {})
    # Retired content must not survive in a public snapshot or detail cache.
    active_ids = {str(row['contentid']) for row in records if row.get('showflag') == '1'}
    details = {key: value for key, value in details.items() if key in active_ids}
    detail_folder = args.cache_dir / 'details'
    detail_folder.mkdir(exist_ok=True)
    for row in records:
        content_id = str(row.get('contentid', ''))
        if not content_id.isdigit() or content_id not in active_ids:
            continue
        path = detail_folder / f'{content_id}.json'
        if path.exists():
            cached = json.loads(path.read_text(encoding='utf-8'))
            if cached.get('modifiedTime') == row.get('modifiedtime'):
                details[content_id] = cached
    candidates = sorted((row for row in records if row.get('showflag') == '1' and row.get('contenttypeid') in KINDS),
                        key=lambda row: (args.priority_region not in row.get('addr1', ''), row['contentid'] in details))
    calls = 0
    for row in candidates:
        content_id = row['contentid']
        if content_id in details and details[content_id].get('modifiedTime') == row.get('modifiedtime'):
            continue
        if calls >= args.detail_limit:
            break
        payload = api_request(key, 'detailPetTour2', contentId=content_id)
        calls += 1
        items = response_items(payload)
        details[content_id] = detail_record(items, content_id, row.get('modifiedtime', ''), datetime.now(timezone.utc).isoformat())
        path = detail_folder / f'{content_id}.json'
        staging = path.with_suffix('.json.tmp')
        staging.write_text(json.dumps(details[content_id], ensure_ascii=False), encoding='utf-8')
        staging.replace(path)
        print(f'Tour detail response saved ({calls}/{args.detail_limit}).', flush=True)
    retrieved_at = datetime.now(timezone.utc).isoformat()
    places, report = normalize_tour(records, details, retrieved_at)
    if len(places) < 500:
        raise ValueError('Incomplete national TourAPI snapshot; previous asset retained.')
    policies = {}
    for row in places:
        policy = row.pop('admission')
        policy_id = hashlib.sha256(json.dumps(policy, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:20]
        policies[policy_id] = policy
        row['admissionKey'] = policy_id
    snapshot = dict(schema=1, retrievedAt=retrieved_at, sourceUrl=SOURCE, report=report,
                    policies=policies, places=places, detailCache=details)
    temporary = args.output.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(snapshot, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    temporary.replace(args.output)
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError):
        raise SystemExit('TourAPI refresh failed; previous map asset retained. Check approval, quota, parameters and network.') from None
