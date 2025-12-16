#!/usr/bin/env bash

#ddev-generated

## Description: Internal command to generate AI commit message from staged changes
## Usage: wunderio-core-commit-internal [working-dir] [model]
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

set -euo pipefail

# Optional first argument: absolute working directory inside the container.
WORKDIR="${1:-}"

if [ -n "$WORKDIR" ] && [[ "$WORKDIR" = /* ]]; then
  # Use the provided working directory and shift so that any remaining
  # arguments (e.g. model name) are passed through to the tooling script.
  cd "$WORKDIR"
  shift
fi

"$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_run-scripts.sh" tooling-commit.sh "$@"
