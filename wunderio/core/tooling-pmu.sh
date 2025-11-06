#!/bin/bash

#
# Helper script to run pmu, but also create temporary module directory if it doesn't exist.
#

set -u
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi
source $DDEV_APPROOT/.ddev/wunderio/core/_helpers.sh

if [[ "$#" -lt 1 ]]; then
  echo "Usage: ddev pmu <module1> <module2> ..."
  exit 0
fi

modules="$1"

cd $DDEV_APPROOT

disable_module() {
    local module_name="$1"

    local module_path="$DDEV_DOCROOT/modules/custom/$module_name"

    # Check if the module directory exists.
    local module_exists=0
    if [ -d "$DDEV_DOCROOT/modules/contrib/$module_name" ] || [ -d "$module_path" ] || [ -d "$DDEV_DOCROOT/core/modules/$module_name" ]; then
        module_exists=1
    fi

    # Create dummy module if the module directory doesn't exist.
    if [ $module_exists -eq 0 ]; then
        mkdir -p "$module_path"
        echo "name: 'Dummy module created by ddev pmu'"    > "$module_path/$module_name.info.yml"
        echo "type: module"                               >> "$module_path/$module_name.info.yml"
        echo "core_version_requirement: ^9 || ^10 || ^11" >> "$module_path/$module_name.info.yml"
    fi

    # Clear caches to make the module available.
    drush cr

    # Run "drush pmu" command.
    echo "Disabling module $module_name..."
    drush pmu -y "$module_name"

    # Remove dummy module if it was created.
    if [ $module_exists -eq 0 ]; then
        rm -rf "$module_path"
    fi
}

for module in $*
do
  disable_module "$module"
done
