# Copyright: (c) Grant Humphries for TriMet, 2013
# ArcGIS Version:   10.2
# Python Version:   2.7.3
#--------------------------------

import os
import csv
import arcpy
from arcpy import env

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True
# BE SURE TO UPDATE THIS FILE PATH TO THE NEW FOLDER EACH TIME A NEW ANALYSIS IS RUN!!!
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2013_12'

# creates a 'temp' to store temporary project output if it doesn't already exist
if not os.path.exists(os.path.join(env.workspace, 'temp')):
	os.makedirs(os.path.join(env.workspace, 'temp'))

# Add project data
isocrones = os.path.join(env.workspace, 'rail_stop_isocrones.shp')
taxlots = '//gisstore/gis/RLIS/TAXLOTS/taxlots.shp'
multi_family = '//gisstore/gis/RLIS/LAND/multifamily_housing_inventory.shp'

# Taxlots will need to be selected based on their location relative to isocrones, the attributes of the
# isocrones that they fall within, and their own attributes, thus a spatial join will be performed
# so that all of the pertainent information will be contained within a single dataset
def mergeTaxlotsIsocrones(tl_data, name, dissolve_fields):
	taxlot_iso_join = os.path.join(env.workspace, 'temp/' + name + '_iso_join.shp')
	join_operation = 'Join_One_to_Many'
	join_type = 'Keep_Common'
	arcpy.SpatialJoin_analysis(tl_data, isocrones, taxlot_iso_join, join_operation, join_type)

	taxlot_iso_dissolve = os.path.join(env.workspace, 'temp/' + name + '_iso_dissolve.shp')
	dissolve_fields.append('max_zone')
	stats_fields = [['incpt_year', 'MIN']]
	part_type = 'Single_Part'
	arcpy.Dissolve_management(taxlot_iso_join, taxlot_iso_dissolve, dissolve_fields, stats_fields, 
								part_type)

	# now remove any taxlots that have yearbuilt date before the inception year of the MAX stop
	# isocrone that has been joined to it as this construction wasn't influenced by MAX development
	compare_fields = ['YEARBUILT', 'MIN_incpt_']
	with arcpy.da.UpdateCursor(taxlot_iso_dissolve, compare_fields) as cursor:
		for build_year, max_year in cursor:
			if build_year > max_year


	return taxlot_iso_dissolve

# Run function for taxlot data, attributes that are to be retained must be included in the dissolve
# field list
tl_name = 'taxlot'
tl_dissolve_fields = ['TLID', 'SITEADDR', 'SITECITY', 'SITEZIP', 'LANDVAL', 'BLDGVAL', 'TOTALVAL', 
						'BLDGSQFT', 'YEARBUILT', 'PROP_CODE', 'LANDUSE', 'SALEDATE', 'SALEPRICE', 'COUNTY']
tl_iso_merge = mergeTaxlotsIsocrones(taxlots, tl_name, tl_dissolve_fields)

# Now run the function for multi-familty housing data
mf_name = 'multifam'
mf_dissolve_fields = ['ADDRESS', 'MAIL_CITY', 'UNITS', 'ZIPCODE', 'UNIT_TYPE', 'COUNTY', 'MIXED_USE',
						 'YEARBUILT', 'COMMONNAME', 'DATASOURCE', 'CONFIDENCE', 'METRO_ID']
mf_iso_merge = mergeTaxlotsIsocrones(multi_family, mf_name, mf_dissolve_fields)

# Create feature layers so that selections can be made on all of these layers
taxlot_layer = 'taxlot_layer'
arcpy.MakeFeatureLayer_management(tl_iso_merge, taxlot_layer)
multifam_layer = 'multi_family_layer'
arcpy.MakeFeatureLayer_management(mf_iso_merge, multifam_layer)
isocrones_layer = 'isocrones_layer'
arcpy.MakeFeatureLayer_management(isocrones, isocrones_layer)

# Create a list that will hold the taxlots stats and add a header to it:
stats_list = []
header_tuple = ('group', 'total taxlot value', 'multi-family units')
stats_list.append(header_tuple)

# These will hold the various subset DBFs that are created
taxlot_select_list = []
multifam_select_list = []

