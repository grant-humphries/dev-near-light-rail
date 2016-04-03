import os
from datetime import datetime
from os.path import exists, getmtime, join

# each iteration of the project is stored in a folder that reflects the
# date of the latest tax lot data
RLIS_DIR = '//gisstore/gis/Rlis'
TAXLOTS = join(RLIS_DIR, 'TAXLOTS', 'taxlots.shp')
date_dir = datetime.fromtimestamp(getmtime(TAXLOTS)).strftime('%Y_%m')

HOME = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail'
DATA_DIR = join(HOME, 'data', date_dir)
SHP_DIR = join(DATA_DIR, 'shp')
MAX_STOPS = join(DATA_DIR, 'shp', 'max_stops.shp')

if not exists(SHP_DIR):
    os.makedirs(SHP_DIR)

DESC_FIELD = 'route_desc'
ID_FIELD = 'stop_id'
ROUTES_FIELD = 'routes'
STOP_FIELD = 'stop_name'
