#!/usr/bin/env bash

#ddev-generated

## Description: Runs drush phpcs commands.
## Usage: phpcs
## Example: "ddev phpcs"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

# Save the existing arguments to an array
args=("$@")

if [ ! -f "$DDEV_APPROOT/phpcs.xml" ]; then
  # Add new arguments to the array
  args+=("--standard=WunderAll")
  echo "Defaulting to running with WunderAll coding standard".
fi

$DDEV_COMPOSER_ROOT/vendor/bin/phpcs "${args[@]}"
