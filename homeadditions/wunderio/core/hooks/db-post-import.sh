#!/bin/bash
#ddev-generated

#
# Helper script to run post-import db hook.
#
# Sanitizes the database after import and executes full deployment.

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

source "$WUNDERIO_GLOBAL_SCRIPT_ROOT/_helpers.sh"

cd "$DDEV_APPROOT"

if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
  display_status_message "Skip db hooks after import"
  exit 0
fi

drush deploy -y || { display_error_message "Drupal deploy failed"; exit 1; }

uli_link=$(drush uli)
display_status_message "Database imported and sanitized."
display_status_message "One-time login link: $(drush uli)"
