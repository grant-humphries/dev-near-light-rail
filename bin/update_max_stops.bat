@echo off
setlocal EnableDelayedExpansion

::Prompt user for current project subfolder
set /p data_folder="Enter the name of the subfolder will be created for this iteration of the project (should be in 'YYYY_MM' format): "

::Set project workspace information
set workspace=G:\PUBLIC\GIS_Projects\Development_Around_Lightrail
set code_workspace=%workspace%\github\dev-near-lightrail
set data_workspace=%workspace%\data\%data_folder%

::Set path to data that will be used in multiple functions
set stops_csv=%data_workspace%\permanent_max_stops.csv

::Create folder for current iteration of project
if not exist %data_workspace% mkdir %data_workspace%

::Set postgres parameters
set oracle_db=HAWAII
set oracle_user=tmpublic
set p/ oracle_pass="Enter password for db:HAWAII, user:tmpublic"

::Execute functions
call:getCurrentMaxStops
call:stopsCsv2shp

goto:eof


::---------------------------------------
:: ***Function section begins below***
::---------------------------------------

:getPermanentMaxStops
::Get all max stops that are not permanently closed from the HAWAII oracle database

::Run a sql script using sqlplus
set stops_script=%code_workspace%\oracle\get_permanent_max_stops.sql
sqlplus %oracle_user%/%oracle_pass%@%oracle_db% @%stops_script% %stops_csv%

goto:eof


:stopsCsv2shp
::Convert the permanent max stops from csv to shapefile, the csv will first be cleaned
::to remove whitespace that was added as a byproduct od sqlplus's spool tool

::the last two variables called are parameters that will be used by the script
set csv2shp_script=%code_workspace%\arcpy\max_stops_csv2shp.py
python %csv2shp_script% %data_workspace% %stops_csv%

goto:eof