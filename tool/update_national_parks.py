"""Refresh the public national urban-park download without an API key.

Source page and download parameters are published by data.go.kr's download UI.
The output contains only official names; rejected rows are counted, never guessed.
"""
import argparse
from datetime import date, datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import urllib.parse
import urllib.request

SOURCE = 'https://www.data.go.kr/data/15012890/standard.do'
ROOT = Path(__file__).resolve().parents[1]


def normalize_records(records):
    unique = {}
    rejected = 0
    duplicates = 0
    for raw in records:
        text = lambda key: str(raw.get(key) or '').strip()
        name = re.sub(r'\s+', ' ', text('PARK_NM'))
        try:
            lat, lon = float(text('LATITUDE')), float(text('LONGITUDE'))
            reference = date.fromisoformat(text('REFERENCE_DATE')).isoformat()
            if not (name and 32.5 <= lat <= 38.7 and 124 <= lon <= 132):
                raise ValueError('Invalid name or coordinates')
            if re.fullmatch(r'[가-힣0-9·.]+(?:동|읍|면|리)', name):
                raise ValueError('Administrative name only')
        except (ValueError, TypeError):
            rejected += 1
            continue
        # Management numbers are not globally unique, even within one agency.
        # Match exact names and coordinates only; never guess across nearby parks.
        identity = f'{name}|{lat:.5f}|{lon:.5f}'
        park_id = 'kr-park-' + hashlib.sha256(identity.encode()).hexdigest()[:20]
        row = [park_id, name, text('PARK_SE'),
               text('RDNMADR') or text('LNMADR'), lat, lon,
               text('PHONE_NUMBER'), reference, text('INSTITUTION_NM')]
        old = unique.get(identity)
        if old is not None:
            duplicates += 1
        if old is None or (row[7], bool(row[3]), bool(row[6])) > (old[7], bool(old[3]), bool(old[6])):
            unique[identity] = row
    parks = sorted(unique.values(), key=lambda row: row[0])
    return parks, dict(sourceRows=len(records), accepted=len(parks), rejected=rejected, duplicates=duplicates)


def get_json(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mungcation-Park-Catalog/1.0', 'Accept': 'application/json'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def download_records():
    header = get_json('https://www.data.go.kr/download/columList.json?pk=15012890&ext=JSON')
    total = int(header['totalCount'])
    if not 10000 <= total <= 50000:
        raise ValueError(f'Unexpected national source count: {total}')
    records = []
    for page in range(1, math.ceil(total / 10000) + 1):
        params = dict(publicDataPk='15012890', colNmList=header['tableVO']['colNmList'],
                      totalCount=total, svcTableNm=header['tableVO']['svcTableNm'], perPage=10000, page=page)
        batch = get_json('https://www.data.go.kr/download/standard.json?' + urllib.parse.urlencode(params, doseq=True))
        if not isinstance(batch, list):
            raise ValueError('Unexpected download format')
        records.extend(batch)
    if len(records) != total:
        raise ValueError(f'Incomplete source: {len(records)} of {total}')
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', nargs='+', type=Path, help='Use previously downloaded official JSON batches')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/data/national_parks.json')
    args = parser.parse_args()
    records = [row for path in args.input for row in json.loads(path.read_bytes())] if args.input else download_records()
    parks, report = normalize_records(records)
    if len(parks) < 10000 or report['rejected'] / len(records) > .05:
        raise ValueError(f'Catalog validation failed: {report}')
    payload = dict(schema=1, source=SOURCE, retrievedAt=datetime.now(timezone.utc).isoformat(),
                   report=report, oldestReference=min(row[7] for row in parks), newestReference=max(row[7] for row in parks), parks=parks)
    encoded = json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n'
    # Prepare and validate the entire snapshot before replacing the current asset.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(encoded, encoding='utf-8')
    print(json.dumps(report), 'bytes:', len(encoded.encode()))


if __name__ == '__main__':
    main()
