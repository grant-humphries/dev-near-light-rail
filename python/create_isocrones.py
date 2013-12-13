# Copyright: (c) Grant Humphries for TriMet, 2013
# ArcGIS Version:   10.2
# Python Version:   2.7.3
#--------------------------------

import os
import re
import arcpy
from arcpy import env

# Check out the Network Analyst extension license
arcpy.CheckOutExtension("Network")

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data'

# Create a temp folder to hold intermediate datasets if it doesn't already exist
if not os.path.exists(os.path.join(env.workspace, 'temp')):
	os.makedirs(os.path.join(env.workspace, 'temp'))

# This dataset should be updated anytime there is a change to any of the MAX stops, such as when the 
# orange line is completed, grab the data from maps5 for most up-to-date product and ensure the schema
# matches what is being called upon in the script.  Also be sure that none of the stops are snapping to the
# sky bridges in downtown as this has been an issue in the past
max_stops = os.path.join(env.workspace, 'max_stops/max_stops_2013_12.shp')


# This section can be removed once the orange line stops are added to maps5
#-----------------------------------------------------------------------------------------------------
orange_stops = os.path.join(env.workspace, 'max_stops/projected_orange_line_stops.shp')

# there are currently no 6 digit stop id's so I'm starting at 100,000 to ensure these will be unique
new_stop_id = 100000

# make sure that these stops haven't already been added to main dataset
id_list = []
fields = ['OID@', 'id']
with arcpy.da.SearchCursor(max_stops, fields) as cursor:
	for oid, data_id in cursor:
		id_list.append(data_id)

# if they haven't add them
if new_stop_id not in id_list:
	line_name = ':MAX Orange Line:'
	i_fields = ['Shape@', 'id', 'routes']
	i_cursor = arcpy.da.InsertCursor(max_stops, i_fields)

	fields = ['OID@', 'Shape@']
	with arcpy.da.SearchCursor(orange_stops, fields) as cursor:
		for oid, geom in cursor:
			i_cursor.insertRow((geom, new_stop_id, line_name))
			new_stop_id += 1

	del i_cursor

#-----------------------------------------------------------------------------------------------------


# These areas will be used to divide the stops into tabulation groups
max_zones = os.path.join(env.workspace, 'max_stop_zones.shp')

# The field 'Name' must be added because only a field of this name will be retained when locations
# are loaded into service area analysis.  I need to field (unique identifier) that will allow me to 
# link the other attributes of this data to the network analyst output
rs_desc = arcpy.Describe(max_stops)
f_name = 'Name'
if f_name.lower() not in [field.name.lower() for field in rs_desc.fields]:
	f_type = 'Text'
	arcpy.AddField_management(max_stops, f_name, f_type)

	# Am using OID here instead of 'STATION' because there are some duplicates in station names
	fields = ['id', 'Name']
	with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
		for data_id, name in cursor:
			name = str(int(data_id))
			cursor.updateRow((data_id, name))


# An attribute needs to be added to the max stops layer that indicates which 'MAX zone' it falls within.
# This will be done with a spatial join, but in order to properly add a field that will contain that
# information a field mapping must be set up.

# Create a Field Mapp*ings* object and add all fields from the max stops fc
join_field_mappings = arcpy.FieldMappings()
join_field_mappings.addTable(max_stops)

# Create a Field Map object and load the 'name' field from the max zones fc 
mz_map_field = 'name'
zone_field_map = arcpy.FieldMap()
zone_field_map.addInputField(max_zones, mz_map_field)

# Get the output field's properties as a field object
zone_field = zone_field_map.outputField
 
# Rename the field and pass the updated field object back into the field map
zone_field.name = 'max_zone'
zone_field.aliasName = 'max_zone'
zone_field_map.outputField = zone_field

# Add the field map to the field mappings
join_field_mappings.addFieldMap(zone_field_map)

# Determine the max zone that each max stop lies within
stops_with_zone = os.path.join(env.workspace, 'temp/max_stops_with_zone.shp')
arcpy.SpatialJoin_analysis(max_stops, max_zones, stops_with_zone, field_mapping=join_field_mappings)


# Each MAX line has a decision to build year associated with it and that information needs to be
# transferred to the stops.  If a MAX stop serves multiple lines year from the oldest line will be 
# assigned
f_name = 'incpt_year'
f_type = 'Short'
arcpy.AddField_management(stops_with_zone, f_name, f_type)

fields = ['routes', 'max_zone', 'incpt_year']
with arcpy.da.UpdateCursor(stops_with_zone, fields) as cursor:
	for routes, zone, year in cursor:
		if ':MAX Blue Line:' in routes and zone not in ('West Suburbs', 'Southwest Portland'):
			year = 1980
		elif ':MAX Blue Line:' in routes and zone in ('West Suburbs', 'Southwest Portland'):
			year = 1990
		elif ':MAX Red Line:' in routes:
			year = 1997
		elif ':MAX Yellow Line:' in routes:
			year = 1999
		elif any(line in routes for line in (':MAX Green Line:', ':MAX Orange Line:')):
			year = 2003

		cursor.updateRow((routes, zone, year))

