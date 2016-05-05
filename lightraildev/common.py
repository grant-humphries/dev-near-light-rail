import os
from datetime import datetime
from os.path import exists, getmtime, join

from arcpy import CheckExtension, CheckOutExtension

# each iteration of the project is stored in a folder that reflects the
# date of the latest tax lot data
RLIS_DIR = '//gisstore/gis/Rlis'
TAXLOTS = join(RLIS_DIR, 'TAXLOTS', 'taxlots.shp')
DATE_DIR = datetime.fromtimestamp(getmtime(TAXLOTS)).strftime('%Y_%m')

HOME = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail'
DATA_DIR = join(HOME, 'data', DATE_DIR)
SHP_DIR = join(DATA_DIR, 'shp')
TEMP_DIR = join(DATA_DIR, 'temp')
MAX_STOPS = join(SHP_DIR, 'max_stops.shp')

OSM_PED_NAME = 'osm_ped_network'
OSM_PED_SHP = join(SHP_DIR, '{}.shp'.format(OSM_PED_NAME))
OSM_PED_GDB = join(DATA_DIR, '{}.gdb'.format(OSM_PED_NAME))
OSM_PED_FDS = join(OSM_PED_GDB, '{}_fds'.format(OSM_PED_NAME))
OSM_PED_FC = join(OSM_PED_FDS, '{}_fc'.format(OSM_PED_NAME))
OSM_PED_ND = join(OSM_PED_FDS, '{}_nd'.format(OSM_PED_NAME))

ATTRIBUTE_PED = 'pedestrian_permissions'
ATTRIBUTE_LEN = 'length'
ATTRIBUTE_MIN = 'minutes'

for dir_ in (SHP_DIR, TEMP_DIR):
    if not exists(dir_):
        os.makedirs(dir_)

DESC_FIELD = 'route_desc'
ID_FIELD = 'stop_id'
ROUTES_FIELD = 'routes'
STOP_FIELD = 'stop_name'


def checkout_arcgis_extension(extension):
    """"""

    if CheckExtension(extension) == 'Available':
        CheckOutExtension(extension)
    else:
        print "the '{}' extension is unavailable so the script can't run " \
              "successfully, if you have ArcGIS Desktop open close it, as " \
              "it may be utilizing the license, otherwise check the " \
              "license server log to determine who has it checked out"
        exit()
