#!/usr/bin/env bash

#ddev-generated

## Description: Synchronise local database with a remote environment.
## Usage: syncdb
## Example: "ddev syncdb prod" "ddev syncdb prod --backup --no-deploy"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

export PATH="$HOME/.ddev/wunderio/core/${PATH:+:$PATH}"

wdr-core.sh tooling syncdb.sh "$@"
