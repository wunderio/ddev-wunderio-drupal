#!/usr/bin/env bash

## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11
## #ddev-generated
## Description: Runs codecept commands.
## Usage: codecept
## Example: "ddev codecept"

if [ ! -f "$DDEV_COMPOSER_ROOT/vendor/bin/codecept" ]; then
  echo "Composer binaries for Codecept missing; exiting early."
  exit 0
fi

$DDEV_COMPOSER_ROOT/vendor/bin/codecept "$@"
