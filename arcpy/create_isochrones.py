# Grant Humphries for TriMet, 2013-14
# ArcGIS Version:   10.2.2
# Python Version:   2.7.5
#--------------------------------

import os
import sys
import re
import timing
import arcpy
from arcpy import env

# Check out the Network Analyst extension
arcpy.CheckOutExtension("Network")

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True

# Set workspace, the user will be prompted to enter the name of the subfolder that data is to be
# written to for the current iteration
project_folder = raw_input('Enter the name of the subfolder being used for this iteration of the project (should be in the form "YYYY_MM"): ')
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/' + project_folder

# Create a 'temp' folder to hold intermediate datasets, and a 'csv' folder to hold output spreadsheets
# (the latter won't be used until a later phase of this project), if they don't already exist
new_folders = ['temp', 'csv']
for folder in new_folders:
	if not os.path.exists(os.path.join(env.workspace, folder)):
		os.makedirs(os.path.join(env.workspace, folder))

# This comes from maps10.trimet.org's postgres database and only contains MAX stops in service
max_stops = os.path.join(env.workspace, 'max_stops.shp')

#-----------------------------------------------------------------------------------------------------
# This section can be removed once the orange line stops are added stops tables on maps10

# Insert orange line stops, which are in the spatial db at this time, into the shapefile conataining
# all of the other MAX stops
orange_stops = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/projected_orange_line_stops.shp'

# Check to see if the orange stops have already been added...
orange_added = False
fields = ['OID@', 'routes']
with arcpy.da.SearchCursor(max_stops, fields) as cursor:
	for oid, routes in cursor:
		if routes == ':MAX Orange Line:':
			orange_added = True
			break

# If they haven't add them
if not orange_added:
	fields = ['SHAPE@', 'stop_id', 'stop_name', 'routes', 'begin_date', 'end_date']
	i_cursor = arcpy.da.InsertCursor(max_stops, fields)

	with arcpy.da.SearchCursor(orange_stops, fields) as cursor:
		for geom, stop_id, name, routes, b_date, e_date in cursor:
			i_cursor.insertRow((geom, stop_id, name, routes, b_date, e_date))

	del i_cursor

#-----------------------------------------------------------------------------------------------------

# Only a field called 'name' will be retained when locations are loaded into service area analysis as the
# MAX stops will be.  In that field I need unique identifiers so attributes from this data can be properly
# linked to the network analyst output
f_name = 'name'
f_type = 'LONG'
arcpy.management.AddField(max_stops, f_name, f_type)

fields = ['stop_id', 'name']
with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
	for stop_id, name in cursor:
		name = stop_id
		cursor.updateRow((stop_id, name))


# An attribute needs to be added to the max stops layer that indicates which 'MAX zone' it falls 
# within, the max_zone feature class below is the source of that determination.  Whichever zone
# a stop falls within it is assigned.

# These areas are used to divide the stops into tabulation groups
max_zones = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/max_stop_zones.shp'

# Create a mapping from zone object id's to their names
max_zone_dict = {}
fields = ['OID@', 'name']
with arcpy.da.SearchCursor(max_zones, fields) as cursor:
	for oid, name in cursor:
		max_zone_dict[oid] = name

# Find the nearest zone to each stop
stop_zone_n_table = os.path.join(env.workspace, 'temp/stop_zone_near_table.dbf')
arcpy.analysis.GenerateNearTable(max_stops, max_zones, stop_zone_n_table)

# Create a mapping from stop oid's to zone oid's
stop2zone_dict = {}
fields = ['IN_FID', 'NEAR_FID']
with arcpy.da.SearchCursor(stop_zone_n_table, fields) as cursor:
	for stop_oid, zone_oid in cursor:
		stop2zone_dict[stop_oid] = zone_oid

# Add a field to store the zone name on the stops fc and populate it
f_name = 'max_zone'
f_type = 'TEXT'
arcpy.management.AddField(max_stops, f_name, f_type)

