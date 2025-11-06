#!/bin/bash
#ddev-generated

#
# Helper script to run GrumPHP.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi
source $DDEV_APPROOT/.ddev/wunderio/core/_helpers.sh

$DDEV_COMPOSER_ROOT/vendor/bin/grumphp "$@"
