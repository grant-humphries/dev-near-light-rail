# Grant Humphries for TriMet, 2013-14
# ArcGIS Version:   10.2.2
# Python Version:   2.7.5
#--------------------------------

import os
import sys
import timing
import arcpy
from arcpy import env

# Check out the Network Analyst extension
arcpy.CheckOutExtension("Network")

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True

# This is the name of the data folder for the current iteration of the project that is being passed
# a parameter to the command prompt in the batch file trim_compare_property_generate_stats.bat.
data_folder = sys.argv[1]

# Set workspace, the user will be prompted to enter the name of the subfolder that data is to be
# written to for the current iteration
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/' + data_folder

# Trim regions covered by water bodies and natural areas (including parks) from properties, the area of 
# these taxlots will be used for normalization in statistics resultant from this project

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

timing.log('property trimmed')
# ran in 39:41 on 2/19/14