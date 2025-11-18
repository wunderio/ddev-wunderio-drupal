#!/usr/bin/env bash

#ddev-generated

## Description: Run PHPStan code scanning tool.
## Usage: phpstan
## Example: "ddev phpstan"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

# Check that PHPStan is installed.
if [ ! -f "$DDEV_COMPOSER_ROOT/vendor/bin/phpstan" ]; then
  echo "Composer binaries for PHPStan missing; exiting early."
  echo "You can install it with 'ddev composer require phpstan/phpstan --dev'."
  exit 0
fi

# Check that phpstan.neon or phpstan.neon.dist exists.
if [ ! -f "$DDEV_COMPOSER_ROOT/phpstan.neon" ] && [ ! -f "$DDEV_COMPOSER_ROOT/phpstan.neon.dist" ]; then
  echo "phpstan.neon or phpstan.neon.dist not found! Please generate one to configure PHPStan."
  exit 0
fi

set -eu
$DDEV_COMPOSER_ROOT/vendor/bin/phpstan "$@"