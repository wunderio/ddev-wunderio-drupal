#!/usr/bin/env bash

#ddev-generated

## Description: Generate AI commit message from staged changes (path-aware)
## Usage: commit [model]
## Example: ddev commit gpt-4o-mini
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

set -euo pipefail

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
