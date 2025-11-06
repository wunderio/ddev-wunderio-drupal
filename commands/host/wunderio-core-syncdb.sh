#!/usr/bin/env bash

#ddev-generated

## Description: Synchronise local database with production.
## Usage: syncdb
## Example: "ddev syncdb"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11


$DDEV_APPROOT/.ddev/wunderio/core/_run-scripts.sh tooling-syncdb.sh "$@"
