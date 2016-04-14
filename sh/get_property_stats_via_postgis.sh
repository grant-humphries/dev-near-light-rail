#!/usr/bin/env bash
# creates and loads a postgis database then calculates the value of
# development around light rail using sql scripts with spatial functions

# stop script on error and limit messages logged by postgres to warning
# or greater
set -e
export PGOPTIONS='--client-min-messages=warning'

# the code directory is two levels up from this script
CODE_DIR=$( cd $(dirname "${0}"); dirname $(pwd -P) )
POSTGIS_DIR="${CODE_DIR}/postgisql"
YR_BUILT_DIR="${CODE_DIR}/year_built_data"
PROJECT_DIR='/g/PUBLIC/GIS_Projects/Development_Around_Lightrail'
TRIMET_DIR='/g/TRIMET'
RLIS_DIR='/g/Rlis'

CITY="${RLIS_DIR}/BOUNDARY/cty_fill.shp"
MULTIFAMILY="${RLIS_DIR}/LAND/multifamily_housing_inventory.shp"
ORCA_SITES="${RLIS_DIR}/LAND/orca_sites.shp"
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

    # espg code of oregon state plane north projection
    ospn=2913

    # this array contains entries that are the shapefile path and the
    # name of the table comma separated
    shapefiles=(
        "${CITY}",'city'                "${ISOCHRONES}",''
        "${MAX_STOPS}",''               "${MULTIFAMILY}",'multifamily'
        "${ORCA_SITES}",''              "${TAXLOTS}",''
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

remove_natural_areas() {
    # Filter out properties that are parks, natural areas, cemeteries
    # and golf courses as well those that are street right-of-way or
    # parts of water bodies
    echo '3) removing natural areas, ROW from tax lots, start time is: '
    echo "$( date +%r ), execution time is ~25 minutes..."

    # the ON_ERROR_STOP parameter causes the sql script to stop if it
    # throws an error at any point
    filter_sql="${POSTGIS_DIR}/remove_row_and_natural_areas.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
        -v ON_ERROR_STOP=1 -f "${filter_sql}"
}

add_year_built_values() {
    # Some additional year built data was provided by Washington county
    # for tax lots that have no data for that attribute in rlis
    echo '4) Updating year built values with supplementary data from '
    echo 'Washington County'

    id_col='ms_imp_seg'
    year_col='yr_built'
    year_tbl='wash_co_year_built'
    year_csv="${YR_BUILT_DIR}/wash_co_year_built.csv"

    drop_cmd="DROP TABLE IF EXISTS ${year_tbl} CASCADE;"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${drop_cmd}"

    create_cmd="CREATE TABLE ${year_tbl}
               (${id_col} text PRIMARY KEY, ${year_col} int);"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${create_cmd}"

    csv_cmd="\copy ${year_tbl} FROM ${year_csv} CSV HEADER;"
    psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}" -c "${csv_cmd}"

    rno2tlid_tbl='rno2tlid'
    rno2tlid_dbf="${YR_BUILT_DIR}/wash_co_rno2tlid.dbf"

    shp2pgsql -d -n -D "${rno2tlid_dbf}" "${rno2tlid_tbl}" \
        | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"

    # Add the washington county year to the tax lots when the year is
    # missing or greater than the existing value
    add_years_sql="${POSTGIS_DIR}/add_missing_year_built.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
         -v wash_co_year="${year_tbl}" -v rno2tlid="${rno2tlid_tbl}" \
         -v id_col="${id_col}" -v year_col="${year_col}" \
         -v ON_ERROR_STOP=1  -f "${add_years_sql}"
}

get_taxlot_max_proximity() {
    echo '5) Determining spatial relationships between tax lots and max stops,'
    echo "ugb, trimet district and cities.  Start time is: $( date +%r )"

    # Add proximity attributes to properties based on spatial relationships
    geoprocess_sql="${POSTGIS_DIR}/geoprocess_properties.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
        -v ON_ERROR_STOP=1 -f "${geoprocess_sql}"
}

generate_stats() {
    # Execute sql script that compiles project stats and generates
    # final export tables
    echo '6) Compiling final stats...'

    stats_sql="${POSTGIS_DIR}/compile_property_stats.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
        -v ON_ERROR_STOP=1 -f "${stats_sql}"
}

export_to_csv() {
    echo '7) Exporting stats to csv...'

    mkdir -p "${CSV_DIR}"

    stats_tbls=( 'final_stats' 'final_stats_minus_max' )
    for tbl in "${stats_tbls[@]}"; do
        copy_cmd="\copy ${tbl} TO ${CSV_DIR}/${tbl}.csv CSV HEADER"
        psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${copy_cmd}"
    done
}

main() {
#    create_postgis_db
#    load_shapefiles
    remove_natural_areas
    add_year_built_values
    get_taxlot_max_proximity
    generate_stats
    export_to_csv
}

main