def selectTaxlots(group_name, where_clause):
	# Select the group of station areas to be used
	select_type = 'New_Selection'
	final_wc = """ "YEARBUILT" >= "MIN_incpt_" AND """ + 
	arcpy.SelectLayerByAttribute_management(taxlot_layer, select_type, where_clause)

	taxlot_select = os.path.join(env.workspace, 'temp/' + group_name + '_tl.shp')
	arcpy.CopyFeatures_management(taxlot_layer, taxlot_select)

	# The taxlots in the central business district are considered separately from those elsewhere, so they must be
	# separated out.  The previous selection was saved out as shapefile because it will be used as a part of a
	# tabulation of a system wide total and I needed to lock in this state for the switch selection that's upcoming
	# to work as I intend
	tl_select_layer = 'taxlot_select_layer'
	arcpy.MakeFeatureLayer_management(taxlot_select, tl_select_layer)

	# the only way I've found to select features that are *not* within a given area is to select those that are within
	# it and then switch the selection
	overlap_type = 'Intersect'
	s_type = 'New_Selection'
	arcpy.SelectLayerByLocation_management(tl_select_layer, overlap_type, biz_dist_layer, selection_type=s_type)

	select_type = 'Switch_Selection'
	arcpy.SelectLayerByAttribute_management(tl_select_layer, select_type)

	tl_select_non_cdb = os.path.join(env.workspace, 'temp/' + group_name + '_tl_non_cbd.shp')
	arcpy.CopyFeatures_management(tl_select_layer, tl_select_non_cdb)

	# sum the all entries of 'totalvalue' in the taxlot non-cbd layer
	fields = ['OID@', 'TOTALVAL']
	value_sum = 0
	with arcpy.da.SearchCursor(tl_select_non_cdb, fields) as cursor:
		for oid, value in cursor:
			value_sum += value

	# Now do the same thing for the multi-family layer that was just done to the taxlot layer
	overlap_type = 'Intersect'
	s_type = 'New_Selection'
	arcpy.SelectLayerByLocation_management(multifam_layer, overlap_type, isocrones_layer, selection_type=s_type)

	select_type = 'Subset_Selection'
	year_wc = ' "YEARBUILT" >= ' + str(line_year)
	arcpy.SelectLayerByAttribute_management(multifam_layer, select_type, year_wc)

	multifam_select = os.path.join(env.workspace, 'temp/' + group_name + '_mf.shp')
	arcpy.CopyFeatures_management(multifam_layer, multifam_select)

	mf_select_layer = 'multifam_select_layer'
	arcpy.MakeFeatureLayer_management(multifam_select, mf_select_layer)

	# select and copy out only the remaining multi_family complexes that are *not* in the central business district
	overlap_type = 'Intersect'
	s_type = 'New_Selection'
	arcpy.SelectLayerByLocation_management(mf_select_layer, overlap_type, biz_dist_layer, selection_type=s_type)

	select_type = 'Switch_Selection'
	arcpy.SelectLayerByAttribute_management(mf_select_layer, select_type)

	mf_select_non_cdb = os.path.join(env.workspace, 'temp/' + group_name + '_mf_non_cbd.shp')
	arcpy.CopyFeatures_management(mf_select_layer, mf_select_non_cdb)

	# sum the all entries of 'units' in the multi-family non-cbd layer
	fields = ['OID@', 'UNITS']
	units_sum = 0
	with arcpy.da.SearchCursor(mf_select_non_cdb, fields) as cursor:
		for oid, units in cursor:
			units_sum += units

	stats_list.append((group_name, value_sum, units_sum))

	# These will be used later to calculate the value for all MAX lines for the whole region as well as for
	# all line in the central business district only
	taxlot_select_list.append(taxlot_select)
	multifam_select_list.append(multifam_select)

# Blue Line
blue_name = 'blue_orig'
blue_year = 1980 # the blue line has two decision to build years 1980 for the inital line and 1990 for the 
# westside extension, I'll need to distinguish between the two with an attribute
blue_wc = """ "line" LIKE '%B%' AND "station" NOT IN ('Beaverton Central', 'Beaverton Creek', 'Beaverton TC', 
														'Elmonica/SW 170th Ave', 'Fairplex/Hillsboro Airport', 
														'Goose Hollow/SW Jefferson St', 'Hatfield Government Center', 
														'Hawthorn Farm', 'Hillsboro Central/SE 3rd TC', 'JELD-WEN Field', 
														'Kings Hill/SW Salmon St', 'Merlo Rd/SW 158th Ave', 'Millikan Way', 
														'Orenco/NW 231st Ave', 'Quatama/NW 205th Ave', 'Sunset TC', 
														'Tuality Hospital/SE 8th Ave', 'Washington Park', 
														'Washington/SE 12th Ave', 'Willow Creek/SW 185th Ave TC') """
selectTaxlots(blue_name, blue_year, blue_wc)

# Blue westside extension
blue_x_name = 'blue_ext'
blue_x_year = 1990
blue_x_wc = """ "line" LIKE '%B%' AND "station" IN ('Beaverton Central', 'Beaverton Creek', 'Beaverton TC', 
													'Elmonica/SW 170th Ave', 'Fairplex/Hillsboro Airport', 
													'Goose Hollow/SW Jefferson St', 'Hatfield Government Center', 
													'Hawthorn Farm', 'Hillsboro Central/SE 3rd TC', 'JELD-WEN Field', 
													'Kings Hill/SW Salmon St', 'Merlo Rd/SW 158th Ave', 'Millikan Way', 
													'Orenco/NW 231st Ave', 'Quatama/NW 205th Ave', 'Sunset TC', 
													'Tuality Hospital/SE 8th Ave', 'Washington Park', 
													'Washington/SE 12th Ave', 'Willow Creek/SW 185th Ave TC') """
