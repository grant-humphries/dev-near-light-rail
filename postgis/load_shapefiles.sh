# First set the password for the postgres database so that it doesn't have to be repeatedly entered
#set pgpassword=**********
# commenting this out for now so my password isn't on github

# **NOTE:** The file path for the project data need to be updated for each new iteration of the
# project. To do this find and replace '2014_02' with the name of the current folder 'date' folder 

# PROJECT DATA (these were created in earlier phases of the project, most are modified 
# versions of RLIS or TriMet data).  

# MAX Stops 
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2014_02/max_stops.shp max_stops | psql -U postgres -d transit_dev

# Walkshed Polygons (Isocrones)
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2014_02/max_stop_isocrones.shp isocrones | psql -U postgres -d transit_dev

# Trimmed Taxlots
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2014_02/trimmed_taxlots.shp taxlot | psql -U postgres -d transit_dev

# Trimmed Multi-family Housing
shp2pgsql -s 2913 -d -I //gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/2014_02/trimmed_multifam.shp multi_family | psql -U postgres -d transit_dev


# TRIMET DATA

# TriMet Service District Boundary
shp2pgsql -s 2913 -d -I //gisstore/gis/TRIMET/tm_fill.shp tm_district | psql -U postgres -d transit_dev


# RLIS DATA

# City Boundaries
shp2pgsql -s 2913 -d -I //gisstore/gis/Rlis/BOUNDARY/cty_fill.shp city | psql -U postgres -d transit_dev

# Urban Growth Boundary
shp2pgsql -s 2913 -d -I //gisstore/gis/Rlis/BOUNDARY/ugb.shp ugb | psql -U postgres -d transit_dev