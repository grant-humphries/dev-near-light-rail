# Overview

This repo contains scripts that automate the majority of the process of finding taxlots within walking distance of light rail stops, determining the value of development that has occurred since those stops have been built, and comparing that growth to other areas in the Portland metro region.  Part of this process is a network analysis from each stop to the taxlots that are within a given walking distance.  This routing is done with ArcGIS's network analsyt (at this time, I am looking to migrate this to PostGres's pg_routing at some point) and files that play a role in the creation of the network which is derived from OSM data run through Osmosis are contained in this repo as well.  The primary output of this project is a set of statistics that describe the total value of properties that are within a walking threshold of MAX stops and that have been built upon/remodeled since the nearby MAX stop was created.  A number of spatial datasets are a by-product of this analysis and can (and have) been used to create maps that further explain the analysis.

# Project Workflow

Follow the steps below to refresh the data and generate a current version of the statistics and supporting spatial data.

## Update MAX Stop Data

It's good practice to update this data each time this project is refreshed to ensure any changes to the MAX network are captured

1. Update under-construction Orange Line stops (this step can be eliminated once they go into operation and are added to our spatial database stop tables)
    * Open Oracle SQL Developer and connect to the 'HAWAII' database.  Then go to the user 'TRANS' and run the query stored here `oracle/get_orange_max_stops.sql`
    * Save the result of the query as a csv in the following location `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data` as 'projected_orange_line_stops.csv' (overwriting previously existing data is ok)
    * Open the csv in ArcMap, display the x,y data, setting the projection to Oregon State Plane North (2913) and save it out as a shapefile with the same name (but .shp file extension) and in the same folder as the csv.

2. Run the batch file stored here: `bin/update_max_stops.bat` to create a shapefile that has all of the MAX stops that are currently in operation.  A python script that will be run later in this process will merge the two stop datasets.

## Create Updated Streets and Trails Shapefile from OpenStreetMap Data

Run the batch file stored here `bin/osm2routable_shp.bat`.

This script grabs current OSM data, imports it into PostGIS using Osmosis, rebuilds the streets and trails network in a database table, then exports to shapefile.

## Create Network Dataset with ArcGIS's Network Analyst

As of 5/18/2014 this phase of the project can't be automated with arcPy (only ArcObjects), see [this post](http://gis.stackexchange.com/questions/59971/how-to-create-network-dataset-for-network-assistant-using-arcpy) for more details, if this functionality becomes available I plan to implented it as my ultimate goal is 'one-click' automation.

1. In ArcMap right click OpenStreetMap shapefile created in the last step and select 'New Network Dataset', this will launch a wizard that configures the network dataset
2. In the next screen use the default name for the file
3. Keep default of modeling turns
4. Click 'Connectivity' and change 'Connectivity Policy' from 'End Point' to 'Any Vertex', **this step is very important as routing will not function properly without it.**
5. Leave Z-input as 'None'
6. Create network attributes based on the python functions here: `arcpy/network_attributes.py` (under the current workflow only the 'foot_permissons' attribute needs to be added.  Optionly there is code to measure walk minutes) 
7. Select 'No' for the establishment of driving directions
8. Review summary to ensure that all settings are correct then click 'Finish'
9. Select 'Yes' when prompted to proceed with building the Network Dataset

Once the Network Dataset has finished building (which takes a few minutes), plan a couple of test trips to make sure that routing is working properly, particularly that the foot permisson restrictions are being applied to freeways, etc.

## Generate Walkshed Isochrones

This step creates walkshed polygons (a.k.a. 'isochrones') that encapsulate the areas that can reach a given MAX stop by walking 'X' miles or less when traveling along the existing street and trail network.

1. Within `arcpy/create_isochrones.py` change the project workspace (variable: 'env.workspace') to the folder that was created for the current iteration.  This should be a subfolder within `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data` that reflects the current month and year in the format 'YYYY_MM'.  This step is very important because if it is not done **older data will be overwritten and the wrong inputs will be used**.  Within the python script named above there is a placeholder that will throw an error if not corrected, this is to ensure this change is made before the script is run.
2. Check to see if the Orange Line stops have been added to the MAX stop data from the database on maps10.trimet.org.  If they have remove the block of code that was adds them to the maps10 export.
3. Adjust walk distance thresholds if necessary.
4. Run `create_isochrones.py` in the python window in ArcMap.  **This code must be run in the ArcMap python window** as opposed to being lauched from the command prompt because features within a Service Area Layer cannot be accessed using the former (not sure why, this seems to be a bug, planning to post the question on gis stackexchange and see if I can get a solution).  This is not ideal because when using the command prompt you can prompt users to to give input (such as the name of the project folder), so I hope to be able to be able to find a way to switch to this method.  The script executed in a little under 10 minutes as of 02/2014.
5. Once the isochrones shapefile has been created bring it into ArcMap or QGIS and sort the features by the area (ascending) to make sure the smallest ones have formed properly.  If any of them appear to be suspiciously undersized then compare them to the OSM network and determine in any changes to need to be made to geometry or attributes.

## Trim, Select and Compare Property Data and Generate Final Stats

Here the tax lot and multi-family housing datasets are processed such that the areas within them that are covered by water or natural areas (including parks) are removed.  This is done because total property area is used as divisor to normalize development value and only areas of taxlots on which new construction/remodeling can occur should be considered.  Then using the isochrones created earlier properties that were built more recently than nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

1. Run the batch file stored here `bin/trim_compare_property_generate_stats.bat`.  Because there are roughly 600,000 polygons in the taxlot shapefile the geoprocessing in the first python script that this batch file launches is time consuming (it took ~40 minutes as of last run).  Multi-processing may be able to speed this up significantly and I plan to look into it at some point, for more info see the comments in the second section of the code.
2. The batch script will pause automatically after the property data has been trimmed, examine the taxlot and multi-family housing layers and ensure sure the erasures have executed properly.
3. After the script has completed use Excel or OpenOffice to save the output csv's (written here: `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/YYYY_MM/csv`) to .xlsx format them for presentation.
4. Add metadata and any needed explanation of the statistics to the spreadsheets.