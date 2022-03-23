#!/usr/bin/env bash

################
### ZappaBoy ###
################

#### USAGE:
# Create service config
# ./traefik-warden.sh create -p 8080 -d "magic.com" -s test

# Start service with docker-compose in folder
# ./traefik-warden.sh start -s test

# Start service defining docker-compose file
# ./traefik-warden.sh start -s test -f ./test-docker-compose.yaml
#------------------------------------------------------------------------------------------

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
config_dir="$WARDEN_ROOT/config"
global_config="$config_dir/global.yaml"
CREATE_MODE="create"
GENERATE_MODE="generate"
START_MODE="start"
STOP_MODE="stop"
MODES=("$CREATE_MODE" "$GENERATE_MODE" "$START_MODE" "$STOP_MODE")
DEFAULT_COMPOSE_PATH="$PWD/docker-compose.yaml"
WARDEN_PLACEHOLDER="warden-"
VERSION="1.0-beta"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") mode [-h] [-v] [-V] [-nc] [-p] port [-d] domain [-s] service [-f] file

JA-Traefik-Warder helps to manage services through Traefik

Available modes:

create              Create new service config in "$WARDEN_ROOT/config" starting from "$WARDEN_ROOT/config/template.yaml"
generate            Generate a new docker-compose.yaml with both global and service specific warden configurations
start               Automatically generate docker-compose, start service and clean docker-compose
stop                Automatically generate docker-compose, start service and clean docker-compose

Available options:

-h,  --help         Print this help and exit
-v,  --version      Print version
-V,  --verbose      Print script debug info
-nc, --no-color     Disable colors in logs
-p,  --port         Define port number for service creation
-d,  --domain       Define domain for service creation
-s,  --service      Define service name
-f,  --file         Define docker-compose.yaml file
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
    port=""
    domain=""
    service_name=""
    compose_file=""

    mode=${1-""}
    [[ ${MODES[*]} =~ ${mode} ]] && shift

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --version) die "Version $VERSION" ;;
        -V | --verbose) set -x ;;
        -nc | --no-color) NO_COLOR=1 ;;
        -p | --port)
            port=${2-"80"}
            shift
            ;;
        -d | --domain)
            domain=${2-"domain.com"}
            shift
            ;;
        -s | --service)
            service_name=${2-""}
            shift
            ;;
        -f | --file)
            compose_file=${2-""}
            shift
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    return 0
}

check_params() {
    [[ -z "$mode" ]] && die "No mode defined"
    [[ ${MODES[*]} =~ ${mode} ]] || die "Mode not recognized"
    [[ -z "$service_name" ]] && die "No service name defined" || service_config=$(readlink -f "$config_dir/$service_name.yaml")

    if [[ "$mode" != "$CREATE_MODE" ]]; then
        [[ -z "$compose_file" ]] && [ -f "$DEFAULT_COMPOSE_PATH" ] && compose_file="$DEFAULT_COMPOSE_PATH"
        [[ -z "$compose_file" ]] && die "No docker-compose.yaml defined" || compose_file=$(readlink -f "$compose_file")

        warden_docker_compose="$(dirname "$compose_file")/$WARDEN_PLACEHOLDER$(basename "$compose_file")"
    fi
}

print_options() {
    msg "${INFO}Mode: $mode${NOFORMAT}"
    msg "${INFO}Service name: $service_name${NOFORMAT}"
    msg "${INFO}Service config: $service_config${NOFORMAT}"
    msg "${INFO}Docker compose file: $compose_file${NOFORMAT}"
}

generate_docker_compose() {
    msg "${INFO}Generating docker compose${NOFORMAT}"
    merged_json=$(yq -s 'reduce .[] as $item ({}; . * $item)' "$global_config" "$service_config" "$compose_file")
    echo "$merged_json" | yq -y >"$warden_docker_compose"
}

start_docker_compose() {
    msg "${INFO}Starting service${NOFORMAT}"
    pushd "$(dirname "$warden_docker_compose")"
    docker-compose -f "$warden_docker_compose" up --build -d
    cat "$warden_docker_compose"
    popd
}

stop_docker_compose() {
    msg "${INFO}Stopping service${NOFORMAT}"
    pushd "$(dirname "$warden_docker_compose")"
    docker-compose -f "$warden_docker_compose" down
    cat "$warden_docker_compose"
    popd
}

create_service_config() {
    cp "$config_dir/template.yaml" "$service_config"
    sed -i "s/SERVICE_NAME_PLACEHOLDER/${service_name}/g" "$service_config"
    sed -i "s/DOMAIN_PLACEHOLDER/${domain}/g" "$service_config"
    sed -i "s/PORT_PLACEHOLDER/${port}/g" "$service_config"
}

clean_environment() {
    rm "$warden_docker_compose"
}

parse_params "$@"
setup_colors
check_params

msg "${INFO}Starting:${NOFORMAT}"
print_options

if [[ "$mode" == "$CREATE_MODE" ]]; then
    create_service_config
else
    generate_docker_compose
    [[ "$mode" == "$START_MODE" ]] && start_docker_compose
    [[ "$mode" == "$STOP_MODE" ]] && stop_docker_compose
    [[ "$mode" != "$GENERATE_MODE" ]] && clean_environment
fi
