#!/usr/bin/env bash

#ddev-generated

## Description: Synchronise local database with a remote environment.
## Usage: syncdb
## Example: "ddev syncdb prod" "ddev syncdb prod --backup --force --deploy"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:$HOME/.ddev/wunderio/core/

wdr-core.sh tooling syncdb.sh "$@"
