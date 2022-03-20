#!/usr/bin/env bash

################
### ZappaBoy ###
################

# USAGE: ./install
#------------------------------------------------------------------------------------------

set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name='traefik-warden.sh'
warden_root=${1-"$HOME/.warden"}

install "$script_dir/$script_name" "$HOME/.local/bin/${script_name%.*}"
mkdir -m755 -p "$warden_root"
cp -r "$script_dir/config" "$warden_root"

if ! grep -q "export WARDEN_ROOT=" "$HOME/.bashrc"; then
    cat << EOF >> "$HOME/.bashrc"

# Warden root
export WARDEN_ROOT=${warden_root}
EOF
fi
