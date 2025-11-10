#!/bin/bash

#
# Wunderio/ddev-drupal package update check executed after DDEV has started.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

source /mnt/ddev-global-cache/wunderio/core/_helpers.sh

cd $DDEV_COMPOSER_ROOT

# Get the latest version of a package via Composer.
get_latest_version() {
    # Run composer show to get information about the package
    package_info=$(composer show wunderio/ddev-drupal --all)

    # Extract the versions and get the latest one.
    # Catches the version from this string:
    # versions : * 0.5.0, 0.4.0, 0.3.0
    version=$(echo "$package_info" | grep -oP '(?<=versions : \* ).*' | tr -d ' ' | cut -d ',' -f 1)

    # If version is empty, try another way where there is no * for latest version.
    # Catches the version from this string:
    # versions : 0.5.0, * 0.4.0, 0.3.0
    if [[ -z "$version" ]]; then
        version=$(echo "$package_info" | grep -oP '(?<=versions : ).*' | tr -d ' ' | cut -d ',' -f 1)
    fi

    # Remove leading and trailing spaces
    version=$(echo "$version" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    echo "$version"
}

# Get the current version of a package via Composer.
get_current_version() {
    # Check the installed version of the package
    current_version=$(composer show | grep 'wunderio/ddev-drupal' | awk '{print $2}')

    echo "$current_version"
}

# Get the current version from the first argument.
current_version=$(get_current_version)

# Get the latest version from Composer.
latest_version=$(get_latest_version)

# Compare the current version with the latest version.
# If they are the same, exit the script.
if [[ $current_version == $latest_version ]]; then
    exit 0
fi

# Prompt the user with a yes or no question.
# Separate the prompt from the rest of the output for
# better readability.
echo ""
display_status_message "A newer version of wunderio/ddev-drupal is available (current: $current_version, latest: $latest_version)."
display_status_message "See what's new: https://github.com/wunderio/ddev-drupal/releases"
read -rp "$(display_status_message "Do you want to update to the latest version? This will run 'composer require wunderio/ddev-drupal --dev' (yes/no): [y] ")" answer

# Convert the input to lowercase for case-insensitive comparison.
answer=${answer,,}
# If the answer is empty (user pressed Enter), default to "y".
answer=${answer:-y}

# Check the user's input and perform actions accordingly
if [[ $answer == "yes" ]] || [[ $answer == "y" ]]; then
    composer require wunderio/ddev-drupal --dev
    echo ""
    display_status_message "Staging the changes to GIT. "
    read -rp "$(display_status_message "wunderio/ddev-drupal is updated, let's now add changes to GIT. This will run 'git add .ddev/ composer.json composer.lock drush/sites/local.site.yml' (yes/no): [y] ")" answer2
    # Convert the input to lowercase for case-insensitive comparison.
    answer2=${answer2,,}
    # If the answer is empty (user pressed Enter), default to "y".
    answer2=${answer2:-y}
    if [[ $answer2 == "yes" ]] || [[ $answer2 == "y" ]]; then

        git add $DDEV_APPROOT/.ddev/ $DDEV_COMPOSER_ROOT/composer.json $DDEV_COMPOSER_ROOT/composer.lock $DDEV_COMPOSER_ROOT/drush/sites/local.site.yml
        display_status_message "Done! Please verify the staged changes and commit (git status / git commit)."
    else
        display_status_message "Skipping the GIT staging. You need to manually stage the changes to GIT."
    fi
else
    display_status_message "Skipping the wunderio/ddev-drupal update."
fi
