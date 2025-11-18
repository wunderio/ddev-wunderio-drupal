#!/bin/bash
#ddev-generated

#
# Helper script to run PHPStan.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

source "$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_helpers.sh"

# Check that PHPStan is installed.
if [ ! -f "$DDEV_COMPOSER_ROOT/vendor/bin/phpstan" ]; then
  echo "Composer binaries for PHPStan missing; exiting early."
  echo "You can install it with 'ddev composer require phpstan/phpstan --dev'."
  exit 1
fi

# Check that phpstan.neon or phpstan.neon.dist exists.
if [ ! -f "$DDEV_COMPOSER_ROOT/phpstan.neon" ] && [ ! -f "$DDEV_COMPOSER_ROOT/phpstan.neon.dist" ]; then
  echo "phpstan.neon or phpstan.neon.dist not found! Please generate one to configure PHPStan."
  exit 1
fi

$DDEV_COMPOSER_ROOT/vendor/bin/phpstan "$@"