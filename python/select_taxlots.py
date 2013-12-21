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
def mergeTaxlotsIsocrones(tl_data, name, dissolve_fields, unique_id, accrual_unit):
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
		for build_year, incept_year in cursor:
			if build_year < incept_year:
				cursor.deleteRow()

	id_list = []
	zone_dict = {'total': 0}
	fields = [unique_id, 'max_zone', accrual_unit]
	with arcpy.da.SearchCursor(taxlot_iso_dissolve, ) as cursor:
		for uid, zone, unit in cursor:
			if zone not in zone_dict:
				zone_dict[zone] = unit
			else:
				zone_dict[zone] += unit

			if uid not in id_list:
				zone_dict['total'] += unit
				id_list.append(uid)

	return zone_dict

# Run function for taxlot data, attributes that are to be retained must be included in the dissolve
# field list, running this function on the taxlots file takes about 11 minutes because it is very
# large file, but things should speed up thereafter
tl_name = 'taxlot'
tl_dissolve_fields = ['TLID', 'SITEADDR', 'SITECITY', 'SITEZIP', 'LANDVAL', 'BLDGVAL', 'TOTALVAL', 
						'BLDGSQFT', 'YEARBUILT', 'PROP_CODE', 'LANDUSE', 'SALEDATE', 'SALEPRICE', 'COUNTY']
tl_id = 'TLID'
tl_unit = 'TOTALVAL'
tl_stats = mergeTaxlotsIsocrones(taxlots, tl_name, tl_dissolve_fields, tl_id, tl_unit)

# Now run the function for multi-familty housing data
mf_name = 'multifam'
mf_dissolve_fields = ['ADDRESS', 'MAIL_CITY', 'UNITS', 'ZIPCODE', 'UNIT_TYPE', 'COUNTY', 'MIXED_USE',
						 'YEARBUILT', 'COMMONNAME', 'DATASOURCE', 'CONFIDENCE', 'METRO_ID']
mf_id = 'METRO_ID'
mf_unit = 'UNITS'
mf_stats = mergeTaxlotsIsocrones(multi_family, mf_name, mf_dissolve_fields, mf_id, mf_unit)

for key in 


# Create a list that will hold the taxlots stats and add a header to it:
stats_list = []
header_tuple = ('group', 'total taxlot value', 'multi-family units')
stats_list.append(header_tuple)




# Now write the stats that have been collected to a csv file
with open(os.path.join(env.workspace, 'csv/development_stats.csv'), 'wb') as dev_stats:
	csv_writer = csv.writer(dev_stats)
	for entry in stats_list:
		csv_writer.writerow(entry)