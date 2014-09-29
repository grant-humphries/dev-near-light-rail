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

# Set environment variables
env.overwriteOutput = True
env.addOutputsToMap = True

# Set workspace, the user will be prompted to enter the name of the subfolder that data is to be
# written to for the current iteration
project_folder = raw_input('Enter the name of the subfolder being used for this iteration of the project (should be in the form "YYYY_MM"): ')
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/'
data_workspace = os.path.join(env.workspace, 'data', project_folder)

# Assign project datasets to variables
max_stops = os.path.join(data_workspace, 'max_stops.shp')
max_zones = os.path.join(env.workspace, 'data', 'max_stop_zones.shp')
final_isochrones = os.path.join(data_workspace, 'max_stop_isochrones.shp')

# These variables will potentially be assigned values later by functions below
service_area_layer = None
sa_facilities = None
sa_isochrones = None

# Create a 'temp' folder to hold intermediate datasets
if not os.path.exists(os.path.join(data_workspace, 'temp')):
	os.makedirs(os.path.join(data_workspace, folder))

def addOrangeStops():
	"""Insert orange line stops, which are in the spatial dbs at this time, into the shapefile 
	containing all of the other MAX stops.  This function can be removed once the orange line stops
	are added stops tables on maps10"""

	orange_stops = os.path.join(env.workspace, 'data', 'projected_orange_line_stops.shp')

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
		fields = ['Shape@', 'stop_id', 'stop_name', 'routes', 'begin_date', 'end_date']
		i_cursor = arcpy.da.InsertCursor(max_stops, fields)

		with arcpy.da.SearchCursor(orange_stops, fields) as cursor:
			for geom, stop_id, name, routes, b_date, e_date in cursor:
				i_cursor.insertRow((geom, stop_id, name, routes, b_date, e_date))

		del i_cursor

def addNameField():
	"""Only a field called 'name' will be retained when locations are loaded into a service area 
	analysis, as the MAX stops will be.  This field is populated that field with unique identifiers
	so that the other attributes from this data can be linked to the network analyst output"""
	
	f_name = 'name'
	f_type = 'LONG'
	arcpy.management.AddField(max_stops, f_name, f_type)

	fields = ['stop_id', 'name']
	with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
		for stop_id, name in cursor:
			name = stop_id
			cursor.updateRow((stop_id, name))

def assignMaxZones():
	"""Add an attribute to max stops that indicates which 'MAX Zone' it falls within, the max_zone 
	feature class is used in conjunction with max stops to make this determination"""

	# Create a mapping from zone object id's to their names
	max_zone_dict = {}
	fields = ['OID@', 'name']
	with arcpy.da.SearchCursor(max_zones, fields) as cursor:
		for oid, name in cursor:
			max_zone_dict[oid] = name

	# Find the nearest zone to each stop
	stop_zone_n_table = os.path.join(data_workspace, 'temp/stop_zone_near_table.dbf')
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

def addInceptionYear():
	"""Each MAX line has a decision to build year, add that information as an attribute to the
	max stops.  If a max stop serves multiple lines the year from the oldest line will be assigned."""
	
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

# This function is not being used at this time as the same walk distance is being used for each stop
def createWalkGroups(zones, name, inverse=False):
	"""If different walk distances must be used in the creation of isochrones for different stops they
	must be generated by separate executions of the service area analysis. This function creates
	separate feature classes for those groups, the zones parameter must be a list"""

	# Create a feature layer so that selections can be made on the data
	max_stop_layer = 'max_stop_layer'
	arcpy.management.MakeFeatureLayer(max_stops, max_stop_layer)

	# Assign a variable that will determine if the output is the zones provide or all
	# of the zones that are not provided
	if inverse:
		negate = 'NOT'
	else:
		negate = ''

	zones_query = "'" + "', '".join(zones) + "'"
	select_type = 'NEW_SELECTION'
	where_clause = '"max_zone" ' + negate + ' IN (' + zones_query + ')'
	arcpy.management.SelectLayerByAttribute(max_stop_layer, select_type, where_clause)

	zone_stops = os.path.join(data_workspace, 'temp', name + '.shp')
	arcpy.management.CopyFeatures(max_stop_layer, zone_stops)

	return zone_stops

def createIsochroneFc():
	"""Create a new feature class to store all isochrones created later in the work flow"""

	geom_type = 'POLYGON'
	ore_state_plane_n = arcpy.SpatialReference(2913)
	arcpy.management.CreateFeatureclass(os.path.dirname(final_isochrones), 
		os.path.basename(final_isochrones), geom_type, spatial_reference=ore_state_plane_n)

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

