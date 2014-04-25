::@echo off
setlocal EnableDelayedExpansion

::Set postgres parameters
set pg_host=localhost
set db_name=osmosis_ped
set pg_uname=postgres

::Prompt the user to enter their postgres password
set /p pg_pword="Enter postgres password: "

::Drop the osmosis_ped database if it exists
dropdb --if-exists -h %pg_host% -U %pg_uname% -W %pg_pword% %db_name%

::Create database 'osmosis_ped' on the local instance of postgres using the postgis template
createdb -O %pg_uname% -T postgis_21_template -h %pg_host% -U %pg_uname% -W %pg_pword% %db_name%

::Run the pg_simple_schema osmosis script on the new database to establish a schema that osmosis
::can import osm data into.  The file path below is in quotes to properly handled the spaces that
::are in the name
set osmosis_schema_script="C:/Program Files (x86)/Osmosis/script/pgsimple_schema_0.6.sql"

psql -h %pg_host% -d %db_name% -U %pg_uname% -W %pg_pword% -f %osmosis_schema_script%

::Run osmosis on the GeoFrabrik extract that Frank downloads nightly.  Only includes features that
::one or more of the tags in the 'osm_tags' varaible below and only preserve that tags that are
::named in the tagtransform.xml file.  Also be sure to indicate the schema that osmosis is importing
::into, in this case it's the pg_simple_schema that was created by the script that was run above
set osm_tags=highway.motorway, ^
	highway.motorway_link, ^
	highway.trunk, ^
	highway.trunk_link, ^
	highway.primary, ^
	highway.primary_link, ^
	highway.secondary, ^
	highway.secondary_link, ^
	highway.tertiary, ^
	highway.tertiary_link, ^
	highway.residential, ^
	highway.residential_link, ^
	highway.unclassified, ^
	highway.service, ^
	highway.track, ^
	highway.road, ^
	highway.construction, ^
	highway.footway, ^
	highway.pedestrian, ^
	highway.path, ^
	highway.cycleway, ^
	highway.bridleway, ^
	highway.steps

set osm_data=G:/PUBLIC/OpenStreetMap/data/osm/or-wa.osm
set tag_transform=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/github/dev-near-lightrail/osmosis/tagtransform.xml

osmosis --read-xml %osm_data% --wkv keyValueList=%osm_tags% --tt %tag_transform% --write-pgsimp-0.6 user=%pg_uname% password=%pg_pword% database=%db_name%

::Run the 'compose_trails' sql script, this will build all streets and trails from the decomposed
::osmosis osm data, the output will be inserted into a new table called 'streets_and_trails'.
::This script will also reproject the data to Oregon State Plane North (2913)
set make_paths_script=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/github/dev-near-lightrail/osmosis/compose_trails.sql

psql -h %pg_host% -d %db_name% -U %pg_uname% -f %make_paths_script%

::Export the street and trails table to a shapefile
set /p shapefile_out="Enter file path to save shapefile: "
set table_name=streets_and_trails

pgsql2shp -k -h %pg_host% -u %pg_uname% -P %pg_pword% -f %shapefile_out% %db_name% %table_name%