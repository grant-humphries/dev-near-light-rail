@echo off
setlocal EnableDelayedExpansion

::Set project workspace information
set workspace=G:\PUBLIC\GIS_Projects\Development_Around_Lightrail
set code_workspace=%workspace%\github\dev-near-lightrail
set /p data_folder="Enter the name of the subfolder will be created for this iteration of the project (should be in 'YYYY_MM' format): "
set data_workspace=%workspace%\data\%data_folder%

::Create folder for current iteration of project
if not exist %data_workspace% mkdir %data_workspace%

::Set postgres parameters
set pg_host=maps10.trimet.org
set db_name=trimet
set /p pg_user="Enter postgres username for maps10"


::Execute functions
call:getCurrentMax
call:orangeCsv2Shp

goto:eof


::---------------------------------------
:: ***Function section begins below***
::---------------------------------------

:getCurrentMax
::Get max stops currently in operation from maps10 and export them to a shapefile

::Create a new table that has only current max stops and the schema needed for this project
set max_stop_script=%code_workspace%\postgis\get_current_max_stops.sql
psql -h %pg_host% -U %pg_user% -d %db_name% -f %max_stop_script%

::Export the new table to shapefile
set shapefile_out=%data_workspace%\max_stops.shp
set table_name=max_stops
pgsql2shp -k -h %pg_host% -u %pg_user% -f %shapefile_out% %db_name% %table_name%

goto:eof


:orangeCsv2Shp
::Convert orange line MAX stops from csv to shapefile (this step will go away once orange
::MAX line is in service)

set csv2shp_script=%code_workspace%\arcpy\orange_stops_csv2shp.py
python %csv2shp_script%

goto:eof