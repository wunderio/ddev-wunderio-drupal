#!/bin/bash
#ddev-generated

#
# Helper functions.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# Function to display status message.
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

# Function to display warning message.
display_warning_message() {
    local color_yellow="\033[0;33m"
    local color_reset="\033[0m"
    local message="$1"

    printf "${color_yellow}${message}${color_reset}\n"
}

# Function to get the absolute path to the database_dumps/ directory.
get_database_dumps_dir() {
    echo "${PROJECT_ROOT}/database_dumps"
}
