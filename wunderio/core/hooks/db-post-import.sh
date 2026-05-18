#!/bin/bash
#ddev-generated

#
# Post-import database hook.
#
# Sanitizes the database after import and executes full deployment.
# Deployment can be skipped by placing a marker file at /mnt/wdr-hooks/.no-deploy
# (e.g. via `ddev syncdb <alias> --no-deploy`).

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

# Sanitize imported database (remove sensitive data).
drush sqlsan -y || { display_error_message "Database sanitization failed"; exit 1; }

if [[ -f /mnt/wdr-hooks/.no-deploy ]]; then
  rm -f /mnt/wdr-hooks/.no-deploy
  display_status_message "Skipping drush deploy (--no-deploy)."
else
  drush deploy -y || { display_error_message "Drupal deploy failed"; exit 1; }
fi

uli_link=$(drush uli)
display_status_message "Database imported and sanitized."
display_status_message "One-time login link: $uli_link"
