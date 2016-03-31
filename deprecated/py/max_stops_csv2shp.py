# Grant Humphries, 2014
# ArcGIS Version:   10.2.2
# Python Version:   2.7.5
#--------------------------------

import os
import sys
import csv
import arcpy
from arcpy import env

# Configure environment settings
env.overwriteOutput = True
env.addOutputsToMap = False
env.workspace = os.path.abspath(sys.argv[1])
#env.outputCoordinateSystem = arcpy.SpatialReference(2913)

# csv file contains records for all 'permanent' max stops
oracle_stops_csv = os.path.abspath(sys.argv[2])
cleaned_stops_csv = os.path.join(env.workspace, 'permanent_stops_cleaned.csv')

def removeWhiteSpace():
    """When the csv containing the stops information is extracted from the Oracle
    database (HAWAII) a tool from sqlplus called spool is used which leaves a bunch
    white space around each of the csv entries, this removes that whitespace"""

    stops_list = []
    with open(oracle_stops_csv, 'rb') as orig_csv:
        reader = csv.reader(orig_csv)
        stops_list = [[value.strip() for value in row] for row in reader]

    with open(cleaned_stops_csv, 'wb') as new_csv:
        writer = csv.writer(new_csv)
        writer.writerows(stops_list)

def csv2shp():
    """Convert a csv to a shapefile using arcpy tools"""

    # Convert csv into feature layer (which is stored in memory)
    x_field = 'X_COORD'
    y_field = 'Y_COORD'
    stops_layer = 'max_stops'
    spatial_reference = arcpy.SpatialReference(2913)
    arcpy.management.MakeXYEventLayer(cleaned_stops_csv, x_field, y_field, stops_layer, spatial_reference)

    # Save the feature layer to a feature class that is stored on the disk, but first
    # delete the shapefile if it already exists as the fc2shp tool won't overwrite
    stops_shp = os.path.join(env.workspace, stops_layer + '.shp')
    if arcpy.Exists(stops_shp):
        arcpy.management.Delete(stops_shp)

    arcpy.conversion.FeatureClassToShapefile(stops_layer, os.path.dirname(stops_shp))

removeWhiteSpace()
csv2shp()