#!/bin/bash
#ddev-generated

#
# Synchronise local database with a remote environment.
#
# Based on https://github.com/wunderio/unisport/blob/master/.lando/syncdb.sh
#

set -eu

if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# --- 1. Validate Input ---
# Check if an alias was provided as an argument.
if [[ -z "$1" ]]; then
  echo "Error: No site alias name provided."
  echo "Usage: $0 your_alias_name"
  echo "Example: $0 prod"
  exit 1
fi

# The alias key is the first argument, e.g., "prod" or "myproduction"
ALIAS_KEY="$1"
# The full alias required by Drush, which needs the "@" prefix, e.g., "@prod"
SITE_ALIAS="@${ALIAS_KEY}"

# --- Sourcing Helper Functions ---
# This is run in host context, so we need to use the home directory.
source "$HOME/.ddev/wunderio/core/_helpers.sh"

sql_file="${ALIAS_KEY}-syncdb-$(date +'%Y-%m-%d').sql"

# Read the remote alias details from drush configuration.
# We pass the full alias (@prod) to Drush.
if ! alias_details=$(ddev drush sa "$SITE_ALIAS" 2>&1); then
  # The command failed. The error message is now in the 'alias_details' variable.
  display_error_message "Drush command failed."

  # Print the actual error message from Drush for better debugging.
  echo "--------------------------------------------------"
  echo "$alias_details"
  echo "--------------------------------------------------"

  display_error_message "Please ensure the alias '$ALIAS_KEY' is defined in your project's drush/sites/self.site.yml file."
  exit 1 # Exit with a non-zero status code to indicate failure
fi

# --- 3. Parse Alias Details using yq ---
# Dynamically build the yq query path using the alias key ("prod").
prod_ssh_user=$(ddev yq '."@self.'"$ALIAS_KEY"'".user' <<< "$alias_details")
prod_ssh_host=$(ddev yq '."@self.'"$ALIAS_KEY"'".host' <<< "$alias_details")
prod_ssh_options=$(ddev yq '."@self.'"$ALIAS_KEY"'".ssh.options' <<< "$alias_details")

# --- 4. Perform the Database Dump and Import ---
display_status_message "Dumping database from '$SITE_ALIAS'..."

ssh "$prod_ssh_user@$prod_ssh_host" "$prod_ssh_options" "drush sql-dump --structure-tables-list=cache,cache_*,history,search_*,sessions" > "$sql_file"

display_status_message "Dump complete, starting import!"

ddev import-db --file="$sql_file"
rm "$sql_file"
{ set +x; } 2>/dev/null

display_status_message "Sync with '$SITE_ALIAS' complete!"
