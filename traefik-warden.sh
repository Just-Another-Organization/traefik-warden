#!/usr/bin/env bash

################
### ZappaBoy ###
################

# USAGE: ./traefik-warder.sh
#------------------------------------------------------------------------------------------

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
TRUE='true'
FALSE='false'

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
    config_dir=""
    config_file=""

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -nc | --no-color) NO_COLOR=1 ;;
        -C | --config-dir)
            config_dir=${2-"$script_dir/config"}
            shift
            ;;
        -c | --service_name)
            config_file=${2-"example"}
            shift
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    if [ -z "$config_dir" ] && [ -z "$config_file" ]; then
        echo "SERVICE"
        service_config="${1-""}"
        config_path="$service_config"
    else
        echo "NO SERVICE"
        config_path="$config_dir/$config_file.yaml"
    fi

    config_path=$(readlink -f "$config_path")

    return 0
}

print_options() {
    msg "${INFO}Config directory: $config_dir${NOFORMAT}"
    msg "${INFO}Config file: $config_file${NOFORMAT}"
    msg "${INFO}Config path: $config_path${NOFORMAT}"
}

parse_params "$@"
setup_colors

msg "${INFO}Starting:${NOFORMAT}"
print_options
