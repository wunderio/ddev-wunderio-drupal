#!/bin/bash
#ddev-generated

#
# Import a local database dump from database_dumps/.
# Interactively picks a file (fzf when available, bash select otherwise).
#

set -eu

if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# --- Sourcing Helper Functions ---
source "$WUNDERIO_GLOBAL_SCRIPT_ROOT/_helpers.sh"

DUMPS_DIR="$(get_database_dumps_dir)"
NO_DEPLOY=false
SELECTED_ARG=""

# --- Parse arguments ---
for arg in "$@"; do
  case "$arg" in
    --no-deploy) NO_DEPLOY=true ;;
    --help|-h)
      display_status_message "Usage: ddev importdb [file] [--no-deploy]"
      display_warning_message "  (no args)     Interactively choose a dump from database_dumps/"
      display_warning_message "  file          Skip picker; use this dump (basename or path under dumps)"
      display_warning_message "  --no-deploy   Skip running drush deploy after import"
      exit 0
      ;;
    -*)
      display_error_message "Unknown option: $arg"
      display_warning_message "Usage: ddev importdb [file] [--no-deploy]"
      exit 1
      ;;
    *)
      if [[ -n "$SELECTED_ARG" ]]; then
        display_error_message "Only one dump file argument is allowed."
        exit 1
      fi
      SELECTED_ARG="$arg"
      ;;
  esac
done

# --- Validate dumps directory ---
if [[ ! -d "$DUMPS_DIR" ]]; then
  display_error_message "Directory not found: $DUMPS_DIR"
  display_warning_message "Store dump files in database_dumps/ at the project root, then retry."
  exit 1
fi

# Build newest-first list of dump files (basenames). Bash 3 compatible (no mapfile).
DUMP_FILES=()
while IFS= read -r path; do
  [[ -f "$path" ]] || continue
  DUMP_FILES+=("$(basename "$path")")
done < <(ls -t "$DUMPS_DIR"/*.sql.gz "$DUMPS_DIR"/*.sql 2>/dev/null || true)

if [[ ${#DUMP_FILES[@]} -eq 0 ]]; then
  display_error_message "No .sql or .sql.gz dump files found in $DUMPS_DIR"
  exit 1
fi

# --- Resolve selected file ---
chosen=""

if [[ -n "$SELECTED_ARG" ]]; then
  # Accept basename, relative path under dumps, or absolute path inside dumps.
  candidate="$SELECTED_ARG"
  if [[ "$candidate" != /* ]]; then
    if [[ "$candidate" == database_dumps/* ]]; then
      candidate="$PROJECT_ROOT/$candidate"
    else
      candidate="$DUMPS_DIR/$candidate"
    fi
  fi

  if [[ ! -f "$candidate" ]]; then
    display_error_message "Dump file not found: $SELECTED_ARG"
    exit 1
  fi

  dumps_resolved="$(cd "$DUMPS_DIR" && pwd)"
  resolved="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
  case "$resolved" in
    "$dumps_resolved"/*) ;;
    *)
      display_error_message "Dump file must be inside database_dumps/: $SELECTED_ARG"
      exit 1
      ;;
  esac

  # Keep the path relative to database_dumps/ so subdirectories work.
  chosen="${resolved#$dumps_resolved/}"
else
  display_status_message "Select a dump from database_dumps/:"

  if command -v fzf >/dev/null 2>&1; then
    chosen="$(printf '%s\n' "${DUMP_FILES[@]}" | fzf --height=40% --reverse --prompt='Dump> ')" || true
    if [[ -z "$chosen" ]]; then
      display_warning_message "No dump selected. Aborting."
      exit 1
    fi
  else
    display_warning_message "fzf not found; using numbered menu. Install fzf for fuzzy search."
    PS3="Enter number (or Ctrl-C to cancel): "
    select item in "${DUMP_FILES[@]}"; do
      if [[ -n "${item:-}" ]]; then
        chosen="$item"
        break
      fi
      display_error_message "Invalid selection."
    done
    if [[ -z "$chosen" ]]; then
      display_warning_message "No dump selected. Aborting."
      exit 1
    fi
  fi
fi

sql_file="$DUMPS_DIR/$chosen"

display_warning_message "This will overwrite your local database with: $chosen"

# Place marker file in the named volume so the post-import hook can read it.
if [[ "$NO_DEPLOY" == "true" ]]; then
  ddev exec sudo touch /mnt/wdr-hooks/.no-deploy
  trap 'ddev exec sudo rm -f /mnt/wdr-hooks/.no-deploy' EXIT
fi

display_status_message "Importing $sql_file ..."
# ddev import-db natively handles .gz files.
ddev import-db --file="$sql_file"

{ set +x; } 2>/dev/null

display_status_message "Import of '$chosen' complete!"
