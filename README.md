# Overview

This repo contains scripts that automate the majority of the process of finding taxlots within walking distance of light rail stops, determining the value of development that has occurred since those stops have been built, and comparing that growth to other areas in the Portland metro region.  Part of this process is a network analysis from each stop to the taxlots that are within a given walking distance.  This routing is done with ArcGIS's network analsyt (at this time, I am looking to migrate this to PostGres's pg_routing at some point) and files that play a role in the creation of the network which is derived from OSM data run through Osmosis are contained in this repo as well.  The primary output of this project is a set of statistics that describe the total value of properties that are within a walking threshold of MAX stops and that have been built upon/remodeled since the nearby MAX stop was created.  A number of spatial datasets are a by-product of this analysis and can (and have) been used to create maps that further explain the analysis.

# Project Workflow

Follow the steps below to refresh the data and generate a current version of the statistics and supporting spatial data.

## Update MAX Stop Data

1. Connect to map server **maps5.trimet.org** (or any other TriMet map server with PostGIS databases) with QGIS.
2. Load the table **current.stop_ext**.
3. Apply the following definition query to the data in order to filter out all non-MAX transit stops (but also be sure that this is what is desired for the current iteration of the project, there has been some discussion of adding frequent service bus and the streetcar has been analyzed in the past):

	```sql
	SELECT * FROM current.stop_ext WHERE "type" = 5
	```

	this query actually must be shorted to `"type" = 5` to be used in QGIS as it only interprets the where clause

4. Create a new sub-folder at the following location: `G:\PUBLIC\GIS_Projects\Development_Around_Lightrail\data` the folder should indicate the date of the current iteration and be in the following format `YYYY_MM`.
5. Save the stops data as a shapefile with the projection Oregon State Plane North (epsg: **2913**) in the newly created folder and give it the name `max_stops.shp`.

## Update OSM Data and Import into PostGIS with Osmosis

Instruction outlines below were derived from a blog post found [here](http://skipperkongen.dk/2012/08/02/import-osm-data-into-postgis-using-osmosis/).  I've modified the orginal workflow in order to meet the needs of this project.

1. Refresh the OSM data stored here: `G:\PUBLIC\GIS_Projects\Development_Around_Lightrail\osm_data\or-wa.osm` with the nightly download that is written here: `G:\PUBLIC\OpenStreetMap\data\osm\or-wa.osm`
2. Create a PostGIS database in postgres and name it **osmosis_ped**
3. Create a schema compatable with Osmosis imports in the new database by running the following script : `pgsimple_schema_0.6.sql` (this file is included in the Osmosis download).  Execute the script by using the following command:

	```Shell
	psql -d osmosis_ped -U postgres -f "C:\Program Files (x86)\Osmosis\script\pgsimple_schema_0.6.sql"
	```
	It may also be neccessary to set the password for the postgres user using the command `SET pgpassword=xxx`

4. Import the OpenStreetMap data into the database via Osmosis by pasting the command stored here `osmosis\osmosis_command.sh` (within this repo) into the command prompt.
5. Turn the deconstructed OSM data (this is the format that Osmosis produces) back into line segments by running the script stored here: `dev-near-lightrail\osmosis\compose_trails.sql`.  Anything that is not a street or trails has been filtered out by Osmosis.  Use the command below to run the script from the command prompt:

	```Shell
	psql -d osmosis_ped -U postgres -f "G:\PUBLIC\GIS_Projects\Development_Around_Lightrail\github\dev-near-lightrail\osmosis\compose_trails.sql"
	```

6. Create a shapefile of the OSM data by connecting to the **osmosis_ped** database with QGIS, adding the table created in step 5 (which is called **streets_and_trails**) to the map and saving it as shapefile called `osm_foot.shp` with an ESPG of **2913**.

## Create Network Dataset with ArcGIS's Network Analyst

As of 2/18/2014 this phase of the project can't be automated with arcPy (only ArcObjects), see [this post](http://gis.stackexchange.com/questions/59971/how-to-create-network-dataset-for-network-assistant-using-arcpy) for more details, if this functionality becomes available I plan to implented it as my ultimate goal is 'one-click' automation.  To create a routable network dataset do the following:

1. In ArcMap right click OpenStreetMap shapefile created in the last step and select 'New Network Dataset', this will launch a wizard that configures the network dataset
2. In the next screen use the default name for the file
3. Keep default of modeling turns
4. Click 'Connectivity' and change 'Connectivity Policy' from 'End Point' to 'Any Vertex', **this step is very important as routing will not function properly without it.**
5. Leave Z-input as 'None'
6. Create network attributes based on the python functions here: `network_analyst\foot_permissions.py`
7. Select 'No' for the establishment of driving directions
8.  
9. Plan a couple of test trips to make sure that routing is working properly, particularly that the foot permisson restrictions are being applied to freeways, etc.

## Generate Walk Distance Isocrones and Trim Property Data

The heavy lifting of the analysis is in these next two phases and almost all of is automated.  To create walkshed polygons (aka 'isocrones') for each of the MAX stops run `arcpy\create_isocrones_trim_property.py`.  Be sure **change the file path for the project workspace** to the new folder that was created when the MAX stop data was updated at the beginning of this workflow or older data will be overwritten and the wrong inputs will be used.  After the isocrones are created sort them by their area (ascending) and make sure the smallest ones have formed properly.  Sometimes the starting points can snap to island trapping the walker in a tiny areas.  If the walk distance thresholds need to be adjusted from previous iterations of this analysis make those changes with the python script.  The script named above also erases water bodies, parks and natural areas from properties which they overlap.  This is a very computationally intensive process and took about 38 minutes to complete when I last attempted.

## Select and Compare Property Data and Generate Final Stats

This ste  Run `postgis\select_taxlots.py`.  This script determines which tax lots and multi-family units meet spatial and attribute criteria to be considered a part of growth that was a least in part due to the construction of a MAX line.  Be sure to change file paths to the new project folder created at the beginning of these instructions.  Updates to the Taxlot and Multi-Family unit data that is used within this script will happen automatically as a part of other processes not related to this project.
