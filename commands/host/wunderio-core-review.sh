#!/usr/bin/env bash

#ddev-generated

## Description: Runs AI code review on branch changes via GitHub Copilot (agents container).
## Usage: review [target-branch]
## Example: "ddev review"
## Example: "ddev review develop"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

export PATH="$HOME/.ddev/wunderio/core/${PATH:+:$PATH}"

wdr-core.sh tooling review.sh "$@"
