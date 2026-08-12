#!/usr/bin/env bash

#ddev-generated

## Description: Import a local database dump from database_dumps/ (interactive picker).
## Usage: importdb
## Example: "ddev importdb" "ddev importdb cleaned.sql.gz" "ddev importdb --no-deploy" "ddev importdb --skip-hooks"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

DDEV_GLOBAL="$(ddev version | grep global-ddev-dir | awk '{print $2}')"
export PATH="${DDEV_GLOBAL}/homeadditions/wunderio/core/${PATH:+:$PATH}"

wdr-core.sh tooling importdb.sh "$@"
