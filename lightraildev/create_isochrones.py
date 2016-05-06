import re
import sys
from argparse import ArgumentParser
from datetime import datetime
from os.path import basename, dirname, join

from arcpy import env,  CheckInExtension, ListFields, SpatialReference
from arcpy.analysis import GenerateNearTable
from arcpy.da import InsertCursor, SearchCursor, UpdateCursor
from arcpy.management import AddField, CopyFeatures, CreateFeatureclass, \
    DeleteField, MakeFeatureLayer, SelectLayerByAttribute
from arcpy.mapping import ListLayers
from arcpy.na import AddLocations, GetSolverProperties, GetNAClassNames, \
    MakeServiceAreaLayer, Solve

from lightraildev.common import checkout_arcgis_extension, ATTRIBUTE_LEN, \
    ATTRIBUTE_PED, DESC_FIELD, HOME, ID_FIELD, MAX_STOPS, OSM_PED_ND, \
    ROUTES_FIELD, SHP_DIR, STOP_FIELD, TEMP_DIR

MAX_ZONES = join(HOME, 'data', 'shp', 'max_stop_zones.shp')
ISOCHRONES = join(SHP_DIR, 'isochrones.shp')

DIST_FIELD = 'walk_dist'
UNIQUE_FIELD = 'name'
YEAR_FIELD = 'incpt_year'
ZONE_FIELD = 'max_zone'


def add_name_field():
    """Only a field called 'name' will be retained when locations are
    loaded into a service area analysis, as the MAX stops will be.  
    This field is populated that field with unique identifiers so that
    the other attributes from this data can be linked to the network 
    analyst output
    """

    fields = [f.name for f in ListFields(MAX_STOPS)]

    if UNIQUE_FIELD not in fields:
        f_type = 'LONG'
        AddField(MAX_STOPS, UNIQUE_FIELD, f_type)
    
        u_fields = [ID_FIELD, UNIQUE_FIELD]
        with UpdateCursor(MAX_STOPS, u_fields) as cursor:
            for stop_id, name in cursor:
                name = stop_id
                cursor.updateRow((stop_id, name))


def assign_max_zones():
    """Add an attribute to max stops that indicates which 'MAX Zone' it
    falls within, the max_zone feature class is used in conjunction with
    max stops to make this determination
    """

    # Create a mapping from zone object id's to their names
    max_zone_dict = dict()
    fields = ['OID@', UNIQUE_FIELD]
    with SearchCursor(MAX_ZONES, fields) as cursor:
        for oid, name in cursor:
            max_zone_dict[oid] = name

    # Find the nearest zone to each stop
    stop_zone_table = join(TEMP_DIR, 'stop_zone_near_table.dbf')
    GenerateNearTable(MAX_STOPS, MAX_ZONES, stop_zone_table)

    # Create a mapping from stop oid's to zone oid's
    stop2zone = dict()
    fields = ['IN_FID', 'NEAR_FID']
    with SearchCursor(stop_zone_table, fields) as cursor:
        for stop_oid, zone_oid in cursor:
            stop2zone[stop_oid] = zone_oid

    f_type = 'TEXT'
    AddField(MAX_STOPS, ZONE_FIELD, f_type)

    fields = ['OID@', ZONE_FIELD]
    with UpdateCursor(MAX_STOPS, fields) as cursor:
        for oid, zone in cursor:
            zone = max_zone_dict[stop2zone[oid]]

            cursor.updateRow((oid, zone))


def add_inception_year():
    """Each MAX line has a decision to build year, add that information
    as an attribute to the max stops.  If a max stop serves multiple
    lines the year from the oldest line will be assigned.
    """

    f_type = 'LONG'
    AddField(MAX_STOPS, YEAR_FIELD, f_type)

    # Note that 'MAX Year' for stops within the CBD are variable as
    # stops within that region were not all built at the same time
    # (this is not the case for all other MAX zones)
    fields = [ID_FIELD, DESC_FIELD, ZONE_FIELD, YEAR_FIELD]
    with UpdateCursor(MAX_STOPS, fields) as cursor:
        for stop_id, rte_desc, zone, year in cursor:
            if 'MAX Blue Line' in rte_desc \
                    and zone not in ('West Suburbs', 'Southwest Portland'):
                year = 1980
            elif 'MAX Blue Line' in rte_desc:
                year = 1990
            elif 'MAX Red Line' in rte_desc:
                year = 1997
            elif 'MAX Yellow Line' in rte_desc \
                    and zone != 'Central Business District':
                year = 1999
            elif 'MAX Green Line' in rte_desc:
                year = 2003
            elif 'MAX Orange Line' in rte_desc:
                year = 2008
            else:
                print 'Stop {} not assigned a MAX Year, cannot proceed ' \
                      'with out this assignment, examine code/data for ' \
                      'errors'.format(stop_id)
                exit()

            cursor.updateRow((stop_id, rte_desc, zone, year))


def create_walk_groups(zones, name, inverse=False):
    """If different walk distances must be used in the creation of
    isochrones for different stops they must be generated by separate
    executions of the service area analysis. This function creates
    separate feature classes for those groups, the zones parameter
    must be a list
    """

    # Create a feature layer so that selections can be made on the data
    stops_layer = 'max_stops'
    MakeFeatureLayer(MAX_STOPS, stops_layer)

    # Assign a variable that will determine if the output is the zones
    # provide or all of the zones that are not provided
    negate = 'NOT' if inverse else ''

    select_type = 'NEW_SELECTION'
    zones_str = ', '.join("'{}'".format(z) for z in zones)
    where_clause = '"{0}" {1} IN ({2})'.format(ZONE_FIELD, negate, zones_str) 
    SelectLayerByAttribute(stops_layer, select_type, where_clause)

    zone_stops = join(TEMP_DIR, '{}.shp'.format(name))
    CopyFeatures(stops_layer, zone_stops)

    return zone_stops


