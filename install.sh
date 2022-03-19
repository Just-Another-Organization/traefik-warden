#!/usr/bin/env bash

################
### ZappaBoy ###
################

# USAGE: ./install
#------------------------------------------------------------------------------------------

set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name='traefik-warden.sh'

install "$script_dir/$script_name" "$HOME/.local/bin/${script_name%.*}"
