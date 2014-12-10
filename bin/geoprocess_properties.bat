@echo off
setlocal EnableDelayedExpansion

::Set project workspaces
set workspace=G:\PUBLIC\GIS_Projects\Development_Around_Lightrail
set git_workspace=%workspace%\github\dev-near-lightrail

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
call:createPostgisDb
call:loadShapefiles
call:addYearbuiltValues
call:geoprocessProperties
call:generateStats
call:exportToCsv

::This line must be in place or functions below will run w/o being called
goto:eof


::---------------------------------------
:: ***Function section begins below***
::---------------------------------------

::Great info on writing functions in batch files here:
::http://www.dostips.com/DtTutoFunctions.php

:createPostgisDb
::Drop the database if it exists then (re)create it and enable postgis
echo "1) Creating database..."

dropdb -h %pg_host% -U %pg_user% --if-exists -i %db_name%
createdb -O %pg_user% -h %pg_host% -U %pg_user% %db_name%

set q="CREATE EXTENSION postgis;"
psql -h %pg_host% -U %pg_user% -d %db_name% -c %q%

goto:eof


:loadShapefiles
::Load all shapefiles that will be used in the postgis analysis portion of the project
::using shp2pgsql
echo "2) Loading shapefiles into Postgres..."
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
shp2pgsql -d -s %srid% -D -I %data_workspace%\max_stops.shp max_stops ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::walkshed polygons (isochrones)
shp2pgsql -d -s %srid% -D -I %data_workspace%\max_stop_isochrones.shp isochrones ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::taxlots
shp2pgsql -d -s %srid% -D -I %rlis_path%\TAXLOTS\taxlots.shp taxlots ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::multi-family housing
shp2pgsql -d -s %srid% -D -I %rlis_path%\LAND\multifamily_housing_inventory.shp multifamily ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::outdoor recreation and conservations areas (orca)
shp2pgsql -d -s %srid% -D -I %rlis_path%\LAND\orca.shp orca ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::trimet service district boundary
shp2pgsql -d -s %srid% -D -I %trimet_path%\tm_fill.shp tm_district ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::city boundaries
shp2pgsql -d -s %srid% -D -I %rlis_path%\BOUNDARY\cty_fill.shp city ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::urban growth boundary
shp2pgsql -d -s %srid% -D -I %rlis_path%\BOUNDARY\ugb.shp ugb ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

goto:eof


:addYearbuiltValues
::Some additional year built data was provided by washington county for tax lots that
::have no data for that attribute in RLIS, this function adds that data to the rlis
::taxlots that are used for this analysis
echo "3) Adding yearbuilt values, where missing, "
echo "from supplementary data from Washington County"

set id_column=ms_imp_seg
set year_column=yr_built
set year_table=wash_co_missing_years
set r2t_table=rno2tlid

set year_csv=%git_workspace%\taxlot_data\wash_co_missing_years.csv
set r2t_dbf=%git_workspace%\taxlot_data\wash_missing_years_rno2tlid.dbf

::Drop table that holds washington county missing yearbuilt values if it exists
set drop_command="DROP TABLE IF EXISTS %year_table% CASCADE;"
psql -h %pg_host% -d %db_name% -U %pg_user% -c %drop_command%

::Create table to hold washington county missing year built data
set create_command="CREATE TABLE %year_table% (%id_column% text, %year_column% int) WITH OIDS;"
psql -h %pg_host% -d %db_name% -U %pg_user% -c %create_command%

::Populate washington county missing yearbuilt table with data from csv
echo \copy %year_table% from %year_csv% csv header ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::Load the dbf that has a mapping of account numbers (rno) to tax lot id's (tlid) 
shp2pgsql -d -n -D %r2t_dbf% %r2t_table% ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

::Add the missing years to the rlis taxlot data when the year is greater than what is in
::rlis (entries will have a value of 0 when there is no data)
set add_years_script=%git_workspace%\postgis\add_missing_yearbuilt.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -v yr_tbl=%year_table% -v r2t_tbl=%r2t_table% ^
	-v id_col=%id_column% -v yr_col=%year_column% -f %add_years_script%

goto:eof


:geoprocessProperties
::Run sql scripts that 
echo "4) Running geoprocessing sql scripts"
echo "Start time is: %time:~0,8%"

::Filter out properties that are parks, natural areas, cemeteries & golf courses
set filter_script=%git_workspace%\postgis\remove_natural_areas.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %filter_script%

echo "phase 4.1 complete, onto 4.2..."

::Add project attributes to properties based on spatial relationships
set geoprocess_script=%git_workspace%\postgis\geoprocess_properties.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %geoprocess_script%

goto:eof


:generateStats
::Execute sql script that compiles project stats and generates final export tables
echo "5) Compiling final stats..."

set stats_script=%git_workspace%\postgis\compile_property_stats.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %stats_script%

goto:eof


:exportToCsv
::Write final output tables to csv
echo "6) Exporting stats to csv..."

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