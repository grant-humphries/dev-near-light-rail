#!/usr/bin/env bash
# creates and loads a postgis database then calculates the value of
# development around light rail using sql scripts with spatial functions

# stop script on error and limit messages logged by postgres to warning
# or greater
set -e
export PGOPTIONS='--client-min-messages=warning'

# the code directory is two levels up from this script, the -W option
# on pwd return a windows path as opposed to posix
CODE_DIR=$( cd $(dirname "${0}"); dirname $(pwd -W) )
POSTGIS_DIR="${CODE_DIR}/postgisql"
YR_BUILT_DIR="${CODE_DIR}/year_built_data"
PROJECT_DIR='G:/PUBLIC/GIS_Projects/Development_Around_Lightrail'
TRIMET_DIR='G:/TRIMET'
RLIS_DIR='G:/Rlis'

CITY="${RLIS_DIR}/BOUNDARY/cty_fill.shp"
MULTIFAMILY="${RLIS_DIR}/LAND/multifamily_housing_inventory.shp"
ORCA_SITES="${RLIS_DIR}/LAND/orca_sites.shp"
TAXLOTS="${RLIS_DIR}/TAXLOTS/taxlots.shp"
TM_DISTRICT="${TRIMET_DIR}/tm_fill.shp"
UGB="${RLIS_DIR}/BOUNDARY/ugb.shp"

DATE_DIR="${PROJECT_DIR}/data/$( date -r ${TAXLOTS} +%Y_%m )"
CSV_DIR="${DATE_DIR}/csv"
SHP_DIR="${DATE_DIR}/shp"

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
    echo $'\na) Creating database...'

    dropdb -h "${HOST}" -U "${USER}" --if-exists "${DBNAME}"
    createdb -h "${HOST}" -U "${USER}" "${DBNAME}"

    q="CREATE EXTENSION postgis;"
    psql -h "${HOST}" -U "${USER}" -d "${DBNAME}" -c "${q}"
}

load_shapefiles() {
    echo $'\nb) Loading shapefiles into Postgres, start time is:'
    echo "$( date +%r ), execution time is: ~6 minutes..."

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

filter_taxlots() {
    echo $'\nc) removing natural areas, ROW and parcels outside of the study'
    echo "area from tax lots, start time is: $( date +%r ), execution time"
    echo 'is: ~3 minutes...'

    # the ON_ERROR_STOP parameter causes the sql script to stop if it
    # throws an error at any point
    filter_sql="${POSTGIS_DIR}/filter_taxlots.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
        -v ON_ERROR_STOP=1 -f "${filter_sql}"
}

supplement_year_built() {
    # Some additional year built data was provided by Washington county
    # for tax lots that have no data for that attribute in rlis
    echo $'\nd) Updating year built values for tax lots with supplementary'
    echo $'data from Washington County...'

    id_col='ms_imp_seg'
    yr_col='yr_built'
    seg_tbl='wash_yr_seg'
    seg_csv="${YR_BUILT_DIR}/wash_year_ms_imp_seg.csv"

    drop_cmd="DROP TABLE IF EXISTS ${seg_tbl} CASCADE;"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${drop_cmd}"

    create_cmd="CREATE TABLE ${seg_tbl}
               (${id_col} text PRIMARY KEY, ${yr_col} int);"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${create_cmd}"

    csv_cmd="\copy ${seg_tbl} FROM ${seg_csv} CSV HEADER;"
    psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}" -c "${csv_cmd}"

    tlno_tbl='wash_yr_tlno'
    tlno_dbf="${YR_BUILT_DIR}/wash_year_tlno.dbf"

    shp2pgsql -d -n -D "${tlno_dbf}" "${tlno_tbl}" \
        | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"

    # Add the washington county year to the tax lots when the year is
    # missing or greater than the existing value
    add_years_sql="${POSTGIS_DIR}/supplement_year_built.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
         -v wash_yr_seg="${seg_tbl}" -v wash_yr_tlno="${tlno_tbl}" \
         -v id_col="${id_col}" -v yr_col="${yr_col}" \
         -v ON_ERROR_STOP=1  -f "${add_years_sql}"
}

get_property_proximity() {
    echo $'\ne) Determining spatial relationships between properties and max'
    echo 'stops, ugb, trimet district and cities.  Start time is: '
    echo "$( date +%r ), execution time is: ~5 minutes..."

    # Add proximity attributes to properties based on spatial relationships
    geoprocess_sql="${POSTGIS_DIR}/property_proximity.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
        -v ON_ERROR_STOP=1 -f "${geoprocess_sql}"
}

generate_stats() {
    echo $'\nf) Compiling final stats...'

    stats_sql="${POSTGIS_DIR}/compile_property_stats.sql"
    psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" \
        -v ON_ERROR_STOP=1 -f "${stats_sql}"
}

export_to_csv() {
    echo $'\ng) Exporting stats to csv...'

    mkdir -p "${CSV_DIR}"

    stats_tbls=( 'final_stats' 'final_stats_minus_max' )
    for tbl in "${stats_tbls[@]}"; do
        copy_cmd="\copy ${tbl} TO ${CSV_DIR}/${tbl}.csv CSV HEADER"
        psql -h "${HOST}" -d "${DBNAME}" -U "${USER}" -c "${copy_cmd}"
    done
}

main() {
    echo $'5) Beginning PostGIS loading and processing...\n'

    create_postgis_db
    load_shapefiles
    filter_taxlots
    supplement_year_built
    get_property_proximity
    generate_stats
    export_to_csv
}

# ran in ~14.5 minutes on 4/15/16
main
