"""Import public pet-admission facts, retaining denial, unknowns and source dates."""
import argparse
import csv
from datetime import date, datetime, timezone
import hashlib
import http.cookiejar
import io
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CULTURE_URL = 'https://www.data.go.kr/data/15111389/fileData.do'
FOOD_URL = 'https://www.foodsafetykorea.go.kr/portal/petKorea.do'
CATEGORIES = {'카페': 'cafe', '식당': 'restaurant', '미술관': 'civic', '박물관': 'civic', '문예회관': 'civic', '여행지': 'civic', '호텔': 'stay', '펜션': 'stay'}
MISSING = {'', '정보없음', '해당없음', '알수없음', '-'}
ROAD = re.compile(r'([가-힣A-Za-z0-9·]+(?:대로|로|길))\s+(\d+(?:-\d+)?)')


def text(row, key):
    value = str(row.get(key) or '').strip()
    return '' if value.replace(' ', '') in MISSING else value


def identity(prefix, *values):
    return prefix + hashlib.sha256('|'.join(values).encode()).hexdigest()[:20]


def normalize_culture(records):
    result = {}
    rejected = 0
    for row in records:
        kind = text(row, '카테고리3')
        if kind not in CATEGORIES:
            continue
        try:
            lat, lon = float(text(row, '위도')), float(text(row, '경도'))
            reference = date.fromisoformat(text(row, '최종작성일')).isoformat()
            name = text(row, '시설명')
            if not (name and 32.5 <= lat <= 38.7 and 124 <= lon <= 132):
                raise ValueError('invalid position or name')
        except (ValueError, TypeError):
            rejected += 1
            continue
        access = text(row, '반려동물 동반 가능정보')
        conditions, size = text(row, '반려동물 제한사항'), text(row, '입장 가능 동물 크기')
        if access == 'N':
            status = 'notAllowed'
        elif access == 'Y':
            restricted = conditions and conditions.replace(' ', '') not in {'제한사항없음', '없음'}
            status = 'conditional' if restricted or size not in {'', '모두 가능', '모두가능'} else 'allowed'
        else:
            status = 'unknown'
        address = text(row, '도로명주소') or text(row, '지번주소')
        road = ROAD.search(address)
        policy = dict(status=status, conditions=conditions, sizeRule=size,
                      transportRule=conditions if re.search(r'유모차|케이지|캐리어|이동장|켄넬|캔넬|백팩|가방', conditions) else '',
                      areaRule=conditions if re.search(r'실내|실외|야외|구역|공용부', conditions) else '',
                      rentalRule='', fees=text(row, '애견 동반 추가 요금'),
                      openingHours=text(row, '운영시간'), sourceName='한국문화정보원 · 반려동물 동반 가능 문화시설',
                      sourceUrl=CULTURE_URL, referenceDate=reference,
                      indoorFacility=text(row, '장소(실내) 여부'), outdoorFacility=text(row, '장소(실외) 여부'))
        place_id = identity('pet-culture-', name, f'{lat:.5f}', f'{lon:.5f}')
        place = dict(id=place_id, name=name, category=CATEGORIES[kind], kind=kind,
                     address=address, lat=lat, lon=lon, phone=text(row, '전화번호'),
                     roadName=road[1] if road else '', buildingNumber=road[2] if road else '', admission=policy)
        previous = result.get(place_id)
        if previous is None or reference > previous['admission']['referenceDate']:
            result[place_id] = place
        elif reference == previous['admission']['referenceDate'] and status != previous['admission']['status']:
            previous['admission']['status'] = 'unknown'
            previous['admission']['conditions'] = '동일 기준일의 공개 자료가 상충하여 동반 가능 여부를 확인해야 합니다.'
    places = sorted(result.values(), key=lambda place: place['id'])
    return places, dict(sourceRows=len(records), accepted=len(places), invalid=rejected,
                        allowed=sum(p['admission']['status'] in {'allowed', 'conditional'} for p in places))


