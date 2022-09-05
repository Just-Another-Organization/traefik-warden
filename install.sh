#!/usr/bin/env bash

################
### ZappaBoy ###
################

# USAGE: ./install
#------------------------------------------------------------------------------------------

set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name='warden.sh'
warden_root=${1-"$HOME/.warden"}

install "$script_dir/$script_name" "$HOME/.local/bin/${script_name%.*}"
mkdir -m755 -p "$warden_root"
cp -r "$script_dir/services" "$script_dir/templates" "$warden_root"

if ! grep -q "export WARDEN_ROOT=" "$HOME/.bashrc"; then

    echo 'Remember to add the following to your $HOME/.bashrc or $HOME/.profile or equivalent'
    cat << EOF
# You can use the following command:
echo 'export WARDEN_ROOT="$HOME/.warden/"' >> $HOME/.bashrc
EOF
fi
