#!/bin/bash
#ddev-generated

#
# Wunderio/ddev-wunderio-drupal package update check executed after DDEV has started.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# --- Sourcing Helper Functions ---
# This is run in host context, so we need to use the home directory.
source "$HOME/.ddev/wunderio/core/_helpers.sh"

# 1. Define the Addon Repository
ADDON_NAME="wunderio/ddev-wunderio-drupal"

# 2. Exit early if we have already checked today.
# We use a cache file to avoid checking multiple times in the same day.
# We minor startup time and reduce API calls to GitHub.
CACHE_FILE="/tmp/ddev_check_$(echo "$ADDON_NAME" | tr / _).txt"
TODAY=$(date +%Y-%m-%d)
if [ -f "$CACHE_FILE" ]; then
    # Read the date from the file. "|| true" prevents exit on EOF if file is empty
    read -r CACHED_DATE < "$CACHE_FILE" || true
    if [ "$CACHED_DATE" == "$TODAY" ]; then
        # We already ran the check today. Exit silently.
        exit 0
    fi
fi
# Mark today as checked immediately
echo "$TODAY" > "$CACHE_FILE"

# 3. Get the Installed Version
# We use --json-output. DDEV returns JSON objects; the actual list is usually in the "raw" field.
# select(.raw != null) ensures we ignore log messages and only parse the actual data.
LOCAL_VERSION=$(ddev add-on list --installed --json-output | \
ddev exec jq -r "select(.raw != null) | .raw[] | select(.Repository == \"$ADDON_NAME\") | .Version")

# If the local version is not found, exit.
# This probably means developer has installed the add-on manually using local
# copy of the add-on.
if [ -z "$LOCAL_VERSION" ] || [ "$LOCAL_VERSION" == "null" ]; then
    exit 0
fi

# 4. Get the Latest Remote Version from GitHub API
# 4.1. Try the BEST method (Official Stable Release)
REMOTE_VERSION=$(curl -s "https://api.github.com/repos/$ADDON_NAME/releases/latest" | ddev exec jq -r .tag_name)
# 4.2. If that returned null (repo has no official releases), use the BACKUP method (Latest Tag)
if [ "$REMOTE_VERSION" == "null" ] || [ -z "$REMOTE_VERSION" ]; then
    REMOTE_VERSION=$(curl -s "https://api.github.com/repos/$ADDON_NAME/tags" | ddev exec jq -r '.[0].name')
fi

if [ -z "$REMOTE_VERSION" ] || [ "$REMOTE_VERSION" == "null" ]; then
    echo "❌ Could not fetch release info from GitHub. Check your internet connection or API rate limits."
    exit 0
fi

# 5. Compare Versions
# Only print the header/footer if we are actually notifying the user
if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
    echo "------------------------------------------------"
    echo "📦 Addon: $ADDON_NAME"
    echo "🏠 Local Version:  $LOCAL_VERSION"
    echo "☁️  Latest Version: $REMOTE_VERSION"
    echo "------------------------------------------------"
    echo "⚠️  UPDATE AVAILABLE!"
    echo "To update, run:"
    echo "ddev add-on get $ADDON_NAME"
fi

exit 0
