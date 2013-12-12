# Copyright: (c) Grant Humphries for TriMet, 2013
# ArcGIS Version:   10.2
# Python Version:   2.7.3
#--------------------------------

import os
import arcpy
from arcpy import env

# Allow shapefiles to be overwritten and set the current workspace
env.overwriteOutput = True
env.addOutputsToMap = True
env.workspace = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data'

walk_polygons = os.path.join(env.workspace, 'half_mile_walk_polys.shp')
rail_stops = os.path.join(env.workspace, 'rail_stop_mod.shp')

walk_shed_dict = {}
fields = ['Shape@', 'FacilityID']
with arcpy.da.SearchCursor(walk_polygons, fields) as cursor:
	for geom, fac_id in cursor:
		oid = fac_id - 1
		walk_shed_dict[oid] = [geom]

fields = ['OID@', 'STATION', 'STATUS', 'TYPE', 'LINE']
with arcpy.da.SearchCursor(rail_stops, fields) as cursor:
	for oid, station, status, mode_type, line in cursor:
		walk_shed_dict[oid].extend((station, status, mode_type, line, oid))

rail_walk_sheds = os.path.join(env.workspace, 'joined_rail_walk_polys.shp')
geom_type = 'Polygon'
epsg = arcpy.SpatialReference(2913)
arcpy.CreateFeatureclass_management(os.path.dirname(rail_walk_sheds), os.path.basename(rail_walk_sheds), 
										geom_type, spatial_reference=epsg)

new_fields = ['Station', 'Status', 'Type', 'Line', 'Origin_ID']
for field in new_fields:
	f_type = 'Text'
	arcpy.AddField_management(rail_walk_sheds, field, f_type)

drop_field = 'Id'
arcpy.DeleteField_management(rail_walk_sheds, drop_field)

fields = ['Shape@', 'Station', 'Status', 'Type', 'Line', 'Origin_ID']
with arcpy.da.InsertCursor(rail_walk_sheds, fields) as cursor:
	for attributes in walk_shed_dict.values():
		cursor.insertRow(attributes)