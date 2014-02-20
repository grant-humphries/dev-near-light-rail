# Overview

This repo contains scripts that automate the majority of the process of finding taxlots within walking distance of light rail stops, determining the value of development that has occurred since those stops have been built, and comparing that growth to other areas in the Portland metro region.  Part of this process is a network analysis from each stop to the taxlots that are within a given walking distance.  This routing is done with ArcGIS's network analsyt (at this time, I am looking to migrate this to PostGres's pg_routing at some point) and files that play a role in the creation of the network which is derived from OSM data run through Osmosis are contained in this repo as well.  The primary output of this project is a set of statistics that describe the total value of properties that are within a walking threshold of MAX stops and that have been built upon/remodeled since the nearby MAX stop was created.  A number of spatial datasets are a by-product of this analysis and can (and have) been used to create maps that further explain the analysis.

# Project Workflow

Follow the steps below to refresh the data and generate a current version of the statistics and supporting spatial data.

## Update MAX Stop Data

It's good practice to update this data each time this project is refreshed to ensure any changes to the MAX network are captured

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

As of 2/18/2014 this phase of the project can't be automated with arcPy (only ArcObjects), see [this post](http://gis.stackexchange.com/questions/59971/how-to-create-network-dataset-for-network-assistant-using-arcpy) for more details, if this functionality becomes available I plan to implented it as my ultimate goal is 'one-click' automation.

1. In ArcMap right click OpenStreetMap shapefile created in the last step and select 'New Network Dataset', this will launch a wizard that configures the network dataset
2. In the next screen use the default name for the file
3. Keep default of modeling turns
4. Click 'Connectivity' and change 'Connectivity Policy' from 'End Point' to 'Any Vertex', **this step is very important as routing will not function properly without it.**
5. Leave Z-input as 'None'
6. Create network attributes based on the python functions here: `arcpy\network_attributes.py` (under the current workflow only the 'foot_permissons' attribute needs to be added.  Optionly there is code to measure walk minutes) 
7. Select 'No' for the establishment of driving directions
8. Review summary to ensure that all settings are correct then click 'Finish'

Once the network dataset has finished building (which takes a few minutes), plan a couple of test trips to make sure that routing is working properly, particularly that the foot permisson restrictions are being applied to freeways, etc.

## Generate Walk Distance Isocrones and Trim Property Data

The heavy lifting of the analysis is in these next two phases and almost all of is automated. This step will create walkshed polygons (aka 'isocrones') that encapsulate the areas that can reach a given MAX stop by walking X miles or less.  It also processes the two property datasets to remove area from them that are covered by water or natural areas.  This done so that development can be compared against areas of taxlots on which new construction/remodeling can occur.

1. Within `arcpy\create_isocrones_trim_property.py` change the project workspace to the folder that was created when the MAX stop data was updated at the beginning of this process.  This step is very important because if it is not done **older data will be overwritten and the wrong inputs will be used**.
2. Check to see if the Orange Line stops have been added to the MAX stop data from the database on maps5.trimet.org.  If they have remove the block of code that was adds them to the maps5 export.
3. Adjust walk distance thresholds if necessary.
45. Run `create_isocrones_trim_property.py`.  This takes a little under 50 minutes to execute as of 02/2014.
5. Once the isocrones shapefile has been created add a field to it and populate that field with the polygon's area.  Then sort the features by their area (ascending) and make sure the smallest ones have formed properly.  In the past a couple of stops have snapped to islands trapping the 'walker' in a small area.
6. Examine the taxlot and multi-family housing layers and ensure sure the erasures have executed properly.

The majority of the run time of this script is spend on geoprocessing the property data (~40 minutes).  Multi-processing may be able to speed this up significantly and I plan to look into it at some point, for more info see the comments in the second section of the code.

## Select and Compare Property Data and Generate Final Stats

This final phase of the project selects taxlots and multi-family units that are within walking distance of MAX stops and have been built upon or remodeled since the decision was made to build nearby MAX stops.   Then compares them to real estate development in the same time frame in larger areas throughout the Portland metro region in an to attempt to get a sense of the impact the addition of MAX has had on growth in nearby areas.

1. Create PostGIS database called **transit_dev** (version of PostGIS must be 2.0 or later for subsequent code to work) 
2. Load the following datasets into the database:
	
   **Project data**
    	
    * MAX Stops
    * Walkshed Polygons (Isocrones)
    * Trimmed Taxlots
    * Trimmed Multi-family Housing
    
   **TriMet data**
    	
    * TriMet Service District Boundary
    
   **RLIS data**
    	
    * Cities
    * Urban Growth Boundary
    
 Shell commands that load this data into the db via the command prompt can be found here: `postgis\... .sh`.  Within these commands the locations of these files is indicated via file paths (although the location is variable based on the interation of project for 'project data').  I'd like to migrate this part of the analysis to the server maps2.trimet.org because the RLIS and TriMet datasets are pre-loaded there, but note that the project datasets would still need to be added to the db each time this analysis is carried out. 

3. Run `postgis\select_and_compare_properties.sql`
4. Execute `postgis\compile_property_stats.sql`
5. Use the following command to write the final stats tables created by the script above to csv's:
	
    ```Shell
    psql code
    ```
    
6. Save the csv's as Excel files and format them
7. Add metadata to the spreadsheets
8. Prosper!!!!!!!!!!