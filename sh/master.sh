#!/usr/bin/env bash
# launches a series of script that comprise the development around
# light rail project

set -e
CODE_DIR=$( cd $(dirname "${0}"); dirname $(pwd -W) )

GET_MAX_STOPS="${CODE_DIR}/bin/get_max_stops"
GET_OSM_SHP="${CODE_DIR}/bin/osm2routable_shp"
CREATE_NETWORK="${CODE_DIR}/bin/create_network"
CREATE_ISOCHRONES="${CODE_DIR}/bin/create_isochrones"
GET_PROPERTY_STATS="${CODE_DIR}/sh/get_property_stats_via_postgis.sh"

process_options() {
    while getopts "ho:p:" OPTION; do
        case "${OPTION}" in
            h)
                usage
                exit 1
                ;;
            o)
                ORAPASSWORD="${OPTARG}"
                ;;
            p)
                export PGPASSWORD="${OPTARG}"
                ;;
        esac
    done

    # prompt for missing postgres password is handled in stats
    # generating shell script
    if [[ -z "${ORAPASSWORD}" ]]; then
        read  -s -p "Enter Oracle database password: " ORAPASSWORD
    fi
}

usage() {
cat << EOF
usage for script: $0

OPTIONS:
     -h     display help (this) message
    --o    oracle password
    --p    postgres password
EOF
}

main() {
    "${GET_MAX_STOPS}" -p "${ORAPASSWORD}"
    "${GET_OSM_SHP}"
    "${CREATE_NETWORK}"
    "${CREATE_ISOCHRONES}"
    "${GET_PROPERTY_STATS}"
}

process_options "$@"
main
