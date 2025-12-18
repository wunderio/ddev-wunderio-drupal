#!/usr/bin/env bash

#ddev-generated

## Description: Internal command to generate AI commit message from staged changes
## Usage: wunderio-core-commit-internal [working-dir] [host-git-name] [host-git-email]
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

set -euo pipefail

# Optional first argument: absolute working directory (must be an absolute path
# in the container's filesystem, e.g., "/var/www/html").
WORKDIR="${1:-}"
HOST_GIT_NAME_ARG="${2:-}"
HOST_GIT_EMAIL_ARG="${3:-}"

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

# If the host provided a Git identity, propagate it to Git's standard
# environment variables so that commits made inside the container use
# the host user's name and email instead of the generic DDEV User.
if [ -n "$HOST_GIT_NAME_ARG" ]; then
  export GIT_AUTHOR_NAME="$HOST_GIT_NAME_ARG"
  export GIT_COMMITTER_NAME="$HOST_GIT_NAME_ARG"
fi

if [ -n "$HOST_GIT_EMAIL_ARG" ]; then
  export GIT_AUTHOR_EMAIL="$HOST_GIT_EMAIL_ARG"
  export GIT_COMMITTER_EMAIL="$HOST_GIT_EMAIL_ARG"
fi

"$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_run-scripts.sh" tooling-commit.sh
