***README is currently under construction and fully not up-to-date***

## Overview
This project is comprised of scripts that automate the process of finding tax lots within network walking distance of light rail stops, determining the value of development that has occurred on those properties since the creation of the stop's light rail lines became public knowledge, and comparing that growth to other areas in the Portland metro region.  The initial piece of this analysis is to create isochrones: polygons that define the areas that can reach their corresponding stop by traveling the supplied distance (one half mile by default) or less.  The isochrones are created using `ArcGIS Network Analyst` and the network on which that tool executes routing is derived from `OpenStreetMap`.  The remaining data transformation and geoprocessing which fetches current light rail stops, determines the tax lots that fall within the isochrones, filters out ineligible tax lots, and the tabulates figures for the comparison areas, is done with open source tools that include the python packages `fiona`, `pyproj`, `shapely`, and `sqlalchemy` and sql scripts that utilize `PostGIS`.  The repo also contains a web map built with OpenLayers3 and Geoserver that visualizes the properties that fall into the varies categores defined by the analysis.

## Project Workflow
Follow the steps below to refresh the data and generate a current version of the statistics and supporting spatial data.

#### Development Environment
The following languages/applications must be installed to execute the scripts in this repo:
* Python 2.7.x
* PostgreSQL with PostGIS 2.0+
* Bash 3.0+

