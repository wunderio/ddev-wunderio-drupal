#!/bin/bash
#ddev-generated

#
# Helper script to run web commands on first post start.
#
# This is run only if there's no vendor folder. There's no 'build'
# command as we have in Lando so we have this instead.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

source $DDEV_APPROOT/.ddev/wunderio/core/_helpers.sh
cd $DDEV_COMPOSER_ROOT
composer install
