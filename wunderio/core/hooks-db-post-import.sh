#!/bin/bash

#
# Helper script to run post-import db hook.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

source $DDEV_APPROOT/.ddev/wunderio/core/_helpers.sh

cd "$DDEV_APPROOT"

if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
  display_status_message "Skip db hooks after import"
  exit 0
fi

# Every import is treated as deployment
# Unified based on https://www.drush.org/12.x/deploycommand/.
drush updatedb --no-cache-clear -y || { display_error_message "Database update failed"; exit 1; }
drush sqlsan -y || { display_error_message "Database sanitization failed"; exit 1; }
drush cache:rebuild || { display_error_message "Cache rebuild failed"; exit 1; }
drush config:import -y || { display_error_message "Config import failed"; exit 1; }
drush cache:rebuild || { display_error_message "Final cache rebuild failed"; exit 1; }
drush deploy:hook || { display_error_message "Deploy hook failed"; exit 1; }

uli_link=$(drush uli)
display_status_message "Drupal is working, running drush uli: $uli_link"