# Create a feature layer so that selections can be made on the data
max_stop_layer = 'max_stop_layer'
arcpy.MakeFeatureLayer_management(stops_with_zone, max_stop_layer)

# Select only MAX in the CBD
select_type = 'New_Selection'
where_clause = """ "max_zone" = 'Central Business District' """
arcpy.SelectLayerByAttribute_management(max_stop_layer, select_type, where_clause)

cbd_max = 'in_memory/cbd_max'
arcpy.CopyFeatures_management(max_stop_layer, cbd_max)

# Now select all MAX that are not in the CBD
select_type = 'Switch_Selection'
arcpy.SelectLayerByAttribute_management(max_stop_layer, select_type)

outer_max = 'in_memory/outer_max'
arcpy.CopyFeatures_management(max_stop_layer, outer_max)

# All of the groups created above will be start points in a service area analysis (seeds for isocrones), 
# but in order to be loaded into service area tool they must be in the form of an object called a Feature Set
cbd_max_set = arcpy.FeatureSet()
cbd_max_set.load(cbd_max)

outer_max_set = arcpy.FeatureSet()
outer_max_set.load(outer_max)

# Create a new feature class to store all of the isochrones that will be created
all_isocrones = os.path.join(env.workspace, 'rail_stop_isocrones.shp')
geom_type = 'Polygon'
epsg = arcpy.SpatialReference(2913)
arcpy.CreateFeatureclass_management(os.path.dirname(all_isocrones), os.path.basename(all_isocrones), 
									geom_type, spatial_reference=epsg)

# Add all fields that are needed in the new feature class, and drop the 'Id' field that is created
# by default when a new fc w/ no additional fields in created
field_names = ['origin_id', 'stop_id', 'routes', 'max_zone', 'incpt_year', 'walk_dist']
for f_name in field_names:
	f_type = 'Text'
	arcpy.AddField_management(all_isocrones, f_name, f_type)

drop_field = 'Id'
arcpy.DeleteField_management(all_isocrones, drop_field)

# create an insert cursor to populate the new feature class with the isocrones that will be generated
i_fields = ['Shape@', 'origin_id', 'walk_dist']
i_cursor = arcpy.da.InsertCursor(all_isocrones, i_fields) 

# Set static parameters for service area analysis (isocrone generation)
break_units = 'Feet'
osm_network = os.path.join(env.workspace, 'osm_foot_10_2013_ND.nd')
permissions = 'foot_permissions'
exclude_restricted = 'Exclude'
polygon_overlap = 'Disks'
# polygon trim is critical this cuts out area of the polygons where no traversable features exist for at lease
# the given distance, 100 meters is the default and seems to work well
polygon_trim = '100 Meters'
polygon_simp = '5 Feet'

# This function creates isocrones for the input locations and adds them to a new feature class, each time 
# function is run the new isocrones are added to the same feature class
def generateIsocrones(locations, break_value, isocrones):
	arcpy.na.GenerateServiceAreas(locations, break_value, break_units, osm_network, isocrones,
									Restrictions=permissions, 
									Exclude_Restricted_Portions_of_the_Network=exclude_restricted,
									Polygon_Overlap_Type=polygon_overlap, Polygon_Trim_Distance=polygon_trim,
									Polygon_Simplification_Tolerance=polygon_simp)

	s_fields = ['Shape@', 'Name']
	with arcpy.da.SearchCursor(isocrones, s_fields) as cursor:
		for geom, output_name in cursor:
			origin_id = re.sub(' : 0 - ' + str(break_value) + '$', '', output_name)
			i_cursor.insertRow((geom, origin_id, break_value))


# Set variable parameters specific to each set of isocrones:
# These first walk shed isocrones that are created will have walk distance of 1650 feet, that a 1/4 which
# is what was traditionally used plus 25%, that extra twenty five percent is to account for the fact that this
# new method is more circuitous
cbd_max_distance = 2475
cbd_max_isos = 'in_memory/cbd_max_service_area'
generateIsocrones(cbd_max_set, cbd_max_distance, cbd_max_isos)

# 0.5 miles * 1.25
outer_max_distance = 3300
outer_max_isos = 'in_memory/outer_max_service_area'
generateIsocrones(outer_max_set, outer_max_distance, outer_max_isos)

# after this cursor is deleted the generateIsocrones function will not longer work properly, thus all 
# calls must be made before this
del i_cursor

# Get value attributes from the original rail stops data set and add it to the new isocrones
# feature class, matching corresponding features
fields = ['id', 'stop_id', 'routes', 'max_zone', 'incpt_year']
rail_stop_dict = {}
with arcpy.da.SearchCursor(stops_with_zone, fields) as cursor:
	for origin_id, stop_id, routes, zone, year in cursor:
		rail_stop_dict[str(int(origin_id))] = (str(int(origin_id)), stop_id, routes, zone, year)

# replace the first entry in fields with rail_stop, the others neccessarily stay the same
fields = ['origin_id', 'stop_id', 'routes', 'max_zone', 'incpt_year']
with arcpy.da.UpdateCursor(all_isocrones, fields) as cursor:
	for origin_id, stop_id, routes, zone, year in cursor:
		cursor.updateRow(rail_stop_dict[str(origin_id)])