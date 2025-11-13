#!/bin/bash
#ddev-generated

#
# Helper script to run other scripts and allow overriding them by having the
# same file in .ddev/wunderio/custom folder.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# This script when ran in host, does not have the WUNDERIO_GLOBAL_CACHE_ROOT and
# WUNDERIO_GLOBAL_CACHE_WUNDERIO environment variables set. So we need to set
# them here.
GLOBAL_CACHE_ROOT="${WUNDERIO_GLOBAL_CACHE_ROOT:-/mnt/ddev-global-cache}"
GLOBAL_CACHE_WUNDERIO="${WUNDERIO_GLOBAL_CACHE_WUNDERIO:-$GLOBAL_CACHE_ROOT/wunderio}"

# Expose helpers to tooling.
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

script_name="$1"
# Remove the first argument (the script name) to get the remaining arguments
shift 1

custom_script="$DDEV_APPROOT/.ddev/wunderio/custom/$script_name"

# Sometimes this script is run on the host, sometimes inside the DDEV container
# so we need to check the directory to determine where the script is
# running from. Mostly it's in the container, but at least one time in
# config.wunderio.yaml we call it on the host via exec-host.
if [ -d "$GLOBAL_CACHE_ROOT" ]; then
  core_script="$GLOBAL_CACHE_WUNDERIO/core/$script_name"
else
  core_script="$HOME/.ddev/wunderio/core/$script_name"
fi

# Check if the custom script exists and is executable
if [ -x "$custom_script" ]; then
    display_status_message "Running custom script: $custom_script"
    # Run the script and pass all remaining arguments.
    "$custom_script" "$@"
elif [ -x "$core_script" ]; then
    # If the custom script doesn't exist, run the core script.
    display_status_message "Running core script: $core_script"

    # Run the script and pass all remaining arguments.
    "$core_script" "$@"
else
    echo "Script not found or not executable: $script_name"
    exit 1
fi
