#!/bin/bash

## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11
## #ddev-generated

## Description: Run PHP Code Beautifier and Fixer
## Usage: phpcbf [options] [path]
## Example: "ddev phpcbf" or "ddev phpcbf web/modules/custom"

# Save the existing arguments to an array
args=("$@")

if [ ! -f "$DDEV_APPROOT/phpcs.xml" ]; then
  # Add new arguments to the array
  args+=("--standard=WunderAll")
  echo "Defaulting to running with WunderAll coding standard".
fi

$DDEV_COMPOSER_ROOT/vendor/bin/phpcbf "$@"
