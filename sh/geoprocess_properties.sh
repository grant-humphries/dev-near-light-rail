#!/usr/bin/env bash
# creates and loads a postgis database then calculates the value of
# development around light rail using sql scripts with spatial functions

# the code directory is two levels up from this script
CODE_DIR=$( cd $(dirname "${0}"); dirname $(pwd -P) )
POSTGIS_DIR="${CODE_DIR}/postgisql"
PROJECT_DIR='/g/PUBLIC/GIS_Projects/Development_Around_Lightrail'
TRIMET_DIR='/g/TRIMET'
RLIS_DIR='/g/Rlis'

CITY="${RLIS_DIR}/BOUNDARY/cty_fill.shp"
MULTIFAMILY="${RLIS_DIR}/LAND/multifamily_housing_inventory.shp"
ORCA="${RLIS_DIR}/LAND/orca.shp"
TAXLOTS="${RLIS_DIR}/TAXLOTS/taxlots.shp"
TM_DISTRICT="${TRIMET_DIR}/tm_fill.shp"
UGB="${RLIS_DIR}/BOUNDARY/ugb.shp"

DATA_DIR="${PROJECT_DIR}/data/$( date -r ${TAXLOTS} +%Y_%m )"
CSV_DIR="${DATA_DIR}/csv"
SHP_DIR="${DATA_DIR}/shp"

ISOCHRONES="${SHP_DIR}/isochrones.shp"
MAX_STOPS="${SHP_DIR}/max_stops.shp"

# postgres parameters
HOST='localhost'
DBNAME='lightraildev'
USER='postgres'

if [[ -z "${PGPASSWORD}" ]]; then
    read  -s -p "Enter PostgreSQL password for user '${USER}': " PGPASSWORD
    export PGPASSWORD
fi


create_postgis_db() {
    echo '1) Creating database...'

    dropdb -h "${HOST}" -U "${USER}" --if-exists -i "${DBNAME}"
    createdb -h "${HOST}" -U "${USER}" "${DBNAME}"

    q="CREATE EXTENSION postgis;"
    psql -h "${HOST}" -U "${USER}" -d "${DBNAME}" -c "${q}"
}

load_shapefiles() {
    echo '2) Loading shapefiles into Postgres...'
    echo "Start time is: $( date +%r )"

    ospn=2913

    # this array contains entries that are the shapefile path and the
    # name of the table comma separated
    shapefiles=(
        "${CITY}",'city'                "${ISOCHRONES}",''
        "${MAX_STOPS}",''               "${MULTIFAMILY}",'multifamily'
        "${ORCA}",''                    "${TAXLOTS}",''
        "${TM_DISTRICT}",'tm_district'  "${UGB}",''
    )

    for shp_info in "${shapefiles[@]}"; do
        # split the items at the comma and assign to separate variables
        IFS=',' read shp_path tbl_name <<< "${shp_info}"

        # if a table name is not provided use the name of the shapefile
        if [[ -z "${tbl_name}" ]]; then
            tbl_name=$( basename "${shp_path}" .shp )
        fi

        shp2pgsql -d -s "${ospn}" -D -I "${shp_path}" "${tbl_name}" \
            | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"
    done
}

add_year_built_values() {
    # Some additional year built data was provided by Washington county
    # for tax lots that have no data for that attribute in rlis
    echo '3) Adding yearbuilt values, where missing, '
    echo 'from supplementary data from Washington County'

    id_col='ms_imp_seg'
    year_col='yr_built'
    year_tbl='wash_co_missing_years'
    year_csv="${CODE_DIR}/taxlot_data/wash_co_missing_years.csv"

    drop_cmd="DROP TABLE IF EXISTS ${year_tbl} CASCADE;"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${drop_cmd}"

    create_cmd="CREATE TABLE ${year_tbl} \
               (${id_col} text, ${year_col} int) WITH OIDS;"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${create_cmd}"

    echo "\copy ${year_tbl} FROM ${year_csv} CSV HEADER" \
        | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"

    rno2tlid_tbl='rno2tlid'
    rno2tlid_dbf="${CODE_DIR}/taxlot_data/wash_missing_years_rno2tlid.dbf"

    shp2pgsql -d -n -D "${rno2tlid_dbf}" "${rno2tlid_tbl}" \
        | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"

    # Add the missing years to the rlis tax lot data when the year is
    # greater than what is in rlis 
    add_years_sql="${POSTGIS_DIR}/add_missing_yearbuilt.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
         -v yr_tbl="${year_tbl}" -v r2t_tbl="${rno2tlid_tbl}" \
         -v id_col="${id_col}" -v yr_col="${year_col}" \
         -f "${add_years_sql}"
}

geoprocess_properties() {
    echo '4) Running geoprocessing sql scripts'
    echo "Start time is: $( date +%r )"

    # Filter out properties that are parks, natural areas, cemeteries
    # and golf courses
    filter_sql="${POSTGIS_DIR}/remove_natural_areas.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -f "${filter_sql}"

    echo 'natural areas removed, geoprocessing step two beginning...'

    # Add project attributes to properties based on spatial relationships
    geoprocess_sql="${POSTGIS_DIR}/geoprocess_properties.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -f "${geoprocess_sql}"

}

generate_stats() {
    # Execute sql script that compiles project stats and generates
    # final export tables
    echo '5) Compiling final stats...'

    stats_sql="${POSTGIS_DIR}/compile_property_stats.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -f "${stats_sql}"
}

export_to_csv() {
    # Write final output tables to csv
    echo '6) Exporting stats to csv...'

    mkdir -p "${CSV_DIR}"

    stats_tbls=( 'pres_stats_w_near_max' 'pres_stats_minus_near_max' )
    for tbl in "${stats_tbls[@]}"; do
        echo "\copy ${tbl} TO ${CSV_DIR}/${tbl}.csv CSV HEADER" \
            | psql -h "${HOST}" -d "${DBNAME}" -U "${USER}"
    done
}

main() {
#    create_postgis_db
    load_shapefiles
#    add_year_built_values
#    geoprocess_properties
#    generate_stats
#    export_to_csv
}

main
