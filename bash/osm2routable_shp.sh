# !/bin/bash

# Set project workspace information
workspace="G:/PUBLIC/GIS_Projects/Development_Around_Lightrail"
code_dir="${workspace}/github/dev-near-lightrail"

echo "Enter the name of the subfolder will be created for this"
echo "iteration of the project (should be in 'YYYY_MM' format):"
read data_folder
set data_dir="${workspace}/data/${data_folder}"

# Set postgres parameters
pg_host=localhost
pg_dbname=osmosis_ped
pg_user=postgres

 # Prompt the user to enter their postgres password, PGPASSWORD is a keyword 
 # and will set the password for all psotgres commands in this session
echo "Enter postgres password for user $pg_user: "
read -s PGPASSWORD
export PGPASSWORD


createPostgisDb() {
    # Create a postgis and hstore enabled postgres database
    # (first deleting it if it exists)

    dropdb -h $pg_host -U $pg_user --if-exists -i $pg_dbname
    createdb -O $pg_user -h $pg_host -U $pg_user $pg_dbname

    q1="CREATE EXTENSION postgis;"
    psql -h $pg_host -U $pg_user$ -d $pg_dbname -c "$q1"

    q2="CREATE EXTENSION hstore;"
    psql -h $pg_host -U $pg_user -d $pg_dbname -c "$q2"
}

runOsmosis() {
    #Use osmosis to populate a postgis database with openstreetmap data

    # Run the pgsnapshot_schema osmosis script on the new database to establish
    # a schema that osmosis can import osm data into.  The file path below is in
    # quotes to properly handled the spaces that are in the name.  This schema
    # puts all osm tags into a single hstore column
    osmosis_pgsnapshot="C:/Program Files (x86)/Osmosis/script/pgsnapshot_schema_0.6.sql"
    psql -h $pg_host -d $pg_dbname -U $pg_user -f "$osmosis_pgsnapshot"

    #Run osmosis on the OSM extract that is downloaded nightly using the Overpass
    # API. The output will only include features that have one or more of the tags
    # in the file keyvaluelistfile.txt. This file contains osm tags as key-value
    # pairs separated by a period with one per line.  Only tags that are in the
    # tagtransform.xml file will be preserved on the features that are brought through.
    osm_data="G:/PUBLIC/OpenStreetMap/data/osm/or-wa.osm"
    key_value_list="${code_dir}/osmosis/keyvaluelistfile.txt"
    tag_transform="${code_dir}/osmosis/tagtransform.xml"

    # Without 'call' command here this script will stop after the osmosis command. The
    # or-wa.osm extract is being trimmed to roughly the bounding box of the trimet
    # district.  See osmosis documentation here:
    # http://wiki.openstreetmap.org/wiki/Osmosis/Detailed_Usage#Data_Manipulation_Tasks
    osmosis \
    --read-xml $osm_data -v \
    --wkv keyValueListFile="${key_value_list}" \
    --used-node \
    --tt "$tag_transform" \
    --bb left='-123.2' right='-122.2' bottom='45.2' top='45.7' \
        completeWays=yes \
    --write-pgsql host=$pg_host database=$pg_dbname \
        user=$pg_user password=$PGPASSWORD
}

buildStreetsPaths() {
    # Run the 'compose_paths' sql script, this will build all streets and trails
    # from the decomposed osmosis osm data, the output will be inserted into a new
    # table called 'streets_and_trails'.  This script will also reproject the data
    # to Oregon State Plane North (EPSG:2913)
    build_paths_script="${code_dir}/postgis/compose_paths.sql"
    psql -h $pg_host -d $pg_dbname -U $pg_user -f "$build_paths_script"
}

export2shp() {
    #Export the street and trails table to a shapefile
    shp="${data_dir}/osm_foot.shp"
    table=streets_and_trails
    pgsql2shp -k -h $pg_host -u $pg_user -P $PGPASSWORD -f "$shp" $pg_dbname $table
}


createPostgisDb;
runOsmosis;
buildStreetsPaths;
export2shp;