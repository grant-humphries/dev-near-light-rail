***README is currently under construction and fully not up-to-date***

## Overview
This repo contains scripts that automate the process of finding tax lots within network walking distance of light rail stops, determining the value of development that has occurred on those properties since the creation of the stop's light rail lines became public knowledge, and comparing that growth to other areas in the Portland metro region.  The initial piece of this analysis is to create isochrones: polygons that define the areas that can reach their corresponding stop by traveling the supplied distance (one half mile by default) or less.  The isochrones are created using `ArcGIS Network Analyst` and the network on which that tool execute routing is derived from `OpenStreetMap`.  The remaining data transformation and geoprocessing which fetches current light rail stops, determines the tax lots that fall within the isochrones, filters out ineligible tax lots, and the tabulates figure for the comparison areas is done with open source tools which include the python packages `fiona`, `pyproj`, `shapely`, and `sqlalchemy` and sql scripts that utilize `PostGIS`.  The repo also contains a web map built with OpenLayers3 and Geoserver that visualizes the properties that fall into the varies categores defined by the analysis.

## Project Workflow
Follow the steps below to refresh the data and generate a current version of the statistics and supporting spatial data.

### Development Environment
The following applications/tools must be installed to execute the scripts in this repo
* Python 2.7.x
* PostgreSQL with PostGIS extension
* Bash 3.0+

The first two items are fairly easy to install on all major platforms (a google search including the name of your operating system should get you what you need).  Bash is installed by default on Linux and Mac and I recommend MinGW 

#### python package management
python package dependencies are retrieved with `buildout` however some of the GIS packages that rely on C libraries will not be installable with buildout on Windows (and even potentially on Mac or Linux)

### Update MAX Stop Data
It's good practice to update this data each time this project is refreshed to ensure any changes to the MAX network are captured
`./bin/get_permanent_max_stops`

### Create Updated Streets and Trails Shapefile from OpenStreetMap Data
`bin/osm2routable_shp`

This script grabs current OSM data, imports it into PostGIS using Osmosis, rebuilds the streets and trails network in a database table, then exports to shapefile.

### Create Network Dataset with ArcGIS's Network Analyst
As of 5/18/2014 this phase of the project can't be automated with arcPy (only ArcObjects), see [this post](http://gis.stackexchange.com/questions/59971/how-to-create-network-dataset-for-network-assistant-using-arcpy) for more details, if this functionality becomes available I plan to implented it as my ultimate goal is to have a single shell script that runs this entire process and this is one of my only remaining hurdles

1. In ArcMap right-click the OpenStreetMap shapefile created in the last step (called osm_foot.shp) and select 'New Network Dataset', this will launch a wizard that configures the network dataset
2. On the next screen use the default name for the file
3. Keep default of modeling turns
4. Click 'Connectivity' and change 'Connectivity Policy' from 'End Point' to 'Any Vertex', **this step is very important as routing will not function properly without it.**
5. Leave Z-input as 'None'
6. Create network attributes based on the python functions here: `arcpy/network_attributes.py` (under the current workflow only the 'foot_permissons' attribute needs to be added.  Optionly there is code to measure walk minutes) 


Settings for this network attribute:

NAME: 'foot_permissions' NOTE!!!: This attribute must have this exact name or the python script
that generates the isochrones won't be able to find it
USAGE TYPE: Restriction
RESTRICTION USAGE: Prohibited
USE BY DEFAULT?: Yes

EVALUATORS (click Evaluators button to access these settings): there will be two items used in
evaluators that have all of the same values except for the 'Direction' field
Source: 'osm_foot', Direction: item 1 - 'From-To', item 2 - 'To-From', Element: 'Edge', Type 'Field',
Value: (function below).  Note that for this function 'True' means walking is prohibited and 'False'
means that it's allowed

note that during the building of osm_foot shapefile all ways that were tagged highway=construction
and that had a valid street type value in the construction tag had that value transferred to the
highway field.  this is because we want to route along streets that are under construction in this
analysis unless there finished type isn't specified (in which case the 'construction' value would
persist in the highway field)

