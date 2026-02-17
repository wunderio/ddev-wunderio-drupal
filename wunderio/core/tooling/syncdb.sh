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

# --- Sourcing Helper Functions ---
source "$WUNDERIO_GLOBAL_SCRIPT_ROOT/_helpers.sh"

# --- 1. Validate Input ---
# Check if an alias was provided as an argument.
if [[ -z "${1:-}" ]]; then
  display_error_message "Error: No site alias name provided."
  display_warning_message "Usage: ddev syncdb your_alias_name"
  display_warning_message "Example: ddev syncdb prod"
  exit 1
fi

# The alias key is the first argument, e.g., "prod" or "myproduction"
ALIAS_KEY="$1"
# The full alias required by Drush, which needs the "@" prefix, e.g., "@prod"
SITE_ALIAS="@${ALIAS_KEY}"

shift 1

# If --keep-dump is passed, keep the dump file
KEEP_DUMP=false
for arg in "$@"; do
  if [[ "$arg" == "--keep-dump" ]]; then
    KEEP_DUMP=true
    break
  fi
done

# Define the dumps directory at the project root.
DUMPS_DIR="$PROJECT_ROOT/database_dumps"

# Check if the directory does not exist
if [ ! -d "$DUMPS_DIR" ]; then
    mkdir -p "$DUMPS_DIR"
    # Ignore everything we never want this folder or its contents to end up into git.
    echo "*" > "$DUMPS_DIR/.gitignore"
    display_status_message "Directory '$DUMPS_DIR' and .gitignore file created."
fi

# Define file name for the dump.
sql_file="$DUMPS_DIR/${ALIAS_KEY}-syncdb-$(date +'%Y-%m-%d').sql"

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

# Parse Alias Details using yq
# DDEV might be injecting some messages to output so clean the output
alias_details_clean=$(echo "$alias_details" | sed -n '/@self/,$p')

# Dynamically build the yq query path using the alias key ("prod").
prod_ssh_user=$(ddev yq '."@self.'"$ALIAS_KEY"'".user' <<< "$alias_details_clean")
prod_ssh_host=$(ddev yq '."@self.'"$ALIAS_KEY"'".host' <<< "$alias_details_clean")
prod_ssh_options=$(ddev yq '."@self.'"$ALIAS_KEY"'".ssh.options' <<< "$alias_details_clean")

# --- Validate parsed SSH details ---
if [[ -z "$prod_ssh_user" || "$prod_ssh_user" == "null" ]]; then
  display_error_message "Missing or invalid SSH user for alias '$ALIAS_KEY'."
  display_warning_message "Check your drush/sites/self.site.yml configuration for the 'user' field."
  exit 1
fi

if [[ -z "$prod_ssh_host" || "$prod_ssh_host" == "null" ]]; then
  display_error_message "Missing or invalid SSH host for alias '$ALIAS_KEY'."
  display_warning_message "Check your drush/sites/self.site.yml configuration for the 'host' field."
  exit 1
fi

if [[ -z "$prod_ssh_options" || "$prod_ssh_options" == "null" ]]; then
  display_error_message "Missing or invalid SSH options for alias '$ALIAS_KEY'."
  display_warning_message "Check your drush/sites/self.site.yml configuration for the 'ssh.options' field."
  exit 1
fi

# Test SSH connection - allow passphrase prompt to be visible
ssh_command=(ssh $prod_ssh_options "$prod_ssh_user@$prod_ssh_host")
if ! "${ssh_command[@]}" "true"; then
  display_error_message "Failed to establish SSH connection to $ALIAS_KEY. Check your network and credentials."
  exit 1
fi

# --- Perform the Database Dump and Import ---
display_status_message "Dumping database from '$SITE_ALIAS'..."

"${ssh_command[@]}" "drush sql-dump --structure-tables-list=cache,cache_*,history,search_*,sessions" > "$sql_file"

display_status_message "Dump complete, starting import!"

ddev import-db --file="$sql_file"
if [[ "$KEEP_DUMP" != "true" ]]; then
  rm "$sql_file"
fi
{ set +x; } 2>/dev/null

display_status_message "Sync with '$SITE_ALIAS' complete!"
