#!/bin/bash

#ddev-generated

#
# Script to update the grumphp.yml file to use both Lando and DDEV on GIT commit.
#
# It's run on addon install, only if grumphp.yml exists and if it contains:
# EXEC_GRUMPHP_COMMAND: lando php
# This is the previous default we've used.
#

set -eu
if [ -n "${WUNDERIO_DEBUG:-}" ]; then
    set -x
fi
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/var/www/html/vendor/bin

# Path to the grumphp.yml file
config_file="grumphp.yml"

# Define the pattern to search for.
pattern="EXEC_GRUMPHP_COMMAND: lando php"

if [ -f "$config_file" ] && grep -q "$pattern" "$config_file"; then
    sed -i "s#$pattern#EXEC_GRUMPHP_COMMAND: \"[ -d .ddev/traefik/ ] \\&\\& GRUMPHP_COMMAND='ddev php' || GRUMPHP_COMMAND='lando php' \\&\\& \\$GRUMPHP_COMMAND\"#g" "$config_file"

    # Add a message to the user.
    color_red="\033[0;31m"
    color_reset="\033[0m"
    printf "${color_red}Added DDEV support to $config_file.\n"
    echo "Please re-init GrumPHP GIT hooks and add $config_file to GIT:"
    echo "ddev grumphp git:init"
    echo "git add $config_file"
    printf "${color_reset}"
fi