def createServiceArea():
	"""Generate and configure a service area layer that will have the ability to make isochrones"""

	global service_area_layer, sa_facilities, sa_isochrones

	# Create and configure a service area layer
	osm_network = os.path.join(data_workspace, 'osm_foot_ND.nd')
	service_area_name = 'service_area_layer'
	impedance_attribute = 'Length'
	travel_from_to = 'TRAVEL_TO'
	permissions = 'foot_permissions'
	service_area_layer = arcpy.na.MakeServiceAreaLayer(osm_network, service_area_name, 
		impedance_attribute, travel_from_to, restriction_attribute_name=permissions).getOutput(0)

	# Within the service area layer there are several sub-layers where things are stored such as facilities,
	# polygons, and barriers.  Grab the facilities and polygons sublayers and assign them to variables
	sa_sublayer_dict = arcpy.na.GetNAClassNames(service_area_layer)

	sa_facilities = sa_sublayer_dict['Facilities']
	sa_isochrones = sa_sublayer_dict['SAPolygons']

def generateIsochrones(locations, break_value):
	"""Create walkshed polygons using the OpenStreetMap street and trail network from the input
	locations to the distance of the input break value"""

	if not service_area_layer:
		createServiceArea()

	# Set the break distance for this batch of stops
	solver_props = arcpy.na.GetSolverProperties(service_area_layer)
	solver_props.defaultBreaks = break_value

	# Add the stops to the service area (sub)layer
	exclude_for_snapping = 'EXCLUDE'
	clear_other_stops = 'CLEAR'
	# Service area locations must be stored in the facilities sublayer
	arcpy.na.AddLocations(service_area_layer, sa_facilities, locations, 
		append=clear_other_stops, exclude_restricted_elements=exclude_for_snapping)

	# Generate the isochrones for this batch of stops, the output will automatically go to the 
	# 'SAPolygons' sub layer of the service area layer which has been assigned to the variable
	# 'sa_isochrones'
	arcpy.na.Solve(service_area_layer)

	# create an insert cursor that writes to isochrone feature class
	i_fields = ['Shape@', 'stop_id', 'walk_dist']
	i_cursor = arcpy.da.InsertCursor(final_isochrones, i_fields) 

	# Grab the needed fields from the isochrones and write them to the feature class created to house
	# them.  The features will only be added if their stop_id is not in the final isochrones fc
	fields = ['Shape@', 'name']
	with arcpy.da.SearchCursor(sa_isochrones, fields) as cursor:
		for geom, output_name in cursor:
			iso_attributes = re.split(' : 0 - ', output_name)
			
			stop_id = int(iso_attributes[0])
			break_value = int(iso_attributes[1])

			i_cursor.insertRow((geom, stop_id, break_value))

	# clean up
	del i_cursor

def addIsoAttributes():
	"""Append attributes from the original max stops data to the isochrones feature class, 
	matching features stop id's field (which are in the 'stop_id' and 'name' fields"""
	
	fields = ['stop_id', 'stop_name', 'routes', 'max_zone', 'incpt_year']
	rail_stop_dict = {}
	with arcpy.da.SearchCursor(max_stops, fields) as cursor:
		for stop_id, stop_name, routes, zone, year in cursor:
			rail_stop_dict[stop_id] = (stop_id, stop_name, routes.strip(), zone, year)

	with arcpy.da.UpdateCursor(final_isochrones, fields) as cursor:
		for stop_id, stop_name, routes, zone, year in cursor:
			cursor.updateRow(rail_stop_dict[stop_id])

def getIsoArea():
	"""Add the area of the isochrones as an attribute, this will be used later to check for errors"""
	
	f_name = 'area'
	f_type = 'FLOAT'
	arcpy.management.AddField(final_isochrones, f_name, f_type)

	fields = ['SHAPE@AREA', 'area']
	with arcpy.da.UpdateCursor(final_isochrones, fields) as cursor:
		for area_value, area_field in cursor:
			area_field = area_value
			cursor.updateRow((area_value, area_field))

# Prep stop data
addOrangeStops()
addNameField()
assignMaxZones()
addInceptionYear()

# Prep for creation of walksheds
createIsochroneFc()

# Create service area layer and walksheds, walk distance is 2640 feet (0.5 miles), have experimented
# with using 2475', 3300' and 4125', but higher-ups seem firm with this number now
walk_distance = 2640
generateIsochrones(max_stops, walk_distance)

# Add additional attributes to the isochrones
addIsoAttributes()
getIsoArea()

# The timing module, which I found here: 
# http://stackoverflow.com/questions/1557571/how-to-get-time-of-a-python-program-execution/1557906#1557906
# keeps track of the run time of the script
timing.log('isochrones created')

# ran in 9:15 on 2/19/14