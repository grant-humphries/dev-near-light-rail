import csv
from os.path import join

# this module comes from the pypiwin32 package
from win32com.client import Dispatch
from xlsxwriter import Workbook

from lightraildev.common import DATA_DIR, EXCEL_DIR, TAXLOT_DATE

CSV_DIR = join(DATA_DIR, 'csv')
EXCEL_BASENAME = 'light_rail_dev_stats_{}.xlsx'.format(TAXLOT_DATE)
EXCEL_PATH = join(EXCEL_DIR, EXCEL_BASENAME)
STATS_TABLES = ('final_stats', 'final_stats_minus_max')
SHEET_BASENAME = 'comparisons {}clude study group'
SHEET_TYPE = ['in', 'ex']

HEADER_MAP = {
    'group_desc': 'Group',
    'max_zone': 'MAX Zone',
    'max_year': 'Decision to Build Year',
    'walk_dist': 'Walk Distance (feet)',
    'totalval': 'Market Property Value',
    'housing_units': 'New Multifamily Housing Units',
    'gis_acres': 'Acres',
    'totalval_per_acre': 'Value/Acre',
    'units_per_acre': 'Units/Acre'
}

FOOTNOTE = 'click this text to view metadata and source information for ' \
           'these statistics'
METADATA_URL = 'https://github.com/grant-humphries/dev-near-light-rail/' \
               'blob/master/METADATA.md'


def csv_to_xlsx():
    """"""

    # xlsxwriter format info: http://xlsxwriter.readthedocs.io/format.html

    aqua = '#31849B'
    gold = '#DDD9C3'
    gray = '#D8D8D8'
    light_gold = '#EEECE1'
    light_gray = '#F2F2F2'
    white = 'white'

    money_format = '$#,##0'
    int_format = '#,##0'
    float_format = '#,##0.00'

    wb = Workbook(EXCEL_PATH, {'strings_to_numbers': True})

    header_format = wb.add_format({
        'align': 'center',
        'bg_color': aqua,
        'bold': True,
        'font_color': white
    })
    footer_format = wb.add_format({
        'bg_color': aqua,
        'bold': True,
        'font_color': white,
        'underline': 1
    })

    for x, tbl in enumerate(STATS_TABLES):
        csv_path = join(CSV_DIR, '{}.csv'.format(tbl))
        ws = wb.add_worksheet(SHEET_BASENAME.format(SHEET_TYPE[x]))
        ws.freeze_panes(1, 0)

        with open(csv_path) as stats_csv:
            stats_reader = csv.reader(stats_csv)
            rows = len(list(stats_reader))
            stats_csv.seek(0)

            header = next(stats_reader)
            cols = len(header)
            for j, item in enumerate(header):
                ws.write(0, j, HEADER_MAP[item], header_format)

            for i, row in enumerate(stats_reader, 1):
                # set row colors
                if i == 1:
                    bg_color = gold
                elif i <= 4:
                    bg_color = light_gold
                elif i % 4 == 1:
                    bg_color = gray
                else:
                    bg_color = light_gray

                for j, item in enumerate(row):
                    cell_format = wb.add_format({
                        'bg_color': bg_color,
                        'border': 1,  # solid, width 1
                        'border_color': gray
                    })

                    # format numbers/set alignment
                    if j == 2:
                        cell_format.set_align('right')
                    elif j in (3, 5):
                        cell_format.set_num_format(int_format)
                    elif j in (4, 7):
                        cell_format.set_num_format(money_format)
                    elif j in (6, 8):
                        cell_format.set_num_format(float_format)

                    ws.write(i, j, item, cell_format)

        ws.merge_range(rows, 0, rows, cols - 1, '')
        ws.write_url(rows, 0, METADATA_URL, footer_format, FOOTNOTE)

    wb.close()


def autofit_column_width():
    """"""

    excel = Dispatch('Excel.Application')
    wb = excel.Workbooks.Open(EXCEL_PATH)

    for ws in wb.WorkSheets:
        ws.Columns.AutoFit()

    wb.Save()
    wb.Close()


def main():
    """"""

    print "\n6) Converting stats csv's into a formatted excel workbook..."

    csv_to_xlsx()
    autofit_column_width()


if __name__ == '__main__':
    main()
