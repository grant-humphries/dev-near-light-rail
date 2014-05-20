@echo off
setlocal EnableDelayedExpansion

::Set project workspaces
set workspace=G:\PUBLIC\GIS_Projects\Development_Around_Lightrail
set code_workspace=%workspace%\github\dev-near-lightrail

set /p data_folder="Enter the name of the sub-folder holding the data for this interation of the project (should be in the form 'YYYY_MM'): "
set data_workspace=%workspace%\data\%data_folder%


::ERASE FROM PROPERTY DATASETS

::Run python script that erases water and natural areas from taxlots and multi_family housing units
python %code_workspace%\arcpy\trim_property.py %data_folder%

echo "Examine trimmed tax lot and multi-family housing layers to ensure erasures have executed properly"
echo "Press CTRL + C to cancel script or"
pause


::CREATE DB AND LOAD SHAPEFILES INTO POSTGIS

::Set postgres parameters
set pg_host=localhost
set db_name=transit_dev
set pg_user=postgres

::Prompt the user to enter their postgres password, 'pgpassword' is a keyword and will automatically
::set the password for most postgres commands in the current session
set /p pgpassword="Enter postgres password:"

::Drop the database if it already exists
dropdb -h %pg_host% -U %pg_user% --if-exists -i %db_name%

::Create a database called 'transit_dev' based on the postgis template
createdb -O %pg_user% -T postgis_21_template -h %pg_host% -U %pg_user% %db_name%

::Project Data (these were created in earlier phases of the project).  
::Set input parameters
set srid=2913

::MAX Stops 
shp2pgsql -s %srid% -d -I %data_workspace%\max_stops.shp max_stops | psql -h %pg_host% -U %pg_user% -d %db_name%

::Walkshed Polygons (Isochrones)
shp2pgsql -s %srid% -d -I %data_workspace%\max_stop_isochrones.shp isochrones | psql -h %pg_host% -U %pg_user% -d %db_name%

::Trimmed Taxlots
shp2pgsql -s %srid% -d -I %data_workspace%\trimmed_taxlots.shp trimmed_taxlots | psql -h %pg_host% -U %pg_user% -d %db_name%

::Trimmed Multi-family Housing
shp2pgsql -s %srid% -d -I %data_workspace%\trimmed_multifam.shp trimmed_multifam | psql -h %pg_host% -U %pg_user% -d %db_name%


::TriMet Data
::Set path to data folder
set trimet_path=G:\TRIMET

::TriMet Service District Boundary
shp2pgsql -s %srid% -d -I %trimet_path%\tm_fill.shp tm_district | psql -h %pg_host% -U %pg_user% -d %db_name%


::RLIS Data
::Set path to data folder
set rlis_path=G:\Rlis

::City Boundaries
shp2pgsql -s %srid% -d -I %rlis_path%\BOUNDARY\cty_fill.shp city | psql -h %pg_host% -U %pg_user% -d %db_name%

::Urban Growth Boundary
shp2pgsql -s %srid% -d -I %rlis_path%\BOUNDARY\ugb.shp ugb | psql -h %pg_host% -U %pg_user% -d %db_name%

echo "Examine the newly create database 'transit_dev' and ensure that all shapefiles have been imported correctly"
echo "Press CTRL + C to cancel script or"
pause


::GENERATE PROPERTY STATS AND SAVE TO CSV

::Select properties that meet criteria to be considered influenced bu MAX development and create 
::groups to compare the properties against
set select_props_script=%code_workspace%\postgis\select_and_compare_properties.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %select_props_script%

::Compile and format the property stats
set compile_stats_script=%code_workspace%\postgis\compile_property_stats.sql
psql -h %pg_host% -d %db_name% -U %pg_user% -f %compile_stats_script%

::Export the stats to CSV
set csv_workspace=%data_workspace%\csv
if not exist %csv_workspace% mkdir %csv_workspace%

::set stats_table1=pres_stats_w_near_max
::set stats_table2=pres_stats_minus_near_max

psql -h %pg_host% -d %db_name% -U %pg_user%

\copy pres_stats_w_near_max to 