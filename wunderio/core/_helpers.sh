#!/bin/bash

#
# Helper functions.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# Function to display status message
display_status_message() {
    local color_green="\033[38;5;70m"
    local color_reset="\033[0m"
    local message="$1"

    printf "${color_green}${message}${color_reset}\n"
}

# Function to display error message
display_error_message() {
    local color_red="\033[0;31m"
    local color_reset="\033[0m"
    local message="$1"

    printf "${color_red}${message}${color_reset}\n"
}