def normalize_food(records):
    result = {}
    for row in records:
        name, address = text(row, 'bsshNm'), text(row, 'siteAddr')
        road = ROAD.search(address)
        if not (name and address and road):
            continue
        key = identity('pet-food-', name, address)
        locality = next((part for part in address.split()[:3]
                         if part.endswith(('시', '군', '구')) and not part.endswith(('특별시', '광역시', '특별자치시'))), '')
        result[key] = dict(id=key, name=name, address=address, region=text(row, 'lgaldngNm'), locality=locality, road=road[1], number=road[2])
    return sorted(result.values(), key=lambda place: place['id']), dict(sourceRows=len(records), accepted=len(result))


def download_culture():
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def get(url, data=None):
        request = urllib.request.Request(url, data=data, headers={'User-Agent': 'Mungcation-Pet-Places/1.0'})
        with opener.open(request, timeout=60) as response:
            return response.read()
    page = get(CULTURE_URL).decode('utf-8')
    match = re.search(r"fn_fileDataDown\('15111389',\s*'([^']+)',\s*'([^']*)',\s*'([^']+)'", page)
    if not match:
        raise ValueError('Public download metadata changed')
    params = dict(publicDataPk='15111389', publicDataDetailPk=match[1], atchFileId=match[2], fileDetailSn=match[3], publicDataTyCode='PR0051')
    meta = json.loads(get('https://www.data.go.kr/tcs/dss/selectFileDataDownload.do?' + urllib.parse.urlencode(params)))
    if not meta.get('status'):
        raise ValueError('Download is unavailable')
    params = dict(atchFileId=meta['atchFileId'], fileDetailSn=meta['fileDetailSn'])
    check = json.loads(get('https://www.data.go.kr/cmm/cmm/check-limit.json', urllib.parse.urlencode(params).encode()))
    if check.get('needCaptcha'):
        raise ValueError('Public download requires human captcha; retaining the previous snapshot')
    params['dataNm'] = meta['dataSetFileDetailInfo']['dataNm']
    raw = get('https://www.data.go.kr/cmm/cmm/fileDownload.do?' + urllib.parse.urlencode(params))
    return raw.decode('utf-8-sig')


def parse_food(page):
    match = re.search(r'<script[^>]*id=["\']resultListData["\'][^>]*>(.*?)</script>', page, re.S)
    if not match:
        raise ValueError('Food registry format changed')
    return json.loads(match[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--culture-file', type=Path)
    parser.add_argument('--food-file', type=Path)
    args = parser.parse_args()
    culture = args.culture_file.read_text(encoding='utf-8-sig') if args.culture_file else download_culture()
    if args.food_file:
        food = args.food_file.read_text(encoding='utf-8')
    else:
        with urllib.request.urlopen(urllib.request.Request(FOOD_URL, headers={'User-Agent': 'Mungcation-Pet-Places/1.0'}), timeout=60) as response:
            food = response.read().decode('utf-8')
    places, culture_report = normalize_culture(list(csv.DictReader(io.StringIO(culture))))
    registered, food_report = normalize_food(parse_food(food))
    if not (len(places) >= 1000 and len(registered) >= 500):
        raise ValueError(f'Incomplete public snapshots: {culture_report}, {food_report}')
    curated = json.loads((ROOT / 'assets/data/pet_retail_sources.json').read_text(encoding='utf-8'))
    snapshot = datetime.now(timezone.utc).isoformat()
    assets = ROOT / 'assets/data'
    payloads = {
        'pet_places.json': dict(schema=1, retrievedAt=snapshot, report=culture_report,
                                policies=curated['policies'], places=places + curated['places']),
        'pet_food_registry.json': dict(schema=1, retrievedAt=snapshot, sourceUrl=FOOD_URL, report=food_report, places=registered),
    }
    # Validate both sources before replacing either asset. No coordinates are invented.
    for filename, payload in payloads.items():
        (assets / filename).write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    print(json.dumps(dict(culture=culture_report, registeredFood=food_report, curated=len(curated['places']))))


if __name__ == '__main__':
    main()
