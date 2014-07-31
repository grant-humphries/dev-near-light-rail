# Copyright: (c) Grant Humphries for TriMet, 2014
# ArcGIS Version:   10.2.2
# Python Version:   2.7.5
#--------------------------------

import os
import sys
import arcpy
from arcpy import env

# Configure environment settings

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data'
#env.outputCoordinateSystem = arcpy.SpatialReference(2913)

# Convert csv into feature layer (which is stored in memory)
orange_stop_csv = os.path.join(env.workspace, 'projected_orange_line_stops.csv')
x_field = 'X_COORD'
y_field = 'Y_COORD'
o_stop_layer = 'max_orange_stops'
spatial_reference = arcpy.SpatialReference(2913)
arcpy.management.MakeXYEventLayer(orange_stop_csv, x_field, y_field, o_stop_layer, spatial_reference)

# Save the feature layer to a feature class that is stored on the disk
o_stop_fc = os.path.join(env.workspace, 'projected_orange_line_stops.shp')
arcpy.conversion.FeatureClassToFeatureClass(o_stop_layer, 
	os.path.dirname(o_stop_fc), os.path.basename(o_stop_fc))