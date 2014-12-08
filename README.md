# Overview

This repo contains scripts that automate the process of finding taxlots within network walking distance of light rail stops, determining the value of development that has occurred since those stops have been built, and comparing that growth to other areas in the Portland metro region.  Part of this process is a network analysis that determines which tax lots can reach each stop using the street and trail network within a given walking distance (usually half of  mile).  This routing is done with ArcGIS's Network Analyst (at this time, although I'm considering migrating this to PostGreSQL's pg_routing extension) and the routable network that is used for this analysis is derived from OpenStreetMap via Osmosis and PostGIS.  The primary output of this project is a set of statistics that describe the total value of properties that are within a walking threshold of MAX stops and that have been developed since it was confirmed that the nearby MAX stop would be built.  The parcel data used here is every tax lot for Multnomah, Washington and Clackamas counties, which is ~600,000 fairly complex polygons.  Thus developing efficient geoprocessing operations on these was one of the biggest challenges of this work.  A number of spatial datasets are a by-product of this analysis and those have been used in a variety of map products in order to visualize the analysis.

# Project Workflow

Follow the steps below to refresh the data and generate a current version of the statistics and supporting spatial data.

## Update MAX Stop Data

It's good practice to update this data each time this project is refreshed to ensure any changes to the MAX network are captured

1. Run the batch file stored here: `bin/update_max_stops.bat` to create a shapefile that has all of the MAX stops that are currently in operation.

This script runs a query on the HAWAII database, writes the output to csv then converts the csv to shapefile.  It ultizes the stops identified in the landmark table to avoid missing any stops that are temporarily closed

## Create Updated Streets and Trails Shapefile from OpenStreetMap Data

1. Run the batch file stored here `bin/osm2routable_shp.bat`.

This script grabs current OSM data, imports it into PostGIS using Osmosis, rebuilds the streets and trails network in a database table, then exports to shapefile.

## Create Network Dataset with ArcGIS's Network Analyst

As of 5/18/2014 this phase of the project can't be automated with arcPy (only ArcObjects), see [this post](http://gis.stackexchange.com/questions/59971/how-to-create-network-dataset-for-network-assistant-using-arcpy) for more details, if this functionality becomes available I plan to implented it as my ultimate goal is to have a single shell script that runs this entire process and this is one of my only remaining hurdles

1. In ArcMap right-click the OpenStreetMap shapefile created in the last step (called osm_foot.shp) and select 'New Network Dataset', this will launch a wizard that configures the network dataset
2. On the next screen use the default name for the file
3. Keep default of modeling turns
4. Click 'Connectivity' and change 'Connectivity Policy' from 'End Point' to 'Any Vertex', **this step is very important as routing will not function properly without it.**
5. Leave Z-input as 'None'
6. Create network attributes based on the python functions here: `arcpy/network_attributes.py` (under the current workflow only the 'foot_permissons' attribute needs to be added.  Optionly there is code to measure walk minutes) 
7. Select 'No' for the establishment of driving directions
8. Review summary to ensure that all settings are correct then click 'Finish'
9. Select 'Yes' when prompted to proceed with building the Network Dataset

Once the Network Dataset has finished building (which takes a few minutes), plan a couple of test trips to make sure that routing is working properly, particularly that the foot permisson restrictions are being applied to freeways, etc.

## Generate Walkshed Isochrones

This step creates walkshed polygons (a.k.a. isochrones) that encapsulate the areas that can reach a given MAX stop by walking 'X' miles or less when traveling along the existing street and trail network.

1. Within `arcpy/create_isochrones.py` change the the variable called 'project_folder' to the name of the folder that was created for the current iteration.  This should be a subfolder within `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data` that reflects the current month and year in the format 'YYYY_MM'.  This step is critical because **older data will be overwritten and the wrong inputs will be used** if it is not carried out.  Within the python script named above there is a placeholder that will throw an error if not corrected, this is to ensure this change is made before the script is run.
2. Adjust walk distance thresholds if necessary.
3. Run `create_isochrones.py` in the python window within ArcMap.  **This code must be run in the ArcMap python window** as opposed to being lauched from the command prompt because features within a Service Area Layer cannot be accessed using the former method (not sure why, this seems to be a bug, planning to post the question on gis stackexchange and see if I can get a solution).  This is not ideal because when using the windows shell you can prompt users to give input (such as the name of the project folder), so I hope to be able to be able to find a way move away from the present method.  The script executed in a little under 10 minutes as of 02/2014.
4. Once the isochrones shapefile has been created bring it into a desktop GIS and sort the features by the area (ascending).  Examine the polygons with the smallest areas and if any of them appear to be suspiciously undersized then compare them to the OSM street and trail network to check for errors there.

## Geoprocess Property Data and Generate Final Stats

Here the tax lot dataset is processed such that properties that are at least 80% covered by parks, natural areas, cemeteries or golf courses are removed from consideration for inclusion in the total value of development.  This step is not executed for the multifamily layer as it is implicit that they aren't covered by these landuses.  Then using the isochrones, properties that were built since the decision to build nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

1. Run the batch file stored here `bin/geoprocess_properties.bat`.  Because there are roughly 600,000 complex polygons in the taxlot shapefile the postgis geoprocessing that this batch file launches is somewhat time consuming (it seems to be taking somewhere between 30 minutes and an hour at this point, but its difficult determine when debugging due to postgresql's cache).
2. After the script completes it's a good idea to examine the taxlot and multi-family housing outputs in qgis to ensure that the steps have been executed as expected.
3. When confident in the resultant data use excel or openoffice to save the output csv's (written here: `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/YYYY_MM/csv`) to .xlsx format them for presentation.
4. Add metadata and any needed explanation of the statistics to the spreadsheets.