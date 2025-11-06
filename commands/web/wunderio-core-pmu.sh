#!/usr/bin/env bash

#ddev-generated

## Description: Runs drush pmu commands but also creates dummy module folder if it does not exist.
## Usage: pmu
## Example: "ddev pmu module1 module2 ..."
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

$DDEV_APPROOT/.ddev/wunderio/core/_run-scripts.sh tooling-pmu.sh "$@"
