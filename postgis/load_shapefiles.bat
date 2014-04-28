::Set postgres parameters
set pg_host=localhost
set db_name=transit_dev
set pg_user=postgres

::Prompt the user to enter their postgres password, 'pgpassword' is a keyword and will automatically
::set the password for most postgres commands in the current session
set /p pgpassword="Enter postgres password:"


::PROJECT DATA (these were created in earlier phases of the project, most are modified 
::versions of RLIS or TriMet data).  
::Set input parameters
set srid=2913

::Prompt the user to enter the name of the sub-folder holding current project datasets
set /p proj_folder="Enter the name of the sub-folder holding the data for this interation of the project (should be in the form 'YYYY_MM'): "
set proj_path=G:/PUBLIC/GIS_Projects/Development_Around_Lightrail/data/%proj_folder%

::MAX Stops 
shp2pgsql -s %srid% -d -I %proj_path%/max_stops.shp max_stops | psql -h %pg_host% -U %pg_user% -d %db_name%

::Walkshed Polygons (Isocrones)
shp2pgsql -s %srid% -d -I %proj_path%/max_stop_isocrones.shp isocrones | psql -h %pg_host% -U %pg_user% -d %db_name%

::Trimmed Taxlots
shp2pgsql -s %srid% -d -I %proj_path%/trimmed_taxlots.shp taxlot | psql -h %pg_host% -U pg_user% -d %db_name%

::Trimmed Multi-family Housing
shp2pgsql -s %srid% -d -I %proj_path%/trimmed_multifam.shp multi_family | psql -h %pg_host% -U pg_user% -d %db_name%


::TRIMET DATA
::Set path to data folder
set trimet_path=G:/TRIMET

::TriMet Service District Boundary
shp2pgsql -s %srid% -d -I %trimet_path%/tm_fill.shp tm_district | psql -h %pg_host% -U pg_user% -d %db_name%


::RLIS DATA
::Set path to data folder
set rlis_path=G:/Rlis

::City Boundaries
shp2pgsql -s %srid% -d -I %rlis_path%/BOUNDARY/cty_fill.shp city | psql -h %pg_host% -U pg_user% -d %db_name%

::Urban Growth Boundary
shp2pgsql -s %srid% -d -I %rlis_path%/BOUNDARY/ugb.shp ugb | psql -h %pg_host% -U pg_user% -d %db_name%