# Grant Humphries for TriMet, 2013-14
# ArcGIS Version:   10.2.1
# Python Version:   2.7.5
#--------------------------------

import os
import re
import timing
import arcpy
from arcpy import env

# Check out the Network Analyst extension
arcpy.CheckOutExtension("Network")

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True

# BE SURE TO UPDATE THIS FILE PATH TO THE NEW FOLDER EACH TIME A NEW ANALYSIS IS RUN!!!
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2014_02'

# Create a 'temp' folder to hold intermediate datasets, and a 'csv' folder to hold spreadsheet (later
# in the project) if they don't already exist
new_folders = ['temp', 'csv']
for folder in new_folders:
	if not os.path.exists(os.path.join(env.workspace, folder)):
		os.makedirs(os.path.join(env.workspace, folder))

# **NOTE:** This feature class is all trimet stops, not just MAX stops when it is initially added, 
# this will be corrected in the next step.  This shapefile is derived from the table current.stop_ext
# in the trimet database on the trimet.maps2.org.
max_stops = os.path.join(env.workspace, 'max_stops.shp')

# Erase all non-MAX stops from the transit stops data
fields = ['OID@', 'type']
with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
	for oid, stop_type in cursor:
		if int(stop_type) != 5:
			cursor.deleteRow()

# The 'lon' field is giving me trouble when I try to import this shapefile back into a PostGIS db
# I think this is because of the negative numbers, but I'm dropping the fields 'lon' and 'lat' to
# resolve this situation
drop_fields = ['lon', 'lat']
arcpy.management.DeleteField(max_stops, drop_fields)

#-----------------------------------------------------------------------------------------------------
# This section can be removed once the orange line stops are added to maps5

orange_stops = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/projected_orange_line_stops.shp'

# Make a list of all trimet id's that are assigned to stops in the max_stops dataset
id_list = []
fields = ['OID@', 'id']
with arcpy.da.SearchCursor(max_stops, fields) as cursor:
	for oid, data_id in cursor:
		id_list.append(data_id)

# Create a starting point for new trimet id's for the orange line stops.  There are currently no trimet id's
# over 20,000 so I'm starting at 50,000 to prevent conflict
new_max_id = 50000

# If the first new MAX is already in the max_stops table it means that the orange line stops have already been
# added to the max stops feature class and thus the clause below shouldn't be run 
if new_max_id not in id_list:
	# Add orange line stops to max stops feature class
	line_name = ':MAX Orange Line:'
	i_fields = ['SHAPE@', 'id', 'routes']
	i_cursor = arcpy.da.InsertCursor(max_stops, i_fields)

	fields = ['OID@', 'SHAPE@']
	with arcpy.da.SearchCursor(orange_stops, fields) as cursor:
		for oid, geom in cursor:
			# ensure existing trimet id's aren't being used
			while new_max_id in id_list:
				new_max_id += 1
			
			i_cursor.insertRow((geom, new_max_id, line_name))
			id_list.append(new_max_id)

	del i_cursor

#-----------------------------------------------------------------------------------------------------

# Only a field called 'name' will be retained when locations are loaded into service area analysis as the
# MAX stops will be.  In that field I need unique identifiers so attributes from this data can be properly
# linked to the network analyst output

# Move the values in 'name' to a new field to preserve them, then overwrite the original with unique id
# from the (trimet) 'id' field
f_name = 'stop_name'
max_stop_desc = arcpy.Describe(max_stops)
# if 'stop_name' field already exists that means this code block has already been run so skip
if f_name not in [field.name for field in max_stop_desc.fields]:
	f_type = 'TEXT'
	arcpy.management.AddField(max_stops, f_name, f_type)

	fields = ['id', 'name', 'stop_name']
	with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
		for tm_id, name, stop_name in cursor:
			stop_name = name
			name = str(int(tm_id))
			cursor.updateRow((tm_id, name, stop_name))


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

# ***Note that stops within the CBD will not all have the same MAX year as stops within
# that region were not all built at the same time (which is not the case for all other MAX zones)***
fields = ['routes', 'max_zone', 'incpt_year']
with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
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


# Create a new feature class to store all of the isocrones that will be created
final_isocrones = os.path.join(env.workspace, 'max_stop_isocrones.shp')
geom_type = 'POLYGON'
epsg = arcpy.SpatialReference(2913)
arcpy.management.CreateFeatureclass(os.path.dirname(final_isocrones), os.path.basename(final_isocrones), 
									geom_type, spatial_reference=epsg)

# Add all fields that are needed in the new feature class, and drop the 'Id' field that exists
# by default
field_names = ['tm_id', 'stop_id', 'routes', 'max_zone', 'incpt_year', 'walk_dist']
for f_name in field_names:
	if f_name in ('stop_id', 'incpt_year'):
		f_type = 'LONG'
	elif f_name in ('tm_id', 'routes', 'max_zone'):
		f_type = 'TEXT'
	elif f_name == 'walk_dist':
		f_type = 'DOUBLE'
	
	arcpy.management.AddField(final_isocrones, f_name, f_type)

