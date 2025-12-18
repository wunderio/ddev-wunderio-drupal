#!/usr/bin/env bash

#ddev-generated

## Description: Internal command to generate AI commit message from staged changes
## Usage: wunderio-core-commit-internal [working-dir]
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

set -euo pipefail

# Optional first argument: absolute working directory (must be an absolute path
# in the container's filesystem, e.g., "/var/www/html").
WORKDIR="${1:-}"

if [ -n "$WORKDIR" ] && [[ "$WORKDIR" = /* ]]; then
  # Validate that the directory exists and is accessible before changing to it.
  if [ ! -d "$WORKDIR" ]; then
    echo "Error: Working directory does not exist: $WORKDIR" >&2
    exit 1
  fi
  if [ ! -r "$WORKDIR" ] || [ ! -x "$WORKDIR" ]; then
    echo "Error: Working directory is not accessible (missing read or execute permissions): $WORKDIR" >&2
    exit 1
  fi
  # Use the provided working directory.
  cd "$WORKDIR"
fi

"$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_run-scripts.sh" tooling-commit.sh
