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

# The path to the initial script (used to resolve the actual directory)
# Resolve the script path to handle symbolic links
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done

# Variable to hold the resolved script path
export WUNDERIO_GLOBAL_SCRIPT_ROOT="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Use the function to get the directory of the script
# Make WUNDERIO_GLOBAL_SCRIPT_ROOT available.
# Expose helpers to tooling.
source "$WUNDERIO_GLOBAL_SCRIPT_ROOT/_helpers.sh"

# Remove the first argument (the method)
script_or_hook="$1"
shift 1

# Check if the string is neither tooling nor hooks.
if [[ "$script_or_hook" != "tooling" && "$script_or_hook" != "hooks" ]]; then
    display_error_message "wdr-core [tooling|hooks] script-name"
    exit 1
fi

# Remove the second argument (the script)
script_name="$1"
shift 1

# Legacy support for older scripts.
app_root_customs="$DDEV_APPROOT/.ddev/wunderio/custom"
legacy_custom_script="$app_root_customs/$script_or_hook-$script_name"
custom_script="$app_root_customs/$script_or_hook/$script_name"

# Sometimes this script is run on the host, sometimes inside the DDEV container
# so we need to check the directory to determine where the script is
# running from. Mostly it's in the container, but at least one time in
# config.wunderio.yaml we call it on the host via exec-host.
core_script="$WUNDERIO_GLOBAL_SCRIPT_ROOT/$script_or_hook/$script_name"

echo "$legacy_custom_script";
# Check if the custom script exists and is executable
if [ -x "$legacy_custom_script" ]; then
    display_status_message "Running custom script: $legacy_custom_script"
    display_warning_message "This script runs on legacy hooks"
    display_warning_message "  Consider to moving it into .ddev/wunderio/custom/$script_or_hook/$script_name"
    # Run the script and pass all remaining arguments.
    "$legacy_custom_script" "$@"
elif [ -x "$custom_script" ]; then
    display_status_message "Running custom script: $custom_script"
    # Run the script and pass all remaining arguments.
    "$custom_script" "$@"
elif [ -x "$core_script" ]; then
    # If the custom script doesn't exist, run the core script.
    display_status_message "Running core script: $core_script"
    # Run the script and pass all remaining arguments.
    "$core_script" "$@"
else
    display_error_message "Script not found or not executable: $script_name"
    exit 1
fi
