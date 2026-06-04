#!/usr/bin/env bash

#ddev-generated

## Description: Runs AI code review on branch changes via GitHub Copilot (agents container).
## Usage: review [target-branch] [--model MODEL]
## Example: "ddev review"
## Example: "ddev review develop"
## Example: "ddev review --model gpt-5-mini"
## Example: "ddev review develop --model gpt-5.2"
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

export PATH="$HOME/.ddev/wunderio/core/${PATH:+:$PATH}"

wdr-core.sh tooling review.sh "$@"
