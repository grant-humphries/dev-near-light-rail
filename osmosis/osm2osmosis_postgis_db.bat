@echo off
setlocal EnableDelayedExpansion

::Set postgres parameters
set pg_host=localhost
set db_name=osmosis_ped
set pg_uname=postgres

::Prompt the user to enter their postgres password, pgpassword is a keyword and will set 
::the password for all psotgres commands in this session
set /p pgpassword="Enter postgres password: "

::Drop the osmosis_ped database if it exists, 'i' prompts the user to confirm that they want to
::delete the database
dropdb -h %pg_host% -U %pg_uname% -i --if-exists %db_name%

::Create database 'osmosis_ped' on the local instance of postgres using the postgis template
createdb -O %pg_uname% -T postgis_21_template -h %pg_host% -U %pg_uname% %db_name%

::Run the pg_simple_schema osmosis script on the new database to establish a schema that osmosis
::can import osm data into.  The file path below is in quotes to properly handled the spaces that
::are in the name
set osmosis_schema_script="C:/Program Files (x86)/Osmosis/script/pgsimple_schema_0.6.sql"

psql -h %pg_host% -d %db_name% -U %pg_uname% -f %osmosis_schema_script%

::Run osmosis on the OSM GeoFrabrik extract that Frank downloads nightly. The output will only
::include features that have one or more of the tags in the file keyvaluelistfile.txt. This file
::contains osm tags as key-value pair separated by a period with on per line.  Only tags that are
::the tagtransform.xml file will be preserved on the features that are brought through.  Also be
::sure to indicate the schema that osmosis is importing into, in this case it's the pg_simple_schema
::that was created by the script run above
set key_value_list=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/github/dev-near-lightrail/osmosis/keyvaluelistfile.txt
set osm_data=G:/PUBLIC/OpenStreetMap/data/osm/or-wa.osm
set tag_transform=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/github/dev-near-lightrail/osmosis/tagtransform.xml

::Withourt 'call' command here this script will stop after the osmosis command
call osmosis --read-xml %osm_data% --wkv keyValueListFile=%key_value_list% --tt %tag_transform% --write-pgsimp-0.6 user=%pg_uname% password=%pgpassword% database=%db_name%

::Run the 'compose_paths' sql script, this will build all streets and trails from the decomposed
::osmosis osm data, the output will be inserted into a new table called 'streets_and_trails'.
::This script will also reproject the data to Oregon State Plane North (2913)
set make_paths_script=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/github/dev-near-lightrail/osmosis/compose_paths.sql

psql -h %pg_host% -d %db_name% -U %pg_uname% -f %make_paths_script%

::Export the street and trails table to a shapefile
set /p shapefile_out="Enter output location for streets and trails shapefile: "
set table_name=streets_and_trails

pgsql2shp -k -h %pg_host% -u %pg_uname% -P %pgpassword% -f %shapefile_out% %db_name% %table_name%