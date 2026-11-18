#!/bin/bash
#ddev-generated

#
# Remove old BackstopJS test runs before the project starts.
#
# Every `backstop test` run creates a new timestamped folder under
# backstop_data/bitmaps_test/ and BackstopJS never removes old ones, so the
# folder grows to gigabytes over time. The HTML report only uses the latest
# run, so older runs are safe to delete. Reference bitmaps are never touched.
#
# Runs before start so Mutagen does not have to sync the old runs.
#
# Settings (environment variables):
#   BACKSTOP_CLEANUP          Set to "false" to disable the cleanup (default "true").
#   BACKSTOP_KEEP_TEST_RUNS   Number of latest runs to keep, at least 1 (default 1).
#                             The latest run is always kept because the HTML
#                             report points to it.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

source "$WUNDERIO_GLOBAL_SCRIPT_ROOT/_helpers.sh"

# Lowercase with tr, macOS ships bash 3.2 which has no ${var,,}.
cleanup="$(printf '%s' "${BACKSTOP_CLEANUP:-true}" | tr '[:upper:]' '[:lower:]')"
case "$cleanup" in
    true | 1 | yes | on) ;;
    false | 0 | no | off) exit 0 ;;
    *)
        display_warning_message "BACKSTOP_CLEANUP must be true or false, skipping Backstop cleanup."
        exit 0
        ;;
esac

keep="${BACKSTOP_KEEP_TEST_RUNS:-1}"
if ! [[ "$keep" =~ ^[0-9]+$ ]]; then
    display_warning_message "BACKSTOP_KEEP_TEST_RUNS must be a number, skipping Backstop cleanup."
    exit 0
fi
# Force base 10, otherwise bash treats e.g. "08" as an invalid octal number.
keep=$((10#$keep))
if [[ "$keep" -lt 1 ]]; then
    display_warning_message "BACKSTOP_KEEP_TEST_RUNS must be at least 1 (use BACKSTOP_CLEANUP=false to disable), skipping Backstop cleanup."
    exit 0
fi

shopt -s nullglob

# Covers tests/backstop, tests/backstopjs and similar layouts.
for test_dir in "$PROJECT_ROOT"/tests/*/backstop_data/bitmaps_test; do
    # Only consider real folders named like BackstopJS runs (YYYYMMDD-HHMMSS).
    # The timestamp format sorts chronologically, newest last.
    # Note: no trailing slash in the glob. `rm -rf symlink/` on macOS deletes
    # the symlink's target, so symlinks are skipped explicitly.
    runs=()
    for run in "$test_dir"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]; do
        if [[ -d "$run" && ! -L "$run" ]]; then
            runs+=("$run")
        fi
    done
    count=${#runs[@]}
    if [[ "$count" -le "$keep" ]]; then
        continue
    fi

    remove=$((count - keep))
    display_status_message "Backstop: removing $remove old test run(s) from ${test_dir#"$PROJECT_ROOT"/}, keeping latest $keep."
    for ((i = 0; i < remove; i++)); do
        rm -rf -- "${runs[$i]}"
    done
done
