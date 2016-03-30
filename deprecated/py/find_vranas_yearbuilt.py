# Grant Humphries, 2013
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
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/old_methodology/old_vrana_data'

# This Ric Vrana's data that is a fork of the RLIS tax lot that he maintained manually
cbd = os.path.join(env.workspace, 'CBD2012.shp')
east_blue = os.path.join(env.workspace, 'EastBlue_2011.shp')
west_blue = os.path.join(env.workspace, 'WestBlueTLs_1104.shp')
green = os.path.join(env.workspace, 'Green205_2011.shp')
orange = os.path.join(env.workspace, 'OrangeTLs2012.shp')
red = os.path.join(env.workspace, 'NERed_2011.shp')
yellow = os.path.join(env.workspace, 'NorthYellow_2011.shp')

# This is current RLIS tax lot data
taxlots = '//gisstore/gis/Rlis/TAXLOTS/taxlots.shp'

tab_areas = [cbd, east_blue, west_blue, green, orange, red, yellow]

# grab all entries in Ric's data that have a year built vale that is not equal to zero and put them in a list
# along with their TLID
has_year_list = []
vrana_tlid_list = []
fields = ['TLID', 'YEARBUILT']
for tab_area in tab_areas:
	with arcpy.da.SearchCursor(tab_area, fields) as cursor:
		for tlid, year in cursor:
			if year != 0:
				has_year_list.append((tlid, year))

				vrana_tlid_list.append(tlid)

print 'Vrana data has been loaded'

# put all entries in the current RLIS data that do not have a yearbuilt value (i.e. = 0) and put their TLIDs in
# a list
no_year_list = []
rlis_tlid_list = []
with arcpy.da.SearchCursor(taxlots, fields) as cursor:
	for tlid, year in cursor:
		if year == 0:
			no_year_list.append(tlid)

		rlis_tlid_list.append(tlid)
		
print 'RLIS data has been loaded'

# This has been done once and does not need to be repeated as it is time consuming, see the CSV for the results
# # Verify that all TLIDs in Ric's data still exist in the current RLIS data
# with open(os.path.join(env.workspace, 'yearbuilt_analysis/vrana_unmatched_tlid.csv'), 'wb') as unmatched_tlids:
# 	csv_writer = csv.writer(unmatched_tlids)
	
# 	# add header to CSV, since there is only a single colums in this csv a string will be written with a column
# 	# for each character unless its in a tuple.  A tuple with only one entry must have a trailing comma
# 	header = ['TLID']
# 	csv_writer.writerow(header)
# 	for tlid in vrana_tlid_list:
# 		if tlid not in rlis_tlid_list:
# 			csv_writer.writerow([tlid])

# print 'Vrana TLIDs have been tested against RLIS TLIDs non-matches written to csv'

# Find all TLIDs that are given in Ric's data and missing in the current RLIS data and write them to a DBF
# For some reason the create table tool doesn't honor the overwrite outputs settings so I running this script
# again you'll need to either change the location of the output or delete the existing file
vrana_year_built = os.path.join(env.workspace, 'yearbuilt_analysis/vrana_year_built.dbf')
arcpy.CreateTable_management(os.path.dirname(vrana_year_built), os.path.basename(vrana_year_built))

new_fields = [('TLID', 'Text'), ('YEARBUILT', 'Short')]
for f_name, f_type in new_fields:
	arcpy.AddField_management(vrana_year_built, f_name, f_type)

drop_field = 'Field1'
arcpy.DeleteField_management(vrana_year_built, drop_field)

fields = [f_name for f_name, f_type in new_fields]
with arcpy.da.InsertCursor(vrana_year_built, fields) as i_cursor:
	for tlid, year in has_year_list:
		if tlid in no_year_list:
			i_cursor.insertRow((tlid, year))