The first two items are fairly easy to install on all major platforms (a google search including the name of your operating system should get you what you need).  Bash is installed by default on Linux and Mac, and I recommend using [MinGW](http://www.mingw.org/) to get this functionality on Windows.

##### python package management
Python package dependencies are retrieved via `buildout`, however some of the GIS packages rely on C libraries ( `fiona`, `gdal`, `pyproj`, `shapely`) and will not install with buildout on Windows (nor potentially on Mac or Linux).  To install these on Windows used the precompiled binaries found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs/).  Alternately the package manager [`conda`](http://conda.pydata.org/docs/install/quick.html) is available on all major platforms and can be used to install these as well.  Finally, `arcpy` is a requirement of the script that generates the isochrones.  To get this package you need an ArcGIS Desktop license and the code also draws on the Network Analyst extension.

With the above dependencies in place the rest of the python packages will be taken care of with buildout.  Simply run `python bootstrap-buildout.py` to create project specific instance of python that includes buildout then run `./bin/buildout` to fetch the remaining python packages.

#### Update MAX Stop Data
buildout has generated an executable that will fetch the appropriate stops for this analysis, to execute it enter the following from the home directory: 
```sh
./bin/get_permanent_max_stops -d 'dbname' -u 'username' -p 'password'
```  
To see the options available for the script use: `./bin/get_permanent_max_stops --help`

#### Get Routable Street and Trail Shapefile via OpenStreetMap
A script has also been created that carries out this task.  To deploy enter:
```sh
./bin/osm2routable_shp
```  
See options by appending the  `--help` parameter.

#### Create Network Dataset with ArcGIS's Network Analyst
As of 4/2016 this phase of the project can't be automated with arcpy (only with `ArcObjects`), see [this post](http://gis.stackexchange.com/questions/59971/how-to-create-network-dataset-for-network-assistant-using-arcpy) for more details.  Thus this task must be carried out within ArcGIS Desktop using the folllowing steps:

* Open ArcMap and make sure that the Network Analyst Extension is enable (accessible under 'Customize' --> 'Extensions')
* In the ArcCatalog window right-click the OpenStreetMap shapefile created in the last step (relative to this repo the shapefile will be at  `../data/year_mon/shp/osm_foot.shp` where the year/month folder is the date of the latest tax lot data) and select 'New Network Dataset', this will launch a wizard that configures the network dataset
* Use the default name for the file
* Keep default of modeling turns
* Click 'Connectivity' and change 'Connectivity Policy' from 'End Point' to 'Any Vertex', **this step is critcial as routing will not function properly without it.**
* Leave elevation modeling as 'None'
* Delete the default network attributes with the 'Remove All' button
* Click 'Add...' button to create a new network attribute
* On the 'Add New Attribute' dialog enter the following, then click 'OK' (**note that the 'Name' attribute must have the exact name defined below or the python script that generates the isochrones won't be able to find it**):
	* `Name`: 'foot_permission'
	* `Usage Type`: Restriction
	* `Restriction Usage`: Prohibited
	* `Use by Default`: True (checked)
* Click the 'Evaluators...' button
* In the 'From-To' row under the 'Type' column select 'Field', then click the 'Evaluator Properties' button on the right-hand side of the dialog
* In the 'Field Evaluators' window set the 'Parser' to 'Python' and enter the following code:
	* Pre-Logic Script Code:
    ```py
    def foot_permissions(foot, access, highway, indoor):
        if foot in ('yes', 'designated', 'permissive'):
            return False
        elif access == 'no' or \
                highway in ('trunk', 'motorway', 'construction') or \
                foot == 'no' or indoor == 'yes':
            return True
        else:
            return False
    ```
    * Value =
    ```
    foot_permissions(!foot!, !access!, !highway!, !indoor!)
    ```
* Repeat the previous two steps of for the 'To-From' row in the 'Evaluators' dialog
* Optionally create a second Network Attribute that tabulates walk minutes using the following inputs: length is assumed to be in feet and walk speed is 3 miles per hour in this case
	* `Name`: 'walk_minutes'
	* `Type`: Cost
	* `Units`: leave as 'Unknown', see below for details
	* `Data Type`: Double
	* `Use by Default`: False (unchecked)
	* Pre-Logic Script Code:
    ```py
    def walk_minutes(length):
        walk_time = length / (5280 * (3 / float(60)))
        return walk_time
    ```
    * Value =
    ```
    walk_minutes(!Shape!)
    ```
* Select 'No' for the establishment of driving directions
* Review summary to ensure that all settings are correct then click 'Finish'
* Select 'Yes' when prompted to proceed with building the Network Dataset

Once the Network Dataset has finished building (which takes a few minutes), plan a couple of test trips to make sure that routing is working properly, particularly ones that ensure that walking restrictions are being applied to freeways, etc.

#### Create Isochrones

This step creates walkshed polygons (a.k.a. isochrones) that encapsulate the areas that can reach a given MAX stop by walking 'X' miles or less when traveling along the existing street and trail network.

1. Within `arcpy/create_isochrones.py` change the the variable called 'project_folder' to the name of the folder that was created for the current iteration.  This should be a subfolder within `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data` that reflects the current month and year in the format 'YYYY_MM'.  This step is critical because **older data will be overwritten and the wrong inputs will be used** if it is not carried out.  Within the python script named above there is a placeholder that will throw an error if not corrected, this is to ensure this change is made before the script is run.
2. Adjust walk distance thresholds if necessary.
3. Run `create_isochrones.py` in the python window within ArcMap.  **This code must be run in the ArcMap python window** as opposed to being lauched from the command prompt because features within a Service Area Layer cannot be accessed using the former method (not sure why, this seems to be a bug, planning to post the question on gis stackexchange and see if I can get a solution).  This is not ideal because when using the windows shell you can prompt users to give input (such as the name of the project folder), so I hope to be able to be able to find a way move away from the present method.  The script executed in a little under 10 minutes as of 02/2014.
4. Once the isochrones shapefile has been created bring it into a desktop GIS and sort the features by the area (ascending).  Examine the polygons with the smallest areas and if any of them appear to be suspiciously undersized then compare them to the OSM street and trail network to check for errors there.

#### Geoprocess Property Data and Generate Final Stats

Here the tax lot dataset is processed such that properties that are at least 80% covered by parks, natural areas, cemeteries or golf courses are removed from consideration for inclusion in the total value of development.  This step is not executed for the multifamily layer as it is implicit that they aren't covered by these landuses.  Then using the isochrones, properties that were built since the decision to build nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

1. Run the batch file stored here `bin/geoprocess_properties.bat`.  Because there are roughly 600,000 complex polygons in the taxlot shapefile the postgis geoprocessing that this batch file launches is somewhat time consuming (it seems to be taking somewhere between 30 minutes and an hour at this point, but its difficult determine when debugging due to postgresql's cache).
2. After the script completes it's a good idea to examine the taxlot and multi-family housing outputs in qgis to ensure that the steps have been executed as expected.
3. When confident in the resultant data use excel or openoffice to save the output csv's (written here: `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/YYYY_MM/csv`) to .xlsx format them for presentation.
4. Add metadata and any needed explanation of the statistics to the spreadsheets.
