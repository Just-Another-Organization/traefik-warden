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
services_dir="$WARDEN_ROOT/services"
templates_dir="$WARDEN_ROOT/templates"
global_config="$services_dir/global.yaml"
CREATE_MODE="create"
GENERATE_MODE="generate"
START_MODE="start"
STOP_MODE="stop"
SERVICES_MODE="services"
TEMPLATES_MODE="templates"
MODES=("$CREATE_MODE" "$GENERATE_MODE" "$START_MODE" "$STOP_MODE" "$SERVICES_MODE" "$TEMPLATES_MODE")
DEFAULT_COMPOSE_PATH="$PWD/docker-compose.yaml"
WARDEN_PLACEHOLDER="warden"
VERSION="1.0-beta"
TRUE='true'
FALSE='false'

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") mode [-h] [-v] [-V] [-nc] [-p] port [-d] domain [-s] service [-f] file

Warden helps to manage services through Traefik

Available modes:

create              Create new service config in "$WARDEN_ROOT/config" starting from "$WARDEN_ROOT/config/template.yaml"
generate            Generate a new docker-compose.yaml with both global and service specific warden configurations
start               Automatically generate docker-compose, start service and clean docker-compose
stop                Automatically generate docker-compose, start service and clean docker-compose
services            List available services
templates           List available templates

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
    service_name=""
    template_name="default"
    compose_file=""
    no_confirm=$FALSE

    mode=${1-""}
    [[ ${MODES[*]} =~ ${mode} ]] && shift

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --version) die "Version $VERSION" ;;
        -V | --verbose) set -x ;;
        -nc | --no-color) NO_COLOR=1 ;;
        -q | --no-confirm) no_confirm=$TRUE ;;
        -s | --service)
            service_name=${2-""}
            shift
            ;;
        -t | --template)
            template_name=${2-""}
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

    [[ -n "$mode" ]] && [[ -z "$service_name" ]] && service_name=${1-""}
    return 0
}

check_params() {
    [[ -z "$mode" ]] && die "No mode defined"
    [[ ${MODES[*]} =~ ${mode} ]] || die "Mode not recognized"
    [[ -z "$service_name" ]] && die "No service name defined" || service_config=$(readlink -f "$services_dir/$service_name.yaml")
    [[ -z "$template_name" ]] && die "No template name defined" || template_config=$(readlink -f "$templates_dir/$template_name.yaml")

    if [[ "$mode" != "$CREATE_MODE" ]]; then
        [[ -z "$compose_file" ]] && [ -f "$DEFAULT_COMPOSE_PATH" ] && compose_file="$DEFAULT_COMPOSE_PATH"
        [[ -z "$compose_file" ]] && die "No docker-compose.yaml defined" || compose_file=$(readlink -f "$compose_file")

        warden_docker_compose="$(dirname "$compose_file")/$WARDEN_PLACEHOLDER-$service_name-$(basename "$compose_file")"
    fi
}

print_options() {
    msg "${INFO}Mode: $mode${NOFORMAT}"
    msg "${INFO}Service name: $service_name${NOFORMAT}"
    msg "${INFO}Service config: $service_config${NOFORMAT}"
    msg "${INFO}Template config: $template_config${NOFORMAT}"
    msg "${INFO}Docker compose file: $compose_file${NOFORMAT}"
}

generate_docker_compose() {
    msg "${INFO}Generating docker compose${NOFORMAT}"
    merged_json=$(yq -s 'reduce .[] as $item ({}; . * $item)' "$global_config" "$service_config" "$compose_file")

    # Healthcheck property is not supported by Traefik
    merged_json=$(echo "$merged_json" | jq 'del(..|.healthcheck?)')
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
    yq '.content' "$template_config" | yq -y >"$service_config"
    placeholders=$(yq '.placeholders' "$template_config")

    echo "$placeholders" | jq -c '.[]' | while read -r i; do
        key=$(echo "$i" | jq -r 'keys | .[]')
        env_key_value="${!key:-""}"
        if [[ -z "$env_key_value" ]]; then
            default_value=$(echo "$i" | jq -r '.[]')
            value="$default_value"
            if [[ "$no_confirm" == "$FALSE" ]]; then
                read -r -p "${key} variable is not set, define a value (default: ${default_value}): " user_value </dev/tty
                if [[ -n "$user_value" ]]; then
                    value="$user_value"
                fi
            fi
        else
            value="$env_key_value"
        fi
        sed -i "s/$key/$value/g" "$service_config"
    done
}

clean_environment() {
    rm "$warden_docker_compose"
}

list_services() {
    ls "$services_dir"
}

list_templates() {
    ls "$templates_dir"
}

parse_params "$@"
setup_colors

if [[ "$mode" == "$SERVICES_MODE" ]]; then
    list_services
    die "Services listed"
fi

if [[ "$mode" == "$TEMPLATES_MODE" ]]; then
    list_templates
    die "Templates listed"
fi

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
