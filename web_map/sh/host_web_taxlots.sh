#!/usr/bin/env bash

# create a version of the tax lot from the development around light
# rail project that will be used within a web map

set -e
export PGOPTIONS='--client-min-messages=warning'

# Set localhost postgres parameters
LH_HOST=localhost
LH_USER=postgres
LH_DBNAME=lightraildev

# Set maps7 postgres parameters
M7_HOST=maps7.trimet.org
M7_USER=geoserve
M7_DBNAME=trimet
M7_SCHEMA=misc_gis

# postgres passwords are pulled from pgpass.conf (.pgpass in linux)

# Assign other project variables
PROJECT_DIR="G:/PUBLIC/GIS_Projects/Development_Around_Lightrail"
CODE_DIR=$( cd $(dirname "${0}"); dirname $(pwd -W) )
DATA_DIR="${PROJECT_DIR}/web_map/shp"

TABLE='web_map_taxlots'
SHP="${DATA_DIR}/${TABLE}.shp"

create_web_map_taxlots() {
    web_taxlot_sql="${CODE_DIR}/sql/create_web_map_taxlots.sql"
    psql -w -h "${LH_HOST}" -U "${LH_USER}" -d "${LH_DBNAME}" \
        -v ON_ERROR_STOP=1 -v web_taxlots="${TABLE}" -f "${web_taxlot_sql}"
}

export_taxlots_to_shp() {
    pgsql2shp -k -h "${LH_HOST}" -u "${LH_USER}" -P "${LH_PASSWORD}" \
        -f "${SHP}" "${LH_DBNAME}" "${TABLE}"
}

load_to_pg_server() {
    schema_cmd="CREATE SCHEMA IF NOT EXISTS ${M7_SCHEMA};"
    psql -h "${M7_HOST}" -U "${M7_USER}" -d "${M7_DBNAME}" -c "${schema_cmd}"

    ospn_epsg=2913
    shp2pgsql -d -s "${ospn_epsg}" -D -I "${SHP}" "${M7_SCHEMA}.${TABLE}" \
        | psql -q -h "${M7_HOST}" -U "${M7_USER}" -d "${M7_DBNAME}"
}

main() {
    create_web_map_taxlots
    export_taxlots_to_shp
    load_to_pg_server
}

main
