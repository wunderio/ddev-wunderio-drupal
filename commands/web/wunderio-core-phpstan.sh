#!/usr/bin/env bash

#ddev-generated

## Description: Runs PHPStan commands.
## Usage: phpstan
## Example: "ddev phpstan analyze web/modules/custom"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

wdr-core tooling phpstan.sh "$@"
