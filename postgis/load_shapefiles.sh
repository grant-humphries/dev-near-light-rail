# First set the password for the postgres database so that it doesn't have to be repeatedly entered
#set pgpassword=**********
# commenting this out for now so my password isn't on github

# PROJECT DATA (these were created in earlier phases of the project, most are modified 
# versions of RLIS or TriMet data).  

# **NOTE:** The $1 sub-folder in the file path of 'project data' datasets must be replaced with the name of the folder that has been created for the current iteration of the project.  Don't push this change to github as it could lead to inadvertant use old files future iterations of the project

# MAX Stops 
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/$/max_stops.shp max_stops | psql -U postgres -d transit_dev

# Walkshed Polygons (Isocrones)
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/$1/max_stop_isocrones.shp isocrones | psql -U postgres -d transit_dev

# Trimmed Taxlots
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/$1/trimmed_taxlots.shp taxlot | psql -U postgres -d transit_dev

# Trimmed Multi-family Housing
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/$1/trimmed_multifam.shp multi_family | psql -U postgres -d transit_dev


# TRIMET DATA

# TriMet Service District Boundary
shp2pgsql -s 2913 -d -I //gisstore/gis/TRIMET/tm_fill.shp tm_district | psql -U postgres -d transit_dev


# RLIS DATA

# City Boundaries
shp2pgsql -s 2913 -d -I //gisstore/gis/Rlis/BOUNDARY/cty_fill.shp city | psql -U postgres -d transit_dev

# Urban Growth Boundary
shp2pgsql -s 2913 -d -I //gisstore/gis/Rlis/BOUNDARY/ugb.shp ugb | psql -U postgres -d transit_dev