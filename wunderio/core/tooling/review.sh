#!/bin/bash
#ddev-generated

#
# Helper script to perform AI Code Review on the current branch against a target branch (default: main).
# Uses GitHub Copilot CLI in the agents container (same as `ddev copilot`).
# Usage: ddev review [target-branch] [--model MODEL]
# Example: ddev review
# Example: ddev review develop
# Example: ddev review --model gpt-5-mini
# Example: ddev review develop --model gpt-5.2
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

# Try to source global helpers if they exist
source "$WUNDERIO_GLOBAL_SCRIPT_ROOT/_helpers.sh" 2>/dev/null || true

# Helper function for error messages if _helpers.sh isn't available
display_error_message() {
    echo -e "\033[31m$1\033[0m"
}

# Render Markdown with ANSI colors when glow is not available.
# Colors: headers=cyan, critical/bug/security=red, type/perf/warning=yellow,
# other labels=blue, remaining bold=bold-white, code blocks=unstyled.
render_markdown() {
    local RED=$'\033[1;31m'
    local YELLOW=$'\033[1;33m'
    local CYAN=$'\033[1;36m'
    local BLUE=$'\033[1;34m'
    local GREEN=$'\033[1;32m'
    local DIM=$'\033[2m'
    local BOLD=$'\033[1m'
    local NC=$'\033[0m'
    local in_code_block=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` ]]; then
            in_code_block=$(( 1 - in_code_block ))
            echo "$line"
            continue
        fi
        if [ $in_code_block -eq 1 ]; then
            echo "$line"
            continue
        fi
        if [[ "$line" =~ ^"### " ]]; then
            echo -e "\n${CYAN}${BOLD}${line}${NC}"
            continue
        fi
        line=$(echo "$line" | sed \
            -e "s/\*\*\(\[Critical[^]]*\]\)\*\*/${RED}\1${NC}/g" \
            -e "s/\*\*\(\[Bug[^]]*\]\)\*\*/${RED}\1${NC}/g" \
            -e "s/\*\*\(\[Security[^]]*\]\)\*\*/${RED}\1${NC}/g" \
            -e "s/\*\*\(\[Type[^]]*\]\)\*\*/${YELLOW}\1${NC}/g" \
            -e "s/\*\*\(\[Performance[^]]*\]\)\*\*/${YELLOW}\1${NC}/g" \
            -e "s/\*\*\(\[Warning[^]]*\]\)\*\*/${YELLOW}\1${NC}/g" \
            -e "s/\*\*\(\[[^]]*\]\)\*\*/${BLUE}\1${NC}/g" \
            -e "s/\*\*Location\*\*:/${DIM}Location:${NC}/g" \
            -e "s/\*\*Description\*\*:/${BOLD}Description:${NC}/g" \
            -e "s/\*\*Suggestion\*\*:/${GREEN}Suggestion:${NC}/g" \
            -e "s/\*\*\([^*]*\)\*\*/${BOLD}\1${NC}/g")
        echo -e "$line"
    done
}

# Copilot model: --model flag > WUNDERIO_REVIEW_MODEL > default.
MODEL="${WUNDERIO_REVIEW_MODEL:-gpt-5-mini}"
TARGET_BRANCH="main"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]]; then
                display_error_message "❌ Error: --model requires a value"
                exit 1
            fi
            MODEL="$2"
            shift 2
            ;;
        --model=*)
            MODEL="${1#--model=}"
            if [ -z "$MODEL" ]; then
                display_error_message "❌ Error: --model requires a value"
                exit 1
            fi
            shift
            ;;
        -*)
            display_error_message "❌ Error: Unknown option: $1"
            exit 1
            ;;
        *)
            TARGET_BRANCH="$1"
            shift
            ;;
    esac
done

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")

if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ]; then
    echo "ℹ️ You are currently on the '$TARGET_BRANCH' branch. Switch to a feature branch to perform a review."
    exit 0
fi

# Verify the target branch exists
if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH" && ! git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    echo "⚠️  Target branch '$TARGET_BRANCH' does not exist locally."
    # Auto-fallback to master if user left the default as main
    if [ "$TARGET_BRANCH" = "main" ] && (git show-ref --verify --quiet "refs/heads/master" || git show-ref --verify --quiet "refs/remotes/origin/master"); then
        echo "🔄 Falling back to 'master'..."
        TARGET_BRANCH="master"
    else
        display_error_message "❌ Error: Cannot compare against '$TARGET_BRANCH' because it does not exist."
        exit 1
    fi
fi

echo "🕵️  Analyzing changes on '$CURRENT_BRANCH' against '$TARGET_BRANCH' using GitHub Copilot (${MODEL})..."

# Detect Drupal version from the installed core (most accurate source).
DRUPAL_VERSION=$(grep -oE "[0-9]+\.[0-9]+(\.[0-9]+)?" web/core/lib/Drupal.php 2>/dev/null | head -1 || echo "")
if [ -z "$DRUPAL_VERSION" ]; then
    # Fallback: parse the constraint from composer.json (strip ^ ~ etc.)
    DRUPAL_VERSION=$(jq -r '(.require["drupal/core-recommended"] // .require["drupal/core"] // "") | ltrimstr("^") | ltrimstr("~") | ltrimstr(">=")' composer.json 2>/dev/null || echo "")
fi
DRUPAL_CONTEXT=""
if [ -n "$DRUPAL_VERSION" ]; then
    DRUPAL_MAJOR=$(echo "$DRUPAL_VERSION" | cut -d. -f1)
    DRUPAL_CONTEXT="This is a Drupal ${DRUPAL_VERSION} project. Verify that the code follows Drupal ${DRUPAL_MAJOR} coding standards, API conventions, and best practices (e.g. hook signatures, service injection, deprecation usage, security best practices)."
    echo "🔍 Detected Drupal ${DRUPAL_VERSION}"
fi

# Gather git context.
# We use TRIPLE DOT (...) to show only changes on the current branch since it diverged from the target.
# We use -U8 to give the AI 8 lines of surrounding code context (crucial for spotting bugs).
# We exclude lock files, compiled assets, and large auto-generated files.
DIFF=$(git diff "${TARGET_BRANCH}...HEAD" -M -w -U8 \
    ':(exclude)*package-lock.json' \
    ':(exclude)*yarn.lock' \
    ':(exclude)*pnpm-lock.yaml' \
    ':(exclude)*composer.lock' \
    ':(exclude)*.min.js' \
    ':(exclude)*.min.css' \
    ':(exclude)*.svg')

if [ -z "$DIFF" ]; then
    echo "✅ No meaningful differences found between '$CURRENT_BRANCH' and '$TARGET_BRANCH' (excluding lockfiles/assets)."
    exit 0
fi

# Large diffs may take longer to process but are sent in full via the Copilot CLI.
DIFF_LENGTH=${#DIFF}
if [ "$DIFF_LENGTH" -gt 100000 ]; then
    echo "ℹ️  Large diff detected (${DIFF_LENGTH} chars). This may take a few extra minutes to process."
fi

# Build context
CONTEXT="Comparing branch: ${CURRENT_BRANCH} against ${TARGET_BRANCH}
${DRUPAL_CONTEXT:+
${DRUPAL_CONTEXT}
}
--- BRANCH CHANGES ---
${DIFF}"

# Strict Senior Engineer Prompt (The secret to Copilot-quality reviews)
REVIEW_INSTRUCTIONS="You are an expert Senior Drupal Engineer performing a pull-request code review.
Your goal is to ensure code quality, security, and performance.

CRITICAL RULES:
1. FOCUS ON HIGH-VALUE ISSUES: Look for logical bugs, security vulnerabilities (XSS, SQLi, insecure data), race conditions, and unhandled edge cases.
2. TYPE SAFETY: Flag mismatches between docblocks (@return, @param), native PHP return/param types, and actual values or sibling methods in the diff.
   - Drupal entity and reference IDs (taxonomy term IDs, node IDs, user IDs, entity reference field target_id values) are integers in this codebase — not strings. If a method returns target_id or ->id(), the docblock should use int or int|null, not string|string|null.
   - When fixing ID types, suggest all three when applicable: (1) update the @return / @param annotation, (2) add or correct the native PHP return type (e.g. ?int means nullable int — int or null), and (3) cast at the return site if needed, e.g. return \$target_id !== NULL ? (int) \$target_id : NULL;
   - Prefer consistency with nearby accessors in the same module (e.g. getVersionId() documented as @return int).
   These mismatches cause PHPStan/Psalm failures and subtle bugs when IDs are compared or passed to APIs expecting int.
3. BEST PRACTICE: Before property/array/entity access, verify the parent value exists (null, empty, missing item) when the diff allows it.
4. BE SPECIFIC: Always reference the exact file and function/line for each issue.
5. PROVIDE SOLUTIONS: Always include a concrete code fix for each issue.
6. IF NO ISSUES: If the code looks robust and safe, reply only with: '✅ The branch looks good. No major issues found.'
7. NO FILLER: Do NOT add greetings, summaries, closing remarks, or any text outside the structure below.
8. GROUP ISSUES TO AVOID REPETITION: Group related issues together to avoid repetition.

FORMAT RULES — follow this structure exactly, no deviations:
- Use '### path/to/File.php' as a section header for each file that has issues.
- For each issue use EXACTLY this layout (preserve the indentation):
  - **[Issue severity]**: One-line summary of the problem.
    - **Location**: \`ClassName::methodName()\` or line reference.
    - **Description**: Clear explanation of why this is a problem.
    - **Suggestion**: Concrete fix. Include a fenced code block when relevant.
      \`\`\`language
      // fixed code
      \`\`\`
- [Issue severity] above is one of the following: [CRITICAL], [HIGH], [MEDIUM], [LOW]."

# Build the Copilot prompt (system instructions + diff context).
COPILOT_PROMPT="${REVIEW_INSTRUCTIONS}

Please review the following pull-request style changes:

${CONTEXT}"

# Resolve DDEV project (host command; same as .ddev/commands/host/copilot).
DDEV_PROJECT="${DDEV_PROJECT:-}"
if [ -z "$DDEV_PROJECT" ]; then
    DDEV_PROJECT=$(ddev describe -j 2>/dev/null | jq -r '.raw.name' 2>/dev/null || echo "")
fi
if [ -z "$DDEV_PROJECT" ]; then
    display_error_message "❌ Error: Could not determine DDEV project name"
    exit 1
fi

AGENTS_CONTAINER="ddev-${DDEV_PROJECT}-agents"

if ! docker ps --format '{{.Names}}' | grep -q "$AGENTS_CONTAINER"; then
    display_error_message "❌ Error: agents container is not running"
    echo "👉 Run 'ddev start' first"
    exit 1
fi

if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "ddev-${DDEV_PROJECT}-devcontainer:latest"; then
    display_error_message "❌ Error: devcontainer image not built"
    echo "👉 Run 'ddev restart' to build the agents devcontainer"
    exit 1
fi

if ! docker exec "$AGENTS_CONTAINER" bash -c "command -v copilot &> /dev/null"; then
    display_error_message "❌ Error: copilot CLI not found in agents container"
    echo "👉 Ensure the devcontainer has the 'ghcr.io/devcontainers/features/copilot-cli' feature"
    exit 1
fi

if ! docker exec "$AGENTS_CONTAINER" bash -c '[ -n "$GH_TOKEN" ]'; then
    display_error_message "❌ Error: GH_TOKEN not found in agents container"
    echo "👉 Set DDEV_AGENTS_GH_TOKEN on your host (see README for instructions)"
    exit 1
fi

PROMPT_FILE=$(mktemp)
OUTPUT_FILE=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$OUTPUT_FILE"' EXIT
printf '%s' "$COPILOT_PROMPT" > "$PROMPT_FILE"

echo ""
echo "=========================================="
echo "         🤖 AI CODE REVIEW REPORT         "
echo "=========================================="
echo ""
echo "⏳ Running Copilot review (large diffs can take several minutes)..."
echo ""

# Pipe prompt on stdin (safe for huge diffs and shell-special chars in patches).
set +e
docker exec -i "$AGENTS_CONTAINER" bash -c "cd /workspace && exec timeout 600 copilot -s --no-ask-user --model $(printf '%q' "$MODEL")" < "$PROMPT_FILE" >"$OUTPUT_FILE" 2>&1
COPILOT_EXIT_CODE=$?
set -e

REVIEW_MSG=$(cat "$OUTPUT_FILE" 2>/dev/null || echo "")

if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    echo "--- RAW COPILOT RESPONSE ---"
    echo "$REVIEW_MSG"
    echo "--- END RAW COPILOT RESPONSE ---"
fi

if [ $COPILOT_EXIT_CODE -eq 124 ]; then
    display_error_message "❌ Error: Copilot review timed out after 10 minutes"
    exit 1
fi

if [ $COPILOT_EXIT_CODE -ne 0 ]; then
    display_error_message "❌ Error: Copilot review failed (exit code: $COPILOT_EXIT_CODE)"
    if [ -n "$REVIEW_MSG" ]; then
        echo "$REVIEW_MSG"
    fi
    exit 1
fi

if [ -z "$REVIEW_MSG" ]; then
    display_error_message "❌ Error: Copilot returned an empty response"
    exit 1
fi

echo ""
if command -v glow &> /dev/null; then
    echo "$REVIEW_MSG" | glow -
else
    echo "$REVIEW_MSG" | render_markdown
fi

echo ""
echo "======================================================"
echo "  Model: ${MODEL} | Powered by GitHub Copilot (agents container)"
echo "======================================================"
echo ""