```py
def footPermissions(foot, access, highway, indoor):
    if foot in ('yes', 'designated', 'permissive'):
        return False

    elif access == 'no'
            or highway in ('trunk', 'motorway', 'construction')
            or foot == 'no' or indoor == 'yes':
        return True
    else:
        return False
```

```
footPermissions(!foot!, !access!, !highway!, !indoor!)
```

UPDATE 02/2014 - ***I refactored that generates the isocrones so adding the walk minutes attribute is
no longer compulsory.***  I'm leaving the code in place in case walk minutes are ever needed.

NAME: 'walk_minutes'
USAGE TYPE: Cost
UNITS: leave as 'Unknown', see below for details
DATA TYPE: Double
USE BY DEFAULT?: No

EVALUATORS:
Direction: item 1 - 'From-To', item 2 - 'To-From', Element: 'Edge', Type 'Field', Value: (function below)

length is assumed to be in feet and walk speed is 3 miles per hour in this case

```py
def walkMinutes(length):
    walk_time = length / (5280 * (3 / float(60)))
    return walk_time
```

```
walkMinutes(!Shape!)
```


7. Select 'No' for the establishment of driving directions
8. Review summary to ensure that all settings are correct then click 'Finish'
9. Select 'Yes' when prompted to proceed with building the Network Dataset

Once the Network Dataset has finished building (which takes a few minutes), plan a couple of test trips to make sure that routing is working properly, particularly that the foot permisson restrictions are being applied to freeways, etc.

### Generate Walkshed Isochrones

This step creates walkshed polygons (a.k.a. isochrones) that encapsulate the areas that can reach a given MAX stop by walking 'X' miles or less when traveling along the existing street and trail network.

1. Within `arcpy/create_isochrones.py` change the the variable called 'project_folder' to the name of the folder that was created for the current iteration.  This should be a subfolder within `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data` that reflects the current month and year in the format 'YYYY_MM'.  This step is critical because **older data will be overwritten and the wrong inputs will be used** if it is not carried out.  Within the python script named above there is a placeholder that will throw an error if not corrected, this is to ensure this change is made before the script is run.
2. Adjust walk distance thresholds if necessary.
3. Run `create_isochrones.py` in the python window within ArcMap.  **This code must be run in the ArcMap python window** as opposed to being lauched from the command prompt because features within a Service Area Layer cannot be accessed using the former method (not sure why, this seems to be a bug, planning to post the question on gis stackexchange and see if I can get a solution).  This is not ideal because when using the windows shell you can prompt users to give input (such as the name of the project folder), so I hope to be able to be able to find a way move away from the present method.  The script executed in a little under 10 minutes as of 02/2014.
4. Once the isochrones shapefile has been created bring it into a desktop GIS and sort the features by the area (ascending).  Examine the polygons with the smallest areas and if any of them appear to be suspiciously undersized then compare them to the OSM street and trail network to check for errors there.

### Geoprocess Property Data and Generate Final Stats

Here the tax lot dataset is processed such that properties that are at least 80% covered by parks, natural areas, cemeteries or golf courses are removed from consideration for inclusion in the total value of development.  This step is not executed for the multifamily layer as it is implicit that they aren't covered by these landuses.  Then using the isochrones, properties that were built since the decision to build nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

1. Run the batch file stored here `bin/geoprocess_properties.bat`.  Because there are roughly 600,000 complex polygons in the taxlot shapefile the postgis geoprocessing that this batch file launches is somewhat time consuming (it seems to be taking somewhere between 30 minutes and an hour at this point, but its difficult determine when debugging due to postgresql's cache).
2. After the script completes it's a good idea to examine the taxlot and multi-family housing outputs in qgis to ensure that the steps have been executed as expected.
3. When confident in the resultant data use excel or openoffice to save the output csv's (written here: `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/YYYY_MM/csv`) to .xlsx format them for presentation.
4. Add metadata and any needed explanation of the statistics to the spreadsheets.
