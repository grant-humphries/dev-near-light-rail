## Overview
This project is comprised of scripts that automate the process of finding tax lots within network walking distance of light rail stops, determining the value of development that has occurred on those properties since the creation of the stop's light rail lines became public knowledge, and comparing that growth to other areas in the Portland metro region.  The initial piece of this analysis is to create isochrones: polygons that define the areas that can reach their corresponding stop by traveling the supplied distance (one half mile by default) or less.  The isochrones are created using ArcGIS `Network Analyst` and the network on which that tool executes routing is derived from [OpenStreetMap](osm.org).  The remaining data transformation and geoprocessing which fetches current light rail stops, determines tax lots that fall within the isochrones, filters out ineligible tax lots, and the tabulates figures for the comparison areas, is done with open source tools that include python packages `fiona`, `pyproj`, `shapely`, and `sqlalchemy` and sql scripts that utilize `PostGIS`.  The repo also contains a web map built with OpenLayers3 and Geoserver that visualizes the properties that fall into the varies categores defined by the analysis.

## Development Environment
The following languages/applications must be installed to execute the scripts in this repo:
* Python 2.7.x
* PostgreSQL with PostGIS 2.0+
* Bash 3.0+

Because the creation of the isochrones relies on ArcGIS this project must be carried out on a Windows machine.  The first two requirements are fairly easy to install on this operating system and I recommend getting [MinGW & MSYS](http://www.mingw.org/) to acquire a Bash-based shell.

#### python package management
Python package dependencies are retrieved via `buildout`, however some of the GIS packages rely on C libraries ( fiona, `gdal`, pyproj, shapely) and will not compile properly and install with buildout on Windows.  To get these on Windows used the precompiled binaries found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs/) or the package manager [`conda`](http://conda.pydata.org/docs/install/quick.html).  Last, `arcpy` is a requirement of the script that generates the isochrones.  To get this package one mut have ArcGIS Desktop license as well as access to a Network Analyst extension.

With the above dependencies in place the rest of the python packages will be taken care of with buildout.  Simply run `python bootstrap-buildout.py` (using a version of python that has the packages named in the paragraph above) to create project specific buildout.  The script creates several directories, one of which is `bin` and contains the buildout executable.  Launch buildout to create a project instance of python that will have all of the required packages as well as console scripts, all of which will be created in `bin`.  Alternatively, if you already have `zc.buildout` installed on the python instance that you're using, just enter the command `buildout` from the project's home directory to create a project python and the scripts.

## Script Execution
The entirety of this process can be carried out by launching a single shell script which in turn executes a series constituent console and shell scripts.  The parent script is called `master.sh` and is stored in the `sh` directory.  For details on what each of the child scripts do and how they can be executed individually see the sections below.


#### update MAX stop data
The `get_max_stops` script in the `bin` directory uses sqlalchemy and TriMet's `TRANS` sqlalchemy model to fetch existing max stops.  It then uses fiona and shapely to write that data to a shapefile.  Database parameters can be passed to the script with flags, and use the `--help` flag to see available options.  An example of a call to this script from within `bin` looks like this:

```sh
get_permanent_max_stops -p 'oracle_password'
```  

#### fetch OpenStreetMap streets and trails and write them to shapefile
To carry out this task execute `osm_hwys_to_shp` which is located in `bin`.  This script uses the `overpass` module to fetch OpenStreetMap streets and trails and converts and writes them to shapefile with fiona and shapely.  The type of ways that are retrived from OSM as well as the bounding box used is configurable, see details on rgeoptions by appending the  `--help` parameter to the script call.

#### create network dataset with ArcGIS Network Analyst
This console script is named `create_network` and again is in `bin`.  The code here uses takes the OSM shapeifle from the previous step use the `comtypes` module and `ArcObjects` COM objects to create the Network Dataset.  This, more complicated approach is taken because a Network Dataset can't be created via `arcpy` (as of 5/2016).

Once the Network Dataset has finished building, load it into ArcMap and use the inspect tool to ensure that the proper restrictions are in place.  For instance, routing should be marked as prohibited on freeways and where else that OpenStreetMap tags prohibit pedestrians.

#### create isochrones
The script `create_isochrones` located in `bin` creates walk shed polygons (aka isochrones) that encapsulate the areas that can reach a given MAX stop by walking a supplied maximum distance (0.5 miles by default) or less when traveling along the existing street and trail network.  ArcGIS Network Analyst use's the network dataset from the last step to create these.  Use the `-d` parameter to set the walk distance in feet if you wish to deviate from the default of 2640.

Once the isochrones shapefile has been created bring it into a desktop GIS and sort the features by the area (ascending).  Examine the polygons with the smallest areas and if any of them appear to be suspiciously undersized then compare them to the OSM street and trail network to check for errors there.

#### geoprocess property data with PostGIS and generate final stats
This final script called `get_stats_via_postgis.sh` is found in the `sh` directory.  The tasks that it carries out begin with loading all of the shapefiles that have been created (and other RLIS shp's) into to PostGIS.  From here the tax lot dataset is processed such that properties that are at least 80% covered by parks, natural areas, cemeteries or golf courses are removed from consideration for inclusion in the total value of development. Tax lots that are in the right-of-way or under water are also extracted.  Next, additional information about the development year of properties, that has been acquired from regional agencies, is added.  Last, using the isochrones, properties that were built since the decision to build nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

After this script has completed, to validate the results, examine the tax lot and multi-family housing spatial tables in a desktop GIS to ensure that the geoprocessing has been executed correctly.


## Metadata for Statistics
The final output of the master script is a csv containing statistics, that is then manually converted to xlsx, formatted and annotated.  The following are clarifications of the meaning some of the more ambiguous terms used with that document:

* `minus max` 
With the excel workbooks there are two sheets that contain variants of the statistics: one label "w/ near max
* `(not in) max walk shed`
* `max zones`


