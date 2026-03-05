#!/bin/bash
#ddev-generated

#
# Helper script to run post-import db hook.
#
# Only sanitizes the database after import. Full deployment steps
# (updatedb, config:import, cache:rebuild, deploy:hook) should be
# run deliberately via `ddev drush deploy`.
#
# Rationale: running cache:rebuild before config:import is dangerous
# when the imported DB has schema differences from the current codebase
# (see https://github.com/wunderio/charts/pull/514). Keeping this hook
# minimal also keeps `ddev import-db` fast for all use cases (restoring
# local backups, debugging specific DB states, etc.).
#

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

display_status_message "Database imported and sanitized."
