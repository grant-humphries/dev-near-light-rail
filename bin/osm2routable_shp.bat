@echo off
setlocal EnableDelayedExpansion

::Set project workspace information
set workspace=G:\PUBLIC\GIS_Projects\Development_Around_Lightrail
set code_workspace=%workspace%\github\dev-near-lightrail
set /p data_folder="Enter the name of the subfolder will be created for this iteration of the project (should be in 'YYYY_MM' format): "
set data_workspace=%workspace%\data\%data_folder%

::Set postgres parameters
set pg_host=localhost
set db_name=osmosis_ped
set pg_user=postgres

::Prompt the user to enter their postgres password, pgpassword is a keyword and will set 
::the password for all psotgres commands in this session
set /p pgpassword="Enter postgres password: "

::Drop the osmosis_ped database if it exists, 'i' prompts the user to confirm that they want to
::delete the database
dropdb -h %pg_host% -U %pg_user% --if-exists -i %db_name%

::Create database 'osmosis_ped' on the local instance of postgres using the postgis template
createdb -O %pg_user% -T postgis_21_template -h %pg_host% -U %pg_user% %db_name%

::Run the pg_simple_schema osmosis script on the new database to establish a schema that osmosis
::can import osm data into.  The file path below is in quotes to properly handled the spaces that
::are in the name
set osmosis_schema_script="C:\Program Files (x86)\Osmosis\script\pgsimple_schema_0.6.sql"

psql -h %pg_host% -d %db_name% -U %pg_user% -f %osmosis_schema_script%

::Run osmosis on the OSM GeoFrabrik extract that Frank downloads nightly. The output will only
::include features that have one or more of the tags in the file keyvaluelistfile.txt. This file
::contains osm tags as key-value pair separated by a period with on per line.  Only tags that are
::the tagtransform.xml file will be preserved on the features that are brought through.  Also be
::sure to indicate the schema that osmosis is importing into, in this case it's the pg_simple_schema
::that was created by the script run above
set osm_data=G:\PUBLIC\OpenStreetMap\data\osm\or-wa.osm

set key_value_list=%code_workspace%\osmosis\keyvaluelistfile.txt
set tag_transform=%code_workspace%\osmosis\tagtransform.xml

::TO DO!!!!!!!!!!: have osmosis clip the input data to a smaller bounding box, the Salem and Vancouver
::areas aren't needed

::Without 'call' command here this script will stop after the osmosis command
::See osmosis documentation here: http://wiki.openstreetmap.org/wiki/Osmosis/Detailed_Usage#Data_Manipulation_Tasks
::The or-wa.osm extract is being trimmed to roughly the bounding box of the trimet district
call osmosis ^
	--read-xml %osm_data% ^
	--wkv keyValueListFile=%key_value_list% ^
	--tt %tag_transform% ^
	--bounding-box left=-123.2 right=-122.2 top=45.7 bottom=45.2 ^
	--write-pgsimp-0.6 host=%pg_host% database=%db_name% user=%pg_user% password=%pgpassword% 

::Run the 'compose_paths' sql script, this will build all streets and trails from the decomposed
::osmosis osm data, the output will be inserted into a new table called 'streets_and_trails'.
::This script will also reproject the data to Oregon State Plane North (2913)
set build_paths_script=%code_workspace%\postgis\compose_paths.sql

psql -h %pg_host% -d %db_name% -U %pg_user% -f %build_paths_script%

::Export the street and trails table to a shapefile
set shapefile_out=%data_workspace%\osm_foot.shp
set table_name=streets_and_trails

pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% -f %shapefile_out% %db_name% %table_name%