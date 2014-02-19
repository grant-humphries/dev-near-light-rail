# Grant Humphries for TriMet, 2013-14
# ArcGIS Version:   10.2.1
# Python Version:   2.7.5
#--------------------------------

import os
import re
import timing
import arcpy
from arcpy import env

# Check out the Network Analyst extension license
arcpy.CheckOutExtension("Network")

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True
# BE SURE TO UPDATE THIS FILE PATH TO THE NEW FOLDER EACH TIME A NEW ANALYSIS IS RUN!!!
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2014_02'

# Create a temp folder to hold intermediate datasets if it doesn't already exist
if not os.path.exists(os.path.join(env.workspace, 'temp')):
	os.makedirs(os.path.join(env.workspace, 'temp'))

# This dataset should be updated anytime there is a change to any of the MAX stops, such as when the 
# orange line is completed, grab the data from maps5 for most up-to-date product and ensure the schema
# matches what is being called upon in the script.  Also be sure that none of the stops are snapping to the
# sky bridges in downtown as this has been an issue in the past
max_stops = os.path.join(env.workspace, 'max_stops.shp')


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
new_stop_id = 50000

# Add orange line stops to max stops feature class
line_name = ':MAX Orange Line:'
i_fields = ['SHAPE@', 'id', 'routes']
i_cursor = arcpy.da.InsertCursor(max_stops, i_fields)

fields = ['OID@', 'SHAPE@']
with arcpy.da.SearchCursor(orange_stops, fields) as cursor:
	for oid, geom in cursor:
		# ensure existing trimet id's aren't being used
		while new_stop_id in id_list:
			new_stop_id += 1
		
		i_cursor.insertRow((geom, new_stop_id, line_name))
		id_list.append(new_stop_id)

del i_cursor


#-----------------------------------------------------------------------------------------------------

# These areas will be used to divide the stops into tabulation groups
max_zones = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/max_stop_zones.shp'

# Only a field called 'name' will be retained when locations are loaded into service area analysis as the
# MAXstops will be.  In that field I need unique identifiers so attributes from this data can be properly
# linked to the network analyst output

# Move the values in 'name' to a new field to preserve them, then overwrite the original with unique id
# from the (trimet) 'id' field
f_name = 'stop_name'
f_type = 'TEXT'
arcpy.AddField_management(max_stops, f_name, f_type)

fields = ['id', 'name', 'stop_name']
with arcpy.da.UpdateCursor(max_stops, fields) as cursor:
	for tm_id, name, stop_name in cursor:
		stop_name = name
		name = str(int(tm_id))
		cursor.updateRow((tm_id, name, stop_name))

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
# assigned. 
f_name = 'incpt_year'
f_type = 'SHORT'
arcpy.AddField_management(stops_with_zone, f_name, f_type)

# ***Note that stops within the CBD will not all have the same MAX year as stops within
# that region were not all built at the same time (which is not the case for all other MAX zones)***
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
select_type = 'NEW_SELECTION'
where_clause = """ "max_zone" = 'Central Business District' """
arcpy.SelectLayerByAttribute_management(max_stop_layer, select_type, where_clause)

cbd_max = 'in_memory/cbd_max'
arcpy.CopyFeatures_management(max_stop_layer, cbd_max)

# Now select all MAX that are not in the CBD
select_type = 'SWITCH_SELECTION'
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
geom_type = 'POLYGON'
epsg = arcpy.SpatialReference(2913)
arcpy.CreateFeatureclass_management(os.path.dirname(all_isocrones), os.path.basename(all_isocrones), 
									geom_type, spatial_reference=epsg)

# Add all fields that are needed in the new feature class, and drop the 'Id' field that is created
# by default when a new fc w/ no additional fields in created
field_names = ['tm_id', 'stop_id', 'routes', 'max_zone', 'incpt_year', 'walk_dist']
for f_name in field_names:
	if f_name in ('stop_id', 'incpt_year'):
		f_type = 'LONG'
	elif f_name in ('tm_id', 'routes', 'max_zone'):
		f_type = 'TEXT'
	elif f_name == 'walk_dist':
		f_type = 'DOUBLE'
	
	arcpy.AddField_management(all_isocrones, f_name, f_type)

drop_field = 'Id'
arcpy.DeleteField_management(all_isocrones, drop_field)