selectTaxlots(blue_x_name, blue_x_year, blue_x_wc)

# Green Line
green_name = 'green'
green_year = 2003
green_wc = """ "line" LIKE '%G%' """
selectTaxlots(green_name, green_year, green_wc)

# Red Line
red_name = 'red'
red_year = 1997
red_wc = """ "line" LIKE '%R%' AND "line" <> 'PMLR' """
selectTaxlots(red_name, red_year, red_wc)

# Orange Line
orange_name = 'orange'
orange_year = 2003
orange_wc = """ "line" = 'PMLR' """
selectTaxlots(orange_name, orange_year, orange_wc)

# Yellow Line
yellow_name = 'yellow'
yellow_year = 1999
yellow_wc = """ "line" LIKE '%Y%' """
selectTaxlots(yellow_name, yellow_year, yellow_wc)

# Now get the total value and units for all MAX station area with no double counting
def sumStationAreas(land_data_array, land_fields, land_unit_type, id_index, count_field):
	# Create a new dataset with the same schema as the template input
	all_stations = os.path.join(env.workspace, 'all_' + land_unit_type + '.shp')
	geom_type = 'Polygon'
	sr = arcpy.SpatialReference(2913)
	arcpy.CreateFeatureclass_management(os.path.dirname(all_stations), os.path.basename(all_stations), 
										geom_type, spatial_reference=sr)

	# Get the type of each field to be added from the existing land unit data, any of the datasets in the array
	# can be used for this.  Then add each of those fields to the newly created feature class
	data_desc = arcpy.Describe(land_data_array[0])
	f_type_dict = {}
	for field in data_desc.fields:
		f_type_dict[field.name] = field.type

	for field_name in land_fields:
		if field_name not in ('Shape@', 'OID@'):
			field_type = f_type_dict[field_name]
			arcpy.AddField_management(all_stations, field_name, field_type)

	# Create an insert cursor that will insert rows into the newly created feature class
	i_cursor = arcpy.da.InsertCursor(all_stations, land_fields)

	# Now insert only unique entries from the subsets of the taxlot layers created earlier into the new feature class
	id_list = []
	for land_data in land_data_array:
		with arcpy.da.SearchCursor(land_data, land_fields) as s_cursor:
			for row in s_cursor:
				if row[id_index] not in id_list:
					i_cursor.insertRow(row)
					id_list.append(row[id_index])
	
	del i_cursor

	# sum the count field for all entries 
	field_sum = 0
	search_fields = ['OID@', count_field]
	with arcpy.da.SearchCursor(all_stations, search_fields) as cursor:
		for oid, c_field in cursor:
			field_sum += c_field

	# create a feature layer for all stations
	all_stations_layer = 'all_stations_layer'
	arcpy.MakeFeatureLayer_management(all_stations, all_stations_layer)

	# select features within the central business district and copy them out and sum the count field
	overlap_type = 'Intersect'
	s_type = 'New_Selection'
	arcpy.SelectLayerByLocation_management(all_stations_layer, overlap_type, biz_dist_layer, selection_type=s_type)

	cbd_all_lines = os.path.join(env.workspace, 'temp/' + land_unit_type + '_cbd.shp')
	arcpy.CopyFeatures_management(all_stations_layer, cbd_all_lines)

	field_sum_cbd = 0
	search_fields = ['OID@', count_field]
	with arcpy.da.SearchCursor(cbd_all_lines, search_fields) as cursor:
		for oid, c_field in cursor:
			field_sum_cbd += c_field

	return [field_sum, field_sum_cbd]

tl_name = 'taxlot'
tl_fields = ['Shape@', 'TLID', 'TOTALVAL', 'YEARBUILT', 'PROP_CODE', 'LANDUSE']
tl_id_index = 1 # unique id is 'TLID'
tl_count_field = 'TOTALVAL'
all_max_value = sumStationAreas(taxlot_select_list, tl_fields, tl_name, tl_id_index, tl_count_field)

mf_name = 'multi_family'
mf_fields = ['Shape@', 'UNITS', 'YEARBUILT', 'METRO_ID']
mf_id_index = 3 # unique id is 'METRO_ID'
mf_count_field = 'UNITS'
all_max_units = sumStationAreas(multifam_select_list, mf_fields, mf_name, mf_id_index, mf_count_field)

# add all max stats to list
stats_list.append(('all MAX', all_max_value[0], all_max_units[0]))
# add CBD stats to the lsit
tats_list.append(('CBD only', all_max_value[1], all_max_units[1]))

# Now write the stats that have been collected to a csv file
with open(os.path.join(env.workspace, 'csv/development_stats.csv'), 'wb') as dev_stats:
	csv_writer = csv.writer(dev_stats)
	for entry in stats_list:
		csv_writer.writerow(entry)