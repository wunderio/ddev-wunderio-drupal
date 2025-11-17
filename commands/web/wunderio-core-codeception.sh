#!/usr/bin/env bash

#ddev-generated

## Description: Runs codecept commands.
## Usage: codecept
## Example: "ddev codecept"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

if [ ! -f "$DDEV_COMPOSER_ROOT/vendor/bin/codecept" ]; then
  echo "Composer binaries for Codecept missing; exiting early."
  echo "You can install it with 'ddev composer require codeception/codeception --dev'."
  exit 0
fi

if [ ! -f "$DDEV_COMPOSER_ROOT/codeception.yml" ]; then
  echo "codeception.yml not found! Please run 'ddev codecept bootstrap'."
  exit 0
fi

$DDEV_COMPOSER_ROOT/vendor/bin/codecept "$@"