# create an insert cursor to populate the new feature class with the isocrones that will be generated
i_fields = ['SHAPE@', 'tm_id', 'walk_dist']
i_cursor = arcpy.da.InsertCursor(all_isocrones, i_fields) 

# Set static parameters for service area analysis (isocrone generation)
break_units = 'FEET'
osm_network = os.path.join(env.workspace, 'osm_foot_ND.nd')
permissions = 'foot_permissions'
exclude_restricted = 'EXCLUDE'
polygon_overlap = 'DISKS'
# polygon trim is critical this cuts out area of the polygons where no traversable features exist for at lease
# the given distance, 100 meters is the default and seems to work well
polygon_trim = '100 METERS'
polygon_simp = '5 FEET'

# This function creates isocrones for the input locations and adds them to a new feature class, each time 
# function is run the new isocrones are added to the same feature class
def generateIsocrones(locations, break_value, isocrones):
	arcpy.na.GenerateServiceAreas(locations, break_value, break_units, osm_network, isocrones,
									Restrictions=permissions, 
									Exclude_Restricted_Portions_of_the_Network=exclude_restricted,
									Polygon_Overlap_Type=polygon_overlap, Polygon_Trim_Distance=polygon_trim,
									Polygon_Simplification_Tolerance=polygon_simp)

	s_fields = ['SHAPE@', 'Name']
	with arcpy.da.SearchCursor(isocrones, s_fields) as cursor:
		for geom, output_name in cursor:
			tm_id = re.sub(' : 0 - ' + str(break_value) + '$', '', output_name)
			i_cursor.insertRow((geom, tm_id, break_value))


# Set variable parameters specific to each set of isocrones:
# For noew I'm using 3300 feet for the CBD walk limit, have experimented with using 2475' and 4125' and
# am still working with Alan Lehto to finalize this number
cbd_max_distance = 3300
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
fields = ['name', 'stop_id', 'routes', 'max_zone', 'incpt_year']
rail_stop_dict = {}
with arcpy.da.SearchCursor(stops_with_zone, fields) as cursor:
	for tm_id, stop_id, routes, zone, year in cursor:
		rail_stop_dict[tm_id] = (tm_id, stop_id, routes.strip(), zone, year)

# replace the first entry in fields with rail_stop, the others neccessarily stay the same
fields = ['tm_id', 'stop_id', 'routes', 'max_zone', 'incpt_year']
with arcpy.da.UpdateCursor(all_isocrones, fields) as cursor:
	for tm_id, stop_id, routes, zone, year in cursor:
		cursor.updateRow(rail_stop_dict[tm_id])

# The timing module, which I found here: 
# http://stackoverflow.com/questions/1557571/how-to-get-time-of-a-python-program-execution/1557906#1557906
# keeps track of the run time of the script
timing.log('Isocrones created')

#-----------------------------------------------------------------------------------------------------
# Trim regions covered by water bodies and natural areas (including parks) from properties, the area of 
# these taxlots will be used for normalization in statistics resultant from this project
print ''
print 'Beginning trimming of property data'

taxlots = '//gisstore/gis/RLIS/TAXLOTS/taxlots.shp'
multi_family = '//gisstore/gis/RLIS/LAND/multifamily_housing_inventory.shp'

water = '//gisstore/gis/RLIS/WATER/stm_fill.shp'
natural_areas = '//gisstore/gis/RLIS/LAND/orca.shp'

# Dissolve water and natural area features into a single geometry features
water_dissolve = 'in_memory/water_dissolve'
arcpy.Dissolve_management(water, water_dissolve)

nat_areas_dissolve = 'in_memory/water_and_nat_areas'
arcpy.Dissolve_management(natural_areas, nat_areas_dissolve)

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

# Assign feature class to more appropriately named variable now that it contains the geometry for both
# water and natural areas
water_and_nat_areas = nat_areas_dissolve

# Free up memory as this dataset is no longer needed
arcpy.Delete_management(water_dissolve)

# Erase merged water and parks late
habitable_taxlots = os.path.join(env.workspace, 'habitable_taxlots.shp')
arcpy.Erase_analysis(taxlots, water_and_nat_areas, habitable_taxlots)

habitable_multifam = os.path.join(env.workspace, 'habitable_multifam.shp')
arcpy.Erase_analysis(multi_family, water_and_nat_areas, habitable_multifam)

timing.endlog()