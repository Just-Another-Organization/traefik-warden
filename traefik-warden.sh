#!/usr/bin/env bash

################
### ZappaBoy ###
################

# USAGE: ./traefik-warder.sh
#------------------------------------------------------------------------------------------

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
config_dir="$WARDEN_ROOT/config"
TRUE='true'
FALSE='false'
START_MODE="start"
STOP_MODE="stop"
MODES=("$START_MODE" "$STOP_MODE")
DEFAULT_COMPOSE_PATH="$PWD/docker-compose.yaml"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v]

JA-Traefik-Warder helps to manage services through Traefik

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
EOF
    exit
}

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    NOFORMAT='\033[0m'
    msg "Exiting...${NOFORMAT}"
}

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        ORANGE='\033[0;33m'
        BLUE='\033[0;34m'
        PURPLE='\033[0;35m'
        CYAN='\033[0;36m'
        YELLOW='\033[1;33m'
        INFO="${BLUE}"
        WARNING="${YELLOW}"
        ERROR="${RED}"
        NOFORMAT='\033[0m'
    else
        NOFORMAT=''
        RED=''
        GREEN=''
        ORANGE=''
        BLUE=''
        PURPLE=''
        CYAN=''
        YELLOW=''
    fi
}

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    msg "$msg"
    exit "$code"
}

parse_params() {

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -nc | --no-color) NO_COLOR=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    mode=${1-""}
    service_name=${2-""}
    compose_file=${3-""}

    return 0
}

check_params() {
    [[ -z "$mode" ]] && die "No mode defined"
    [[ ${MODES[*]} =~ ${mode} ]] || die "Mode not recognized"
    [[ -z "$service_name" ]] && die "No service name defined" || service_config=$(readlink -f "$config_dir/$service_name")
    [[ -z "$compose_file" ]] && [ -f "$DEFAULT_COMPOSE_PATH" ] \
        && compose_file=$(readlink -f "$DEFAULT_COMPOSE_PATH") || die "No docker-compose.yaml defined"
}

print_options() {
    msg "${INFO}Mode: $mode${NOFORMAT}"
    msg "${INFO}Service name: $service_name${NOFORMAT}"
    msg "${INFO}Service config: $service_config${NOFORMAT}"
    msg "${INFO}Docker compose file: $compose_file${NOFORMAT}"
}

parse_params "$@"
setup_colors
check_params

msg "${INFO}Starting:${NOFORMAT}"
print_options
