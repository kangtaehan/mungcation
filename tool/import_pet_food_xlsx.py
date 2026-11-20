"""Import the supplied food-registration workbook without inventing map points."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

from update_pet_places import normalize_food, FOOD_URL, ROOT, ROAD, text

NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def read_food_workbook(path):
    with zipfile.ZipFile(path) as archive:
        if sum(item.file_size for item in archive.infolist()) > 30_000_000:
            raise ValueError('Workbook exceeds the supported size.')
        shared = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            shared = [''.join(item.itertext()) for item in
                      ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('s:si', NS)]
        matches = []
        for filename in archive.namelist():
            if not re.fullmatch(r'xl/worksheets/sheet\d+\.xml', filename):
                continue
            rows = []
            for row in ET.fromstring(archive.read(filename)).findall('s:sheetData/s:row', NS):
                values = {}
                for cell in row.findall('s:c', NS):
                    if cell.find('s:f', NS) is not None:
                        raise ValueError('Formula cells cannot be imported as registration facts.')
                    column = re.fullmatch(r'([A-Z]+)\d+', cell.get('r', ''))
                    if column is None:
                        raise ValueError('Invalid cell reference.')
                    value = cell.find('s:v', NS)
                    value = value.text or '' if value is not None else ''
                    if cell.get('t') == 's':
                        value = shared[int(value)]
                    elif cell.get('t') == 'inlineStr':
                        node = cell.find('s:is', NS)
                        value = ''.join(node.itertext()) if node is not None else ''
                    values[column[1]] = value.strip()
                if any(values.values()):
                    rows.append(values)
            for index, row in enumerate(rows[:10]):
                columns = {value: key for key, value in row.items()}
                if not {'업소명', '업소주소', '지역'} <= columns.keys():
                    continue
                matches.append([
                    dict(bsshNm=item.get(columns['업소명'], ''),
                         siteAddr=item.get(columns['업소주소'], ''),
                         lgaldngNm=item.get(columns['지역'], ''),
                         businessType=item.get(columns.get('업종'), ''))
                    for item in rows[index + 1:]
                ])
                break
        if len(matches) != 1:
            raise ValueError('Exactly one sheet with business name, address and region headers is required.')
        return matches[0]


def build_snapshot(records, as_of, *, source_file):
    reference = datetime.fromisoformat(as_of)
    if reference.tzinfo is None:
        raise ValueError('The workbook reference timestamp must include a timezone.')
    places, report = normalize_food(records)
    unresolved = [
        dict(name=text(row, 'bsshNm'), address=text(row, 'siteAddr'), region=text(row, 'lgaldngNm'))
        for row in records
        if not (text(row, 'bsshNm') and text(row, 'siteAddr') and ROAD.search(text(row, 'siteAddr')))
    ]
    report.update(unresolved=len(unresolved), duplicates=len(records) - len(unresolved) - len(places))
    return dict(schema=1, retrievedAt=datetime.now(timezone.utc).isoformat(),
                sourceUrl=FOOD_URL, sourceAsOf=reference.isoformat(), sourceFile=source_file,
                report=report, places=places, unresolved=unresolved)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workbook', type=Path)
    parser.add_argument('--as-of', required=True, help='Reference timestamp printed on the supplied workbook, including offset')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/data/pet_food_registry.json')
    args = parser.parse_args()
    payload = build_snapshot(read_food_workbook(args.workbook), args.as_of, source_file=args.workbook.name)
    if len(payload['places']) < 500:
        parser.error('Incomplete national registration list; the previous asset was retained.')
    payload['sourceSha256'] = hashlib.sha256(args.workbook.read_bytes()).hexdigest()
    old = json.loads(args.output.read_text(encoding='utf-8')) if args.output.exists() else {'places': []}
    previous = {row['id'] for row in old['places']}
    current = {row['id'] for row in payload['places']}
    # Replace the one validated asset atomically; park and culture data are untouched.
    staging = args.output.with_suffix('.json.tmp')
    staging.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    staging.replace(args.output)
    print(json.dumps(dict(**payload['report'], previous=len(previous), added=len(current-previous), removed=len(previous-current))))


if __name__ == '__main__':
    main()