drop_field = 'Id'
arcpy.management.DeleteField(final_isocrones, drop_field)

# create an insert cursor to populate the new feature class
i_fields = ['SHAPE@', 'tm_id', 'walk_dist']
i_cursor = arcpy.da.InsertCursor(final_isocrones, i_fields) 

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
sa_isocrones = sa_sublayer_dict['SAPolygons']

# Used to keep track of the isocrones that have been added to the new feature class
tm_id_list = []

def generateIsocrones(locations, break_value):
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

	# Generate the isocrones for this batch of stops, the output will automatically go to the 
	# 'SAPolygons' sub layer of the service area layer which has been assigned to the variable
	# 'sa_isocrones'
	arcpy.na.Solve(service_area_layer)

	# Grab the needed fields from the isocrones and write them to the feature class created to house
	# them.  The features will only be added if their tm_id is not in the final isocrones fc
	fields = ['SHAPE@', 'Name']
	with arcpy.da.SearchCursor(sa_isocrones, fields) as cursor:
		for geom, output_name in cursor:
			iso_attributes = re.split(' : 0 - ', output_name)
			
			tm_id = iso_attributes[0]
			break_value = int(iso_attributes[1])

			if tm_id not in tm_id_list:
				i_cursor.insertRow((geom, tm_id, break_value))
				tm_id_list.append(tm_id)

# Set parameters specific to each set of isocrones:
# For now I'm using 3300 feet for the CBD walk limit, have experimented with using 2475' and 4125' and
# am still working with Alan Lehto to finalize this number
cbd_max_distance = 3300
generateIsocrones(cbd_max, cbd_max_distance)

# 0.5 miles * 1.25
outer_max_distance = 3300
generateIsocrones(outer_max, outer_max_distance)

# Cursor should be discarded now that it is no longer needed (can cause execution problems if not done)
del i_cursor

# Get value attributes from the original max stops data and add it to the new isocrones feature class, 
# matching corresponding features.  Recall that the tm_id field has been copied to 'name' field and 
# casted to string
fields = ['name', 'stop_id', 'routes', 'max_zone', 'incpt_year']
rail_stop_dict = {}
with arcpy.da.SearchCursor(max_stops, fields) as cursor:
	for tm_id, stop_id, routes, zone, year in cursor:
		rail_stop_dict[tm_id] = (tm_id, stop_id, routes.strip(), zone, year)

fields = ['tm_id', 'stop_id', 'routes', 'max_zone', 'incpt_year']
with arcpy.da.UpdateCursor(final_isocrones, fields) as cursor:
	for tm_id, stop_id, routes, zone, year in cursor:
		cursor.updateRow(rail_stop_dict[tm_id])

# The timing module, which I found here: 
# http://stackoverflow.com/questions/1557571/how-to-get-time-of-a-python-program-execution/1557906#1557906
# keeps track of the run time of the script
timing.log('Isocrones created')

# ran in 9:15 on 2/19/14

#-----------------------------------------------------------------------------------------------------
# Trim regions covered by water bodies and natural areas (including parks) from properties, the area of 
# these taxlots will be used for normalization in statistics resultant from this project

timing.log('Property trimming beginning')

taxlots = '//gisstore/gis/RLIS/TAXLOTS/taxlots.shp'
multi_family = '//gisstore/gis/RLIS/LAND/multifamily_housing_inventory.shp'

water = '//gisstore/gis/RLIS/WATER/stm_fill.shp'
natural_areas = '//gisstore/gis/RLIS/LAND/orca.shp'

# Dissolve water and natural area feature classes into a single geometry for each group
water_dissolve = os.path.join(env.workspace, 'temp/water_dissolve.shp')
arcpy.management.Dissolve(water, water_dissolve)

nat_areas_dissolve = os.path.join(env.workspace, 'temp/water_and_nat_areas.shp')
arcpy.management.Dissolve(natural_areas, nat_areas_dissolve)

# Grab the dissolved water geometry feature
fields = ['OID@', 'SHAPE@']
with arcpy.da.SearchCursor(water_dissolve, fields) as cursor:
	for oid, geom in cursor:
		water_geom = geom

# Union the natural area and water features into a single geometry
with arcpy.da.UpdateCursor(nat_areas_dissolve, fields) as cursor:
	for oid, geom in cursor:
		geom = geom.union(water_geom)
		cursor.updateRow((oid, geom))

# Assign the parks/water feature class to more appropriately named variable
water_and_nat_areas = nat_areas_dissolve

# Erase merged parks/water features from property data
# Consider try multi-processing for this step at some point as it is very computationally intensive:
# http://blogs.esri.com/esri/arcgis/2011/08/29/multiprocessing/
trimmed_taxlots = os.path.join(env.workspace, 'trimmed_taxlots.shp')
arcpy.analysis.Erase(taxlots, water_and_nat_areas, trimmed_taxlots)

trimmed_multifam = os.path.join(env.workspace, 'trimmed_multifam.shp')
arcpy.analysis.Erase(multi_family, water_and_nat_areas, trimmed_multifam)

timing.endlog()
# second phase ran in 39:41 on 2/19/14