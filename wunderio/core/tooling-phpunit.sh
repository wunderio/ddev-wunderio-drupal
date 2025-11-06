#!/bin/bash

#
# Helper script to run PHPUnit.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi
source $DDEV_APPROOT/.ddev/wunderio/core/_helpers.sh

if [ ! -f "$DDEV_APPROOT/phpunit.xml" ]; then
    echo "phpunit.xml not found! Please run 'ddev regenerate-phpunit-config'."
    exit 1
fi

$DDEV_COMPOSER_ROOT/vendor/bin/phpunit "$@"
