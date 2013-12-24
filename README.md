# Overview

This repo contains scripts that automate the majority of the process of finding taxlots near light rail stops and determining the value of development that has occurred since those stops have been built.  Part of this process is a network analysis from the stop to the taxlots that are within a given walking distance.  This routing is done with ArcGIS's network analsyt (at this time, I am looking to migrate this to pg_routing at some point) and files that play a role of the creation of the network which is derived from OSM data and Osmosis are contained in this repo as well.  The primary output of this project is a set of statistics that describe the total value of properties that are within the set walking threshold of a MAX stop and have been built up since the nearby MAX stop was created.  A number of spatial dataset are a by product of this analysis and could be used to create maps further explaining the analysis.

# Project Workflow

## Update MAX Stop Data

1. Connect to map server 'maps5.trimet.org' with QGIS.
2. Load the table 'current.stop_ext'.
3. Apply the following definition query to the data in order to filter out all non-MAX stops (but also be sure that this is what is desired for the current iteration of the project, there has been some discussion of adding frequent service bus and the streetcar has been analyzed in the past):

'''
"type" = 5
'''

4. Create a new sub-folder at the follwowing location: 'G:\PUBLIC\GIS_Projects\Development_Around_Lightrail\data' the folder should represent the data and be in the following format 'YYYY_MM'.
5. Save the stops data as a shapefile with the projection '2913' in the newly created folder and include the date in the name of the shapefile.

## Update OSM Data and Import into PostGIS with Osmosis

Original instructions on how load OSM data into a PostGreSQL database were found here:
http://skipperkongen.dk/2012/08/02/import-osm-data-into-postgis-using-osmosis/.  I modified this workflow in order to meet the needs of my project.

1. Refresh the OSM data stored here: 'G:\PUBLIC\GIS_Projects\Development_Around_Lightrail\osm_data\or-wa.osm' with the nightly download that is saved here: 'G:\PUBLIC\OpenStreetMap\data\osm\or-wa.osm'
2. Create a PostGIS database in postgres and name it 'osmosis_ped'
3. Create the Osmosis schema within the newly created database by running the following script that comes with the Osmosis download: 'pgsimple_schema_0.6.sql'.  Do this by using the following command:

'''
psql -d osmosis_ped -U postgres -f "C:\Program Files (x86)\Osmosis\script\pgsimple_schema_0.6.sql"
'''

It may also be neccessary to set the password for the postgres user using the command 'set pgpassword=xxx'
4. Run Osmosis using the command in 'dev-near-lightrail\osmosis\osmosis_command.sh'
5. Run the following script: 'dev-near-lightrail\osmosis\compose_trails.sql' to create a table that has the geometry of the streets and trails desired for the network analysis, to run this in the command line use the shell snippet below:

'''
psql -d osmosis_ped -U postgres -f "G:\PUBLIC\GIS_Projects\Development_Around_Lightrail\github\dev-near-lightrail\osmosis\compose_trails.sql"
'''

6. Connect to the 'osmosis_ped' db with QGIS, add the table created in step 5 to the map and save it as shapefile with an ESPG of 2913.

## Create Network Dataset with ArcGIS's Network Analyst

This step can't be 

## Generate Walk Distance Isocrones

Run 'create_isocrones.py'.  Be sure change the file path for the project workspace to the new folder that will be created when the MAX stop data is updated and saved or older data will be overwritten and the wrong inputs will be used.  If the walk distance thresholds need to be adjusted from previous iterations of this analysis make those changes with the python script.

## Determine Tax Lots that Meet Spatial and Attribute Criteria and Generate Final Stats

Run 'select_taxlots.py'.  Again be sure to change file paths to the new project folder created at the beginning of these instructions.  Updates to the Taxlot and Multi-Family unit data that is used within this script will happen automatically as a part of other processes not related to this project.