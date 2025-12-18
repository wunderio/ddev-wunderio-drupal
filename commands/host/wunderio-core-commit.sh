#!/usr/bin/env bash

#ddev-generated

## Description: Generate AI commit message from staged changes (path-aware)
## Usage: commit [model]
## Example: ddev commit gpt-4o-mini
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

set -euo pipefail

source "$HOME/.ddev/wunderio/core/_helpers.sh"

# Host-side current directory.
HOST_PWD="$PWD"

# Find DDEV project root by looking for .ddev directory.
# Walk up from current directory until we find it.
PROJECT_ROOT="$HOST_PWD"
while [ "$PROJECT_ROOT" != "/" ]; do
  if [ -d "$PROJECT_ROOT/.ddev" ]; then
    break
  fi
  PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

# If we didn't find .ddev, fall back to script-based detection
if [ "$PROJECT_ROOT" == "/" ]; then
  # Resolve project root from this script location (for add-on installations)
  PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
fi

# Safety Check: Ensure we actually found a DDEV project.
# If we didn't, PROJECT_ROOT might be "/" or some arbitrary system path.
if [ ! -d "$PROJECT_ROOT/.ddev" ]; then
  display_error_message "❌ Error: Could not determine DDEV project root." >&2
  echo "   Ensure you are running this command from within a DDEV project" >&2
  echo "   or that the script is installed correctly in .ddev/commands/..." >&2
  exit 1
fi

# Compute path relative to project root, if possible.
REL_PATH="${HOST_PWD#$PROJECT_ROOT/}"

# Default container project root used by DDEV.
CONTAINER_ROOT="/var/www/html"

if [ "$REL_PATH" != "$HOST_PWD" ] && [ -n "$REL_PATH" ]; then
  # We're inside the project tree; mirror the path inside the container.
  TARGET_PATH="${CONTAINER_ROOT}/${REL_PATH}"
else
  # Fallback: use the project root inside the container.
  TARGET_PATH="${CONTAINER_ROOT}"
fi

# Run the internal web command inside the container, passing the target path
# as the first argument so that it can cd to the correct directory before
# generating the commit message.
ddev wunderio-core-commit-internal "$TARGET_PATH" "$@"
