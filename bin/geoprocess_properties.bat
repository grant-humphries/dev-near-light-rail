@echo off
setlocal EnableDelayedExpansion

::Set project workspaces
set workspace=G:\PUBLIC\GIS_Projects\Development_Around_Lightrail
set postgis_workspace=%workspace%\github\dev-near-lightrail\postgis

set /p data_folder="Enter the name of the sub-folder holding the data for this interation of the project (should be in the form 'YYYY_MM'): "
set data_workspace=%workspace%\data\%data_folder%

::Set postgres parameters
set pg_host=localhost
set db_name=transit_dev
set pg_user=postgres

::Prompt the user to enter their postgres password, 'pgpassword' is a keyword and will automatically
::set the password for most postgres commands in the current session
set /p pgpassword="Enter postgres password:"


::Execute functions
call:dropCreateDb
call:loadShapefiles
call:geoprocess_properties
call:generateStats
call:exportToCsv

::This line must be inplace or function below will run w/o being called
goto:eof



::---------------------------------------
:: ***Function section begins below***
::---------------------------------------

::Great info on writing functions in batch files here:
::http://www.dostips.com/DtTutoFunctions.php

:dropCreateDb
::Drop the database if it exists then (re)create it
echo "Creating database..."

dropdb -h %pg_host% -U %pg_user% --if-exists -i %db_name%
createdb -O %pg_user% -T postgis_21_template -h %pg_host% -U %pg_user% %db_name%

goto:eof


:loadShapefiles
::Load all shapefiles that will be used in the postgis analysis portion of the project
::using shp2pgsql
echo "Loading shapefiles into Postgres..."
echo "Start time is: %time:~0,8%"

::Set function variables
set trimet_path=G:\TRIMET
set rlis_path=G:\Rlis
set srid=2913

::Loading large, complex shapefiles like taxlots and multi-family housing can be time consuming,
::however using the -D parameter of can *greatly* improve performance, see link for details
::http://gis.stackexchange.com/questions/109564/what-is-the-best-hack-for-importing-large-datasets-into-postgis?utm_content=buffer6bdf0&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer
::The 'q' parameter on psql makes command line output less verbose

::max stops 
shp2pgsql -s %srid% -D -I %data_workspace%\max_stops.shp max_stops ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::walkshed polygons (isochrones)
shp2pgsql -s %srid% -D -I %data_workspace%\max_stop_isochrones.shp isochrones ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::taxlots
shp2pgsql -s %srid% -D -I %rlis_path%\TAXLOTS\taxlots.shp taxlots ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::multi-family housing
shp2pgsql -s %srid% -D -I %rlis_path%\LAND\multifamily_housing_inventory.shp multifamily ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::trimet service district boundary
shp2pgsql -s %srid% -D -I %trimet_path%\tm_fill.shp tm_district ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::city boundaries
shp2pgsql -s %srid% -D -I %rlis_path%\BOUNDARY\cty_fill.shp city ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::urban growth boundary
shp2pgsql -s %srid% -D -I %rlis_path%\BOUNDARY\ugb.shp ugb ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

goto:eof


:geoprocessProperties
::Run sql scripts that 
echo "Running geoprocessing sql scripts"
echo "Start time is: %time:~0,8%"

::Filter out properties that are parks, natural areas, cemeteries & golf courses
set filter_script=%postgis_workspace%\remove_natural_areas.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %filter_script%

echo.phase 1 complete... 

::Add project attributes to properties based on spatial relationships
set geoprocess_script=%postgis_workspace%\geoprocess_properties.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %geoprocess_script%

goto:eof


:generateStats
::Execute sql script that compiles project stats and generates final export tables
echo "Compiling final stats..."

set stats_script=%postgis_workspace%\compile_property_stats.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %stats_script%

goto:eof


:exportToCsv
::Write final output tables to csv
echo "Exporting stats to csv..."

::Create a folder to store the output
set csv_workspace=%data_workspace%\csv
if not exist %csv_workspace% mkdir %csv_workspace%

::Pipe the export command to psql as the variables below can't be expanded after one enters psql 
set stats_table1=pres_stats_w_near_max
echo \copy %stats_table1% to '%csv_workspace%\%stats_table1%.csv' csv header ^
	| psql -h %pg_host% -d %db_name% -U %pg_user%

set stats_table2=pres_stats_minus_near_max
echo \copy %stats_table2% to '%csv_workspace%\%stats_table2%.csv' csv header ^
	| psql -h %pg_host% -d %db_name% -U %pg_user%

goto:eof