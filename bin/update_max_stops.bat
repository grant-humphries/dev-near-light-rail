@echo off
setlocal EnableDelayedExpansion

::Set project workspace information
set workspace=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail
set /p proj_folder="Enter the name of the subfolder will be created for this iteration of the project (should be in 'YYYY_MM' format): "
set pf_path=%workspace%/data/%project_folder%

::Create folder for current iteration of project
if not exist %pf_path% mkdir %pf_path%

::Set postgres parameters
set pg_host=maps10.trimet.org
set db_name=trimet
set pg_user=geoserve

::Prompt the user to enter their postgres password, pgpassword is a keyword and will set
::the password for all psotgres commands in this session
set /p pgpassword="Enter postgres password for db:trimet, u:geoserve: "

::Create a new table that has only current max stops and the schema needed for this project
set max_stop_script=%workspace%/github/dev-near-lightrail/postgis/get_current_max_stops.sql

psql -h %pg_host% -U %pg_user% -d %db_name% -f %max_stop_script%

::Export the new table to shapefile
set /p shapefile_out=%pf_path%/max_stops.shp
set table_name=max_stops

pgsql2shp -k -h %pg_host% -u %pg_uname% -P %pgpassword% -f %shapefile_out% %db_name% %table_name%