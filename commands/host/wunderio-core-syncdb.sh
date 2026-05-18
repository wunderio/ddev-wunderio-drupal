#!/usr/bin/env bash

#ddev-generated

## Description: Synchronise local database with a remote environment.
## Usage: syncdb
## Example: "ddev syncdb prod" "ddev syncdb prod --backup --no-deploy"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

DDEV_GLOBAL="$(ddev version | grep global-ddev-dir | awk '{print $2}')"
export PATH="${DDEV_GLOBAL}/homeadditions/wunderio/core/${PATH:+:$PATH}"

wdr-core tooling syncdb.sh "$@"
