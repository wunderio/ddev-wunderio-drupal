#!/usr/bin/env bash

#ddev-generated

## Description: Synchronise local database with production.
## Usage: syncdb
## Example: "ddev syncdb"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

export PATH="$HOME/.ddev/wunderio/core/:$PATH"

wdr-core.sh tooling syncdb.sh "$@"
