import io
import tempfile
import unittest
import zipfile
from pathlib import Path

from import_pet_food_xlsx import read_food_workbook, build_snapshot


def workbook(*, formula=False, missing_header=False):
    headers = ['연번', '업소명', '업종', '지역', '업소주소']
    if missing_header:
        headers[-1] = '다른항목'
    rows = [headers, ['1', '테스트 성수점', '일반음식점', '서울', '서울특별시 성동구 왕십리로 10(1층)'],
            ['2', '주소 미확정', '휴게음식점', '서울', '서울특별시 성동구 성수동']]
    from xml.sax.saxutils import escape
    data = []
    for index, row in enumerate(rows, 1):
        cells = []
        for col, value in enumerate(row):
            f = '<f>HYPERLINK("https://example.org")</f>' if formula and index == 2 and col == 1 else ''
            cells.append(f'<c r="{chr(65+col)}{index}" t="inlineStr">{f}<is><t>{escape(value)}</t></is></c>')
        data.append(f'<row r="{index}">{"".join(cells)}</row>')
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w') as archive:
        archive.writestr('xl/worksheets/sheet1.xml',
                         '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + ''.join(data) + '</sheetData></worksheet>')
    return out.getvalue()


class FoodWorkbookTest(unittest.TestCase):
    def with_file(self, **options):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        path = Path(folder.name) / 'food.xlsx'
        path.write_bytes(workbook(**options))
        return path

    def test_import_retains_exact_branch_and_address_and_no_coordinates(self):
        records = read_food_workbook(self.with_file())
        snapshot = build_snapshot(records, '2026-11-20T14:50:00+09:00', source_file='food.xlsx')
        self.assertEqual(snapshot['report']['sourceRows'], 2)
        self.assertEqual(snapshot['report']['accepted'], 1)
        self.assertEqual(snapshot['report']['unresolved'], 1)
        self.assertEqual(snapshot['places'][0]['name'], '테스트 성수점')
        self.assertEqual(snapshot['places'][0]['number'], '10')
        self.assertNotIn('lat', snapshot['places'][0])
        self.assertEqual(snapshot['sourceAsOf'], '2026-11-20T14:50:00+09:00')

    def test_headers_are_required_and_formulas_are_not_business_data(self):
        for options in [{'missing_header': True}, {'formula': True}]:
            with self.subTest(options=options), self.assertRaises(ValueError):
                read_food_workbook(self.with_file(**options))

    def test_source_timestamp_requires_a_timezone(self):
        with self.assertRaises(ValueError):
            build_snapshot([], '2026-11-20T14:50:00', source_file='food.xlsx')


if __name__ == '__main__':
    unittest.main()