fields = ['OID@', 'max_zone']
with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
	for oid, zone in cursor:
		zone = max_zone_dict[stop2zone_dict[oid]]

		cursor.updateRow((oid, zone))


# Each MAX line has a decision to build year associated with it and that information needs to be
# transferred to the stops.  If a MAX stop serves multiple lines the year from the oldest line 
# will be assigned. 
f_name = 'incpt_year'
f_type = 'SHORT'
arcpy.management.AddField(max_stops, f_name, f_type)

# Note that 'MAX Year' for stops within the CBD are varaible as stops within that region were not
# all built at the same time (this is not the case for all other MAX zones)
fields = ['stop_id', 'routes', 'max_zone', 'incpt_year']
with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
	for stop_id, routes, zone, year in cursor:
		if ':MAX Blue Line:' in routes and zone not in ('West Suburbs', 'Southwest Portland'):
			year = 1980
		elif ':MAX Blue Line:' in routes and zone in ('West Suburbs', 'Southwest Portland'):
			year = 1990
		elif ':MAX Red Line:' in routes:
			year = 1997
		elif ':MAX Yellow Line:' in routes:
			year = 1999
		elif ':MAX Green Line:' in routes:
			year = 2003
		elif ':MAX Orange Line:' in routes:
			year = 2008
		else:
			print 'Stop ' + str(stop_id) + ' not assigned a MAX Year'
			print 'Cannot proceed with out this assignment, examine code, data for errors'
			sys.exit()

		cursor.updateRow((stop_id, routes, zone, year))


# Create a feature layer so that selections can be made on the data
max_stop_layer = 'max_stop_layer'
arcpy.management.MakeFeatureLayer(max_stops, max_stop_layer)

# Select only MAX in the CBD
select_type = 'NEW_SELECTION'
where_clause = """ "max_zone" = 'Central Business District' """
arcpy.management.SelectLayerByAttribute(max_stop_layer, select_type, where_clause)

cbd_max = os.path.join(env.workspace, 'temp/cbd_max.shp')
arcpy.management.CopyFeatures(max_stop_layer, cbd_max)

# Now select all MAX that are not in the CBD
select_type = 'SWITCH_SELECTION'
arcpy.management.SelectLayerByAttribute(max_stop_layer, select_type)

outer_max = os.path.join(env.workspace, 'temp/outer_max.shp')
arcpy.management.CopyFeatures(max_stop_layer, outer_max)


# Create a new feature class to store all of the isochrones that will be created
final_isochrones = os.path.join(env.workspace, 'max_stop_isochrones.shp')
geom_type = 'POLYGON'
epsg = arcpy.SpatialReference(2913)
arcpy.management.CreateFeatureclass(os.path.dirname(final_isochrones), os.path.basename(final_isochrones), 
									geom_type, spatial_reference=epsg)

# Add all fields that are needed in the new feature class, and drop the 'Id' field that exists
# by default
field_names = ['stop_id', 'stop_name', 'routes', 'max_zone', 'incpt_year', 'walk_dist']
for f_name in field_names:
	if f_name in ('stop_id', 'incpt_year'):
		f_type = 'LONG'
	elif f_name in ('stop_name', 'routes', 'max_zone'):
		f_type = 'TEXT'
	elif f_name == 'walk_dist':
		f_type = 'DOUBLE'
	
	arcpy.management.AddField(final_isochrones, f_name, f_type)

drop_field = 'Id'
arcpy.management.DeleteField(final_isochrones, drop_field)

# create an insert cursor to populate the new feature class
i_fields = ['SHAPE@', 'stop_id', 'walk_dist']
i_cursor = arcpy.da.InsertCursor(final_isochrones, i_fields) 