def create_isochrone_fc():
    """Create a new feature class to store all isochrones created later
    in the work flow
    """

    geom_type = 'POLYGON'
    ospn = SpatialReference(2913)
    CreateFeatureclass(dirname(ISOCHRONES), basename(ISOCHRONES),
                       geom_type, spatial_reference=ospn)

    field_names = [
        ID_FIELD,  STOP_FIELD,  ROUTES_FIELD,
        ZONE_FIELD, YEAR_FIELD, DIST_FIELD]

    for f_name in field_names:
        if f_name in (ID_FIELD, YEAR_FIELD):
            f_type = 'LONG'
        elif f_name in (STOP_FIELD, ROUTES_FIELD, ZONE_FIELD):
            f_type = 'TEXT'
        elif f_name == DIST_FIELD:
            f_type = 'DOUBLE'

        AddField(ISOCHRONES, f_name, f_type)

    # drop Id field that is created by default
    DeleteField(ISOCHRONES, 'Id')


def generate_isochrones(locations, break_value):
    """Create walk shed polygons using the OpenStreetMap network from
    the input locations to the distance of the input break value
    """

    # Create and configure a service area layer, these have the ability
    # generate isochrones
    network_dataset = OSM_PED_ND
    sa_name = 'service_area'
    impedance_attribute = ATTRIBUTE_LEN
    sa_layer = MakeServiceAreaLayer(
        network_dataset, sa_name, impedance_attribute, 'TRAVEL_TO',
        restriction_attribute_name=ATTRIBUTE_PED).getOutput(0)

    # Within the service area layer there are several sub-layers where
    # things are stored such as facilities, polygons, and barriers.
    sa_classes = GetNAClassNames(sa_layer)

    # GetNAClassNames returns a dictionary in which the values are
    # strings that are the names of each class, to get their
    # corresponding layer objects the ListLayers method must be used
    facilities_str = sa_classes['Facilities']
    isochrones_lyr = ListLayers(sa_layer, sa_classes['SAPolygons'])[0]

    solver_props = GetSolverProperties(sa_layer)
    solver_props.defaultBreaks = break_value

    # Service area locations must be stored in the facilities sublayer
    clear_other_stops = 'CLEAR'
    exclude_for_snapping = 'EXCLUDE'
    AddLocations(sa_layer, facilities_str, locations,
                 append=clear_other_stops,
                 exclude_restricted_elements=exclude_for_snapping)

    # Generate the isochrones for this batch of stops, the output will
    # automatically go to the 'sa_isochrones' variable
    Solve(sa_layer)

    i_fields = ['SHAPE@', ID_FIELD, DIST_FIELD]
    i_cursor = InsertCursor(ISOCHRONES, i_fields)

    s_fields = ['SHAPE@', UNIQUE_FIELD]
    with SearchCursor(isochrones_lyr, s_fields) as cursor:
        for geom, output_name in cursor:
            iso_attributes = re.split('\s:\s0\s-\s', output_name)
            stop_id = int(iso_attributes[0])
            break_value = int(iso_attributes[1])

            i_cursor.insertRow((geom, stop_id, break_value))

    del i_cursor


def add_iso_attributes():
    """Append attributes from the original max stops data to the
    isochrones feature class, matching features stop id's field
    (which are in the 'stop_id' and 'name' fields
    """

    rail_stop_dict = dict()
    s_fields = [ID_FIELD, STOP_FIELD, ROUTES_FIELD, ZONE_FIELD, YEAR_FIELD]
    with SearchCursor(MAX_STOPS, s_fields) as s_cursor:
        sid_ix = s_cursor.fields.index(ID_FIELD)
        
        for row in s_cursor:
            stop_id = row[sid_ix]
            rail_stop_dict[stop_id] = list(row)

    # area value will be used to check for errors in isochrone creation
    iso_fields = [f.name for f in ListFields(ISOCHRONES)]
    area_field = 'area'
    if area_field not in iso_fields:
        f_type = 'DOUBLE'
        AddField(ISOCHRONES, area_field, f_type)
    
    area_val = 'SHAPE@AREA'
    u_fields = s_fields + [area_field, area_val]
    with UpdateCursor(ISOCHRONES, u_fields) as u_cursor:
        sid_ix = u_cursor.fields.index(ID_FIELD)
        val_ix = u_cursor.fields.index(area_val)
        
        for row in u_cursor:
            stop_id = row[sid_ix]
            area = row[val_ix]
            
            i_row = rail_stop_dict[stop_id]
            i_row.extend([area, area])
            u_cursor.updateRow(i_row)


def process_options(args):
    """"""

    parser = ArgumentParser()
    parser.add_argument(
        '-d', '--walk_distance',
        type=int,
        default=2640,
        help='distance, in feet, that defines the limit of the walk shed'
    )

    options = parser.parse_args(args)
    return options


def main():
    """"""

    args = sys.argv[1:]
    opts = process_options(args)

    start_time = datetime.now().strftime('%I:%M %p')
    print '4) Creating isochrones with walk distance of {0} feet, start ' \
          'time is: {1}, run time is: ~1.25 minutes...\n'.format(
               opts.walk_distance, start_time)

    # configure arcpy settings
    env.overwriteOutput = True
    checkout_arcgis_extension('Network')

    # Prep stop data
    add_name_field()
    assign_max_zones()
    add_inception_year()

    create_isochrone_fc()
    generate_isochrones(MAX_STOPS, opts.walk_distance)
    add_iso_attributes()

    CheckInExtension('Network')

if __name__ == '__main__':
    main()
