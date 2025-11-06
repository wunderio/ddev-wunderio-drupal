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

# Expose helpers to tooling.
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

script_name="$1"
# Remove the first argument (the script name) to get the remaining arguments
shift 1

custom_script=".ddev/wunderio/custom/$script_name"
core_script=".ddev/wunderio/core/$script_name"

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
