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
  display_warning_message "Usage: ddev syncdb <alias> [--keep-dump] [--backup] [--skip-hooks]"
  display_warning_message "Example: ddev syncdb prod"
  display_warning_message "  --keep-dump   Keep the downloaded dump file after import"
  display_warning_message "  --backup      Create a local database backup before overwriting"
  display_warning_message "  --skip-hooks  Skip DDEV post-import hooks during database import"
  exit 1
fi

# The alias key is the first argument, e.g., "prod" or "myproduction"
ALIAS_KEY="$1"
# The full alias required by Drush, which needs the "@" prefix, e.g., "@prod"
SITE_ALIAS="@${ALIAS_KEY}"

shift 1

# Parse flags
KEEP_DUMP=false
BACKUP=false
SKIP_HOOKS=false
for arg in "$@"; do
  case "$arg" in
    --keep-dump)   KEEP_DUMP=true ;;
    --backup)      BACKUP=true ;;
    --skip-hooks)  SKIP_HOOKS=true ;;
  esac
done

# --- 2. Validate drush/sites/self.site.yml and alias upfront ---
SITE_YML="$PROJECT_ROOT/drush/sites/self.site.yml"
if [[ ! -f "$SITE_YML" ]]; then
  display_error_message "Missing drush/sites/self.site.yml"
  display_warning_message "This file defines SSH aliases for remote environments."
  display_warning_message "See https://www.drush.org/13.x/site-aliases/ for format."
  exit 1
fi

if ! grep -q "^${ALIAS_KEY}:" "$SITE_YML"; then
  display_error_message "Alias '${ALIAS_KEY}' not found in drush/sites/self.site.yml"
  display_warning_message "Available aliases:"
  grep -E '^[a-zA-Z]' "$SITE_YML" | sed 's/:$//' | while read -r alias; do
    display_warning_message "  - $alias"
  done
  exit 1
fi

# --- 3. Prepare dumps directory ---
DUMPS_DIR="$PROJECT_ROOT/database_dumps"

if [ ! -d "$DUMPS_DIR" ]; then
    mkdir -p "$DUMPS_DIR"
    # Ignore everything — we never want this folder or its contents to end up in git.
    echo "*" > "$DUMPS_DIR/.gitignore"
    display_status_message "Directory '$DUMPS_DIR' and .gitignore file created."
fi

# Use .sql.gz extension for compressed dump.
sql_file="$DUMPS_DIR/${ALIAS_KEY}-syncdb-$(date +'%Y-%m-%d').sql.gz"

# --- 4. Create local backup (if --backup) ---
if [[ "$BACKUP" == "true" ]]; then
  backup_file="$DUMPS_DIR/backup-$(date +'%Y-%m-%d-%H%M%S').sql.gz"
  display_status_message "Creating local database backup: $backup_file"
  ddev export-db --gzip --file="$backup_file"
  display_status_message "Backup saved."
fi

# --- 5. Read remote alias details from Drush ---
if ! alias_details=$(ddev drush sa "$SITE_ALIAS" --format=yaml 2>&1); then
  display_error_message "Drush command failed."
  echo "--------------------------------------------------"
  echo "$alias_details"
  echo "--------------------------------------------------"
  display_error_message "Please ensure the alias '$ALIAS_KEY' is defined in your project's drush/sites/self.site.yml file."
  exit 1
fi

# Parse Alias Details using a single yq call.
# DDEV might be injecting some messages to output so clean the output.
alias_details_clean=$(echo "$alias_details" | sed -n '/@self/,$p')

# Dynamically build the yq query path using the alias key ("main").
alias_full="@self.${ALIAS_KEY}"
read -r remote_ssh_user remote_ssh_host remote_ssh_options < <(
  ddev exec -- yq -r ".\"$alias_full\" | [.user, .host, .ssh.options] | @tsv" <<< "$alias_details_clean"
)

# --- 6. Validate parsed SSH details ---
if [[ -z "$remote_ssh_user" || "$remote_ssh_user" == "null" ]]; then
  display_error_message "Missing or invalid SSH user for alias '$ALIAS_KEY'."
  display_warning_message "Check your drush/sites/self.site.yml configuration for the 'user' field."
  exit 1
fi

if [[ -z "$remote_ssh_host" || "$remote_ssh_host" == "null" ]]; then
  display_error_message "Missing or invalid SSH host for alias '$ALIAS_KEY'."
  display_warning_message "Check your drush/sites/self.site.yml configuration for the 'host' field."
  exit 1
fi

if [[ -z "$remote_ssh_options" || "$remote_ssh_options" == "null" ]]; then
  display_error_message "Missing or invalid SSH options for alias '$ALIAS_KEY'."
  display_warning_message "Check your drush/sites/self.site.yml configuration for the 'ssh.options' field."
  exit 1
fi

# Test SSH connection - allow passphrase prompt to be visible.
# Use SSH -C (compression) as a fallback for transfer speed.
ssh_command=(ssh -C $remote_ssh_options "$remote_ssh_user@$remote_ssh_host")
if ! "${ssh_command[@]}" "true"; then
  display_error_message "Failed to establish SSH connection to $ALIAS_KEY. Check your network and credentials."
  exit 1
fi

# --- 7. Perform the Database Dump and Import ---
display_status_message "Dumping database from '$SITE_ALIAS' (gzip compressed)..."

"${ssh_command[@]}" "drush sql-dump --gzip --structure-tables-list=cache,cache_*,history,search_*,sessions" > "$sql_file"

display_status_message "Dump complete, starting import!"

# Build import-db command with conditional flags.
# ddev import-db natively handles .gz files.
import_cmd=(ddev import-db --file="$sql_file")

# Full deployment steps can be ran seperatly.
if [[ "$SKIP_HOOKS" == "true" ]]; then
  import_cmd+=(--skip-hooks)
fi

"${import_cmd[@]}"

if [[ "$KEEP_DUMP" != "true" ]]; then
  rm "$sql_file"
fi
{ set +x; } 2>/dev/null

display_status_message "Sync with '$SITE_ALIAS' complete!"
