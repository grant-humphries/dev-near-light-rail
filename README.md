***README is currently under construction and fully not up-to-date***

## Overview
This project is comprised of scripts that automate the process of finding tax lots within network walking distance of light rail stops, determining the value of development that has occurred on those properties since the creation of the stop's light rail lines became public knowledge, and comparing that growth to other areas in the Portland metro region.  The initial piece of this analysis is to create isochrones: polygons that define the areas that can reach their corresponding stop by traveling the supplied distance (one half mile by default) or less.  The isochrones are created using `ArcGIS Network Analyst` and the network on which that tool executes routing is derived from `OpenStreetMap`.  The remaining data transformation and geoprocessing which fetches current light rail stops, determines the tax lots that fall within the isochrones, filters out ineligible tax lots, and the tabulates figures for the comparison areas, is done with open source tools that include the python packages `fiona`, `pyproj`, `shapely`, and `sqlalchemy` and sql scripts that utilize `PostGIS`.  The repo also contains a web map built with OpenLayers3 and Geoserver that visualizes the properties that fall into the varies categores defined by the analysis.

## Development Environment
The following languages/applications must be installed to execute the scripts in this repo:
* Python 2.7.x
* PostgreSQL with PostGIS 2.0+
* Bash 3.0+

The first two items are fairly easy to install on all major platforms (a google search including the name of your operating system should get you what you need).  Bash is installed by default on Linux and Mac, and I recommend using [MinGW](http://www.mingw.org/) to get this functionality on Windows.

#### python package management
Python package dependencies are retrieved via `buildout`, however some of the GIS packages rely on C libraries ( `fiona`, `gdal`, `pyproj`, `shapely`) and will not install with buildout on Windows (nor potentially on Mac or Linux).  To install these on Windows used the precompiled binaries found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs/).  Alternately the package manager [`conda`](http://conda.pydata.org/docs/install/quick.html) is available on all major platforms and can be used to install these as well.  Finally, `arcpy` is a requirement of the script that generates the isochrones.  To get this package you need an ArcGIS Desktop license and the code also draws on the Network Analyst extension.

With the above dependencies in place the rest of the python packages will be taken care of with buildout.  Simply run `python bootstrap-buildout.py` to create project specific instance of python that includes buildout then run `./bin/buildout` to fetch the remaining python packages.

## Script Execution
The entirety of this process can be carried out by launching a single shell script which in turn executes a series constituent console and shell scripts.  The parent script is called `master.sh` and is stored in the `sh` directory.  For details on what each of the child scripts do and how they can be executed individually see below.


#### update MAX stop data
The `get_max_stops` script in the `bin` directory uses `sqlalchemy` and the trimet's `TRANS` sqlalchemy model to fetch existing max stops.  It then uses `fiona` and `shapely` to write that data to a shapefile.  Database parameters can be passed to the script with flags, use the `--help` flag to see available options.  An example of a call to this script is below:

```sh
get_permanent_max_stops -d 'dbname' -u 'username' -p 'password'
```  

#### get routable street and trail shapefile via OpenStreetMap
A script has also been created that carries out this task.  To deploy enter:
```sh
./bin/osm2routable_shp
```  
See options by appending the  `--help` parameter.

#### create network dataset with ArcGIS Network Analyst
Execute `create_network` console script in the `bin` directory to create network dataset from the OSM shapefile generated in the last stop.  The script, use the `comtypes` module and `ArcObjects` to create the network as this can't presently be done with `arcpy`.

Once the Network Dataset has finished building (which takes a few minutes), plan a couple of test trips using the Network Analyst Toolbar (more details on how to do this [here](http://desktop.arcgis.com/en/arcmap/latest/extensions/network-analyst/route.htm)) to make sure that routing is working properly.  In particular ensure that walking restrictions are being applied to freeways, etc.

#### create isochrones

This step creates walk shed polygons (a.k.a. isochrones) that encapsulate the areas that can reach a given MAX stop by walking a supplied maximum distance (one half mile by default) or less when traveling along the existing street and trail network.

* Use the `-d` parameter to set the walk distance in feet if you wish to deviate from the default of 2640
3. Run `./bin/create_isochrones` The script executed in a little under 10 minutes as of 02/2014.
4. Once the isochrones shapefile has been created bring it into a desktop GIS and sort the features by the area (ascending).  Examine the polygons with the smallest areas and if any of them appear to be suspiciously undersized then compare them to the OSM street and trail network to check for errors there.

#### geoprocess property data with PostGIS and generate final stats

Here the tax lot dataset is processed such that properties that are at least 80% covered by parks, natural areas, cemeteries or golf courses are removed from consideration for inclusion in the total value of development.  This step is not executed for the multifamily layer as it is implicit that they aren't covered by these landuses.  Then using the isochrones, properties that were built since the decision to build nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

After the script completes it's a good idea to examine the tax lot and multi-family housing outputs in qgis to ensure that the steps have been executed as expected.

When confident in the resultant data use excel or openoffice to save the output csv's (written here: `G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/YYYY_MM/csv`) to .xlsx format them for presentation.  Add metadata and any needed explanation of the statistics to the spreadsheets.
