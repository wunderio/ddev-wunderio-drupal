#!/usr/bin/env bash

#ddev-generated

## Description: Runs PHPUnit commands.
## Usage: phpunit
## Example: "ddev phpunit"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

"$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_run-scripts.sh" tooling-phpunit.sh "$@"
