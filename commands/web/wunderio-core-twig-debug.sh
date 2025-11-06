#!/usr/bin/env bash

#ddev-generated

## Description: Toggle Drupal Twig debugging.
## Usage: twig-debug [off]
## Example: "ddev twig-debug" to enable or "ddev twig-debug off" to disable
## AutocompleteTerms: ["off"]
## ExecRaw: true
## ProjectTypes: drupal9,drupal10,drupal11

# Function to check if twig debugging is enabled.
is_enabled() {
  if [ "$(drush php:eval "echo \Drupal::keyValue('development_settings')->get('twig_debug') ? 'true' : 'false';")" = "true" ]; then
    return 0
  else
    return 1
  fi
}

# Function to enable Twig debugging.
enable_twig_debug() {
  drush php:eval "\Drupal::keyValue('development_settings')->setMultiple(['disable_rendered_output_cache_bins' => TRUE, 'twig_debug' => TRUE, 'twig_cache_disable' => TRUE]);"
  echo "Enabled twig-debug"
  drush cr >/dev/null 2>&1
}

# Function to disable Twig debugging.
disable_twig_debug() {
  drush php:eval "\Drupal::keyValue('development_settings')->setMultiple(['disable_rendered_output_cache_bins' => FALSE, 'twig_debug' => FALSE, 'twig_cache_disable' => FALSE]);"
  echo "Disabled twig-debug"
  drush cr >/dev/null 2>&1
}

# Handle command parameters.
if [ "$1" = "off" ]; then
  disable_twig_debug
else
  if is_enabled; then
    echo "Twig debugging is already enabled"
  else
    enable_twig_debug
  fi
fi
