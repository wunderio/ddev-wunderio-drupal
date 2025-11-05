#!/usr/bin/env bash

## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11
## #ddev-generated
## Description: Synchronise local database with production.
## Usage: syncdb
## Example: "ddev syncdb"


$DDEV_APPROOT/.ddev/wunderio/core/_run-scripts.sh tooling-syncdb.sh "$@"