# Create and configure a service area layer
osm_network = os.path.join(env.workspace, 'osm_foot_ND.nd')
service_area_name = 'service_area_layer'
impedance_attribute = 'Length'
travel_from_to = 'TRAVEL_TO'
permissions = 'foot_permissions'
service_area_layer = arcpy.na.MakeServiceAreaLayer(osm_network, service_area_name, 
								impedance_attribute, travel_from_to, 
								restriction_attribute_name=permissions).getOutput(0)

# Within the service area layer there are several sub-layers where things are stored such as facilities,
# polygons, and barriers.  Grab the facilities and polygons sublayers and assign them to variables
sa_sublayer_dict = arcpy.na.GetNAClassNames(service_area_layer)

sa_facilities = sa_sublayer_dict['Facilities']
sa_isochrones = sa_sublayer_dict['SAPolygons']

def generateisochrones(locations, break_value):
	# Set the break distance for this batch of stops
	solver_props = arcpy.na.GetSolverProperties(service_area_layer)
	solver_props.defaultBreaks = break_value

	# Add the stops to the service area (sub)layer
	exclude_for_snapping = 'EXCLUDE'
	clear_other_stops = 'CLEAR'
	# Service area locations must be stored in the facilities sublayer
	arcpy.na.AddLocations(service_area_layer, sa_facilities, 
							locations, append=clear_other_stops,
							exclude_restricted_elements=exclude_for_snapping)

	# Generate the isochrones for this batch of stops, the output will automatically go to the 
	# 'SAPolygons' sub layer of the service area layer which has been assigned to the variable
	# 'sa_isochrones'
	arcpy.na.Solve(service_area_layer)

	# Grab the needed fields from the isochrones and write them to the feature class created to house
	# them.  The features will only be added if their stop_id is not in the final isochrones fc
	fields = ['SHAPE@', 'name']
	with arcpy.da.SearchCursor(sa_isochrones, fields) as cursor:
		for geom, output_name in cursor:
			iso_attributes = re.split(' : 0 - ', output_name)
			
			stop_id = int(iso_attributes[0])
			break_value = int(iso_attributes[1])

			i_cursor.insertRow((geom, stop_id, break_value))

# Set parameters specific to each set of isochrones:
# For now I'm using 2640 feet (half a mile) for the CBD walk limit, have experimented with using 2475',
# 3300' and 4125' and am still working with Alan Lehto to finalize this number
cbd_max_distance = 2640
generateisochrones(cbd_max, cbd_max_distance)

# 0.5 miles
outer_max_distance = 2640
generateisochrones(outer_max, outer_max_distance)

# Cursor should be discarded now that it is no longer needed (can cause execution problems if not done)
del i_cursor

# Get value attributes from the original max stops data and add it to the new isochrones feature class, 
# matching corresponding features.
fields = ['stop_id', 'stop_name', 'routes', 'max_zone', 'incpt_year']
rail_stop_dict = {}
with arcpy.da.SearchCursor(max_stops, fields) as cursor:
	for stop_id, stop_name, routes, zone, year in cursor:
		rail_stop_dict[stop_id] = (stop_id, stop_name, routes.strip(), zone, year)

with arcpy.da.UpdateCursor(final_isochrones, fields) as cursor:
	for stop_id, stop_name, routes, zone, year in cursor:
		cursor.updateRow(rail_stop_dict[stop_id])

# Add the area of the isochrones as an attribute, this will be used later to check for errors
f_name = 'area'
f_type = 'FLOAT'
arcpy.management.AddField(final_isochrones, f_name, f_type)

fields = ['SHAPE@AREA', 'area']
with arcpy.da.UpdateCursor(final_isochrones, fields) as cursor:
	for area_value, area_field in cursor:
		area_field = area_value
		cursor.updateRow((area_value, area_field))

# The timing module, which I found here: 
# http://stackoverflow.com/questions/1557571/how-to-get-time-of-a-python-program-execution/1557906#1557906
# keeps track of the run time of the script
timing.log('isochrones created')

# ran in 9:15 on 2/19/14