## Overview
This project is comprised of scripts that automate the process of finding tax lots within network walking distance of light rail stops, determining the value of development that has occurred on those properties since the creation of the stop's light rail lines became public knowledge, and comparing that growth to other areas in the Portland metro region.  The initial piece of this analysis is to create isochrones: polygons that define the areas that can reach their corresponding stop by traveling the supplied distance (one half mile by default) or less.  The isochrones are created using ArcGIS `Network Analyst` and the network on which that tool executes routing is derived from [OpenStreetMap](osm.org).  The remaining data transformation and geoprocessing which fetches current light rail stops, determines tax lots that fall within the isochrones, filters out ineligible tax lots, and the tabulates figures for the comparison areas, is done with open source tools that include python packages `fiona`, `pyproj`, `shapely`, and `sqlalchemy` and sql scripts that utilize `PostGIS`.  The repo also contains a web map built with OpenLayers3 and Geoserver that visualizes the properties that fall into the varies categories defined by the analysis.

## Development Environment
The following languages/applications must be installed to execute the scripts in this repo:
* Python 2.7.x
* PostgreSQL with PostGIS 2.0+
* Bash 3.0+

Because the creation of the isochrones relies on ArcGIS this project must be carried out on a Windows machine.  The first two requirements are fairly easy to install on this operating system and I recommend getting [MinGW & MSYS](http://www.mingw.org/) to acquire a Bash-based shell.

#### Python package management
Python package dependencies are retrieved via `buildout`, however some of the GIS packages rely on C libraries ( fiona, `gdal`, pyproj, shapely) and will not compile properly and install with buildout on Windows.  To get these on Windows used the precompiled binaries found [here](http://www.lfd.uci.edu/~gohlke/pythonlibs/) or the package manager [`conda`](http://conda.pydata.org/docs/install/quick.html).  Last, `arcpy` is a requirement of the script that generates the isochrones.  To get this package one mut have ArcGIS Desktop license as well as access to a Network Analyst extension.

With the above dependencies in place the rest of the python packages will be taken care of with buildout.  Simply run `python bootstrap-buildout.py` (using a version of python that has the packages named in the paragraph above) to create project specific buildout.  The script creates several directories, one of which is `bin` and contains the buildout executable.  Launch buildout to create a project instance of python that will have all of the required packages as well as console scripts, all of which will be created in `bin`.  Alternatively, if you already have `zc.buildout` installed on the python instance that you're using, just enter the command `buildout` from the project's home directory to create a project python and the scripts.

## Script Execution
The entirety of this process can be carried out by launching a single shell script which in turn executes a series constituent console and shell scripts.  The parent script is called `master.sh` and is stored in the `sh` directory.  For details on what each of the child scripts do and how they can be executed individually see the sections below.


#### Update MAX stop data
The `get_max_stops` script in the `bin` directory uses sqlalchemy and TriMet's `TRANS` sqlalchemy model to fetch existing max stops.  It then uses fiona and shapely to write that data to a shapefile.  Database parameters can be passed to the script with flags, and use the `--help` flag to see available options.  An example of a call to this script from within `bin` looks like this:

```sh
get_permanent_max_stops -p 'oracle_password'
```  

#### Fetch OpenStreetMap streets and trails and write them to shapefile
To carry out this task execute `osm_hwys_to_shp` which is located in `bin`.  This script uses the `overpass` module to fetch OpenStreetMap streets and trails and converts and writes them to shapefile with fiona and shapely.  The type of ways that are retrieved from OSM as well as the bounding box used is configurable, see details on options by appending the  `--help` parameter to the script call.

#### Create network dataset with ArcGIS Network Analyst
This console script is named `create_network` and again is in `bin`.  The code here uses takes the OSM shapefile from the previous step use the `comtypes` module and `ArcObjects` COM objects to create the Network Dataset.  This, more complicated approach is taken because a Network Dataset can't be created via `arcpy` (as of 5/2016).

Once the Network Dataset has finished building, load it into ArcMap and use the inspect tool to ensure that the proper restrictions are in place.  For instance, routing should be marked as prohibited on freeways and where else that OpenStreetMap tags prohibit pedestrians.

#### Create isochrones
The script `create_isochrones` located in `bin` creates walk shed polygons (aka isochrones) that encapsulate the areas that can reach a given MAX stop by walking a supplied maximum distance (0.5 miles by default) or less when traveling along the existing street and trail network.  ArcGIS Network Analyst use's the network dataset from the last step to create these.  Use the `-d` parameter to set the walk distance in feet if you wish to deviate from the default of 2640.

Once the isochrones shapefile has been created bring it into a desktop GIS and sort the features by the area (ascending).  Examine the polygons with the smallest areas and if any of them appear to be suspiciously undersized then compare them to the OSM street and trail network to check for errors there.

#### Geoprocess property data with PostGIS and generate final stats
This final script called `get_stats_via_postgis.sh` is found in the `sh` directory.  The tasks that it carries out begin with loading all of the shapefiles that have been created (and other RLIS shp's) into to PostGIS.  From here the tax lot dataset is processed such that properties that are at least 80% covered by parks, natural areas, cemeteries or golf courses are removed from consideration for inclusion in the total value of development. Tax lots that are in the right-of-way or under water are also extracted.  Next, additional information about the development year of properties, that has been acquired from regional agencies, is added.  Last, using the isochrones, properties that were built since the decision to build nearby MAX stations are selected and stats are generated that compare growth in those areas to other urbanized regions in the Portland metropolitan area.

After this script has completed, to validate the results, examine the tax lot and multi-family housing spatial tables in a desktop GIS to ensure that the geoprocessing has been executed correctly.


## Metadata/Sources for Statistics
The final output of the master script is a csv containing statistics, that is then manually converted to xlsx, formatted and annotated.  The following are clarifications of the meaning some of the more ambiguous terms used with that document:

#### Group (column):
Within the group column two base types exist, properties groups of properties that have been influence by the development of the MAX lines and those, thos 
* Properties in MAX walk shed  
*This group consists of tax lots that are within network walking distance one or more MAX stops (network, meaning the distance traveled along streets and trails rather than as the crow flies) that have been developed since the decision to build the oldest MAX stop within walking range was made.  The network walk threshold is within is given in the Walk Distance column*
* Nine largest cities in TriMet District
* TriMet District
* Urban Growth Boundary

Variants of the latter three groups also exist, whose names end with ‘not in MAX walk shed’


#### MAX Zone (column):
MAX zones are derived from collections of consecutive stops that are within regions that have similar characteristics such as population density, walkability, etc.  The map below displays the division of stops into MAX zones.  

If a tax lot meets the construction date criteria for and is within walking distance of two or more stops that are in different MAX zones, then the value of that tax lot is included in the tabulation for both zones, but double counting is eliminated in the 'All Zones' rows.  For this reason adding up each of the MAX zones for 'Properties in MAX walk shed' will give you a different and larger number than what is in 'All Zones'.  



Parcels summed in rows with a 'Group' of 'Properties in MAX walk shed' are tax lots that are within 'Property Value' is the market value of these tax lots (land and building value) derived from the most current version (at the time that this analysis was conducted) of RLIS tax lots dataset.  

'Prop Value per Acre' for 'Properties in MAX walk shed' is derived by taking 'Property Value' and dividing it by the acreage of all tax lots within walking distance of MAX stops (not just the tax lots with recent construction that comprise the dollar value in 'Property Value').  Tax lots that are at least 80% covered by regions defined as Parks, Natural Areas, Cemeteries or Golf Courses by RLIS's 'Outdoor Recreation and Conservation Areas' dataset are excluded from all phases of this analysis.
 
To compare real estate development in areas near MAX stations to levels throughout the Portland metro region the similar statistics were compiled for three larger groups of properties: tax lots within the TriMet Service District Boundary, tax lots within the Urban Growth Boundary, and tax lots within the limits of the nine most populous cities in the TriMet district (Portland, Gresham, Hillsboro, Beaverton, Tualatin, Tigard, Lake Oswego, Oregon City, and West Linn).  To highlight construction for a similar time period as the properties summed in 'Properties in MAX walk shed' a '(MAX) decision to build year' was assigned to every tax lot in the three-county region.  This mapping was made by first determining which MAX stop was closest to each parcel and then assigning the decision to build year of that stop to the parcel (parcels were also given the 'MAX Zone' of their closest stop, so they could be broken up into sub-groups).  From there the same time-based criteria was applied to these properties as to those in station walk sheds: tax lots that have been developed in the same year or more recently than the nearest station's decision to build year were included in the 'Total Value' summation.  'Value per Acre' was then tabulated by dividing by the area of all tax lots in those regions (TriMet District, UGB, Nine Biggest Cities), excluding only the natural areas mentioned above.

#### New Multifamily Housing Units (column)
Multifamily housing units are collections of tax lots that comprise apartment complexes, condos, etc.  Values in this column are tabulated similarly to 'Property Value' field: for units to be included in the '...MAX walk shed' or comparison groups they needed to meet same criteria established for the 'Property Value' numbers.  Note however, that the 'Property Value' dollar figures are a valuation for both single family residences in addition to multi-family housing units, so the average value of a multifamily unit can *not* be derived from these two numbers.

#### Sources:  
* [OpenStreetMap](osm.org) (street and trail network)
* [Oregon Metro's RLIS](http://rlisdiscovery.oregonmetro.gov/) (tax lots, multifamily housing inventory, Outdoor Recreation and Conservation Areas, Urban Growth Boundary, city limits) 
* [TriMet GIS](http://developer.trimet.org/gis/) (rail stations, TriMet Service District boundary)


for a detailed account of the workflow used to derive these numbers see the README.md document here: https://github.com/grant-humphries/dev-near-light-rail


Note: See sheet one in this book for source information and an explanation of the statistics.  Numbers here were derived and are presented in exactly the same way as sheet one with a single key difference.  The comparison groups (TriMet District, UGB, Nine Biggest Cities) on sheet one include all tax lots (and multi-family housing units) inside the boundary that defines the region, here tax lots that are within walking distance of MAX (and thus comprise the 'Properties in MAX walk shed statistics) are excluded from the comparison groups.

