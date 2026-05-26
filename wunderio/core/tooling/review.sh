#!/bin/bash
#ddev-generated

#
# Helper script to perform AI Code Review on the current branch against a target branch (default: main).
# Usage: ddev review [target-branch]
# Example: ddev review
# Example: ddev review develop
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

# Configuration from environment.
OPENAI_API_URL="${OPENAI_API_URL:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
# Modern models (Gemini 1.5/2.5 Pro, GPT-4o, Claude 3.5 Sonnet) are highly recommended for deep reviews.
# Flash is fast, but Pro models catch more complex logic bugs.
MODEL="google_genai.gemini-2.5-pro"
MAX_TOKENS=8000

# Validate environment variables.
if [ -z "$OPENAI_API_URL" ] || [ -z "$OPENAI_API_KEY" ]; then
    display_error_message "❌ Error: Required OpenAI environment variables are not set"
    echo "Set the missing variables in DDEV global config, then restart your DDEV project:"
    echo "  ddev config global --web-environment-add=\"OPENAI_API_URL=https://your-api-url\""
    echo "  ddev config global --web-environment-add=\"OPENAI_API_KEY=your-api-key\""
    echo "  ddev restart"
    exit 1
fi

# Determine branches
TARGET_BRANCH="${1:-main}"
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

echo "🕵️  Analyzing changes on '$CURRENT_BRANCH' against '$TARGET_BRANCH' using ${MODEL}..."

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

# Truncate diff if it's too large to avoid exceeding API token limits.
# 100,000 chars is usually safe for modern models like Gemini 2.5 and GPT-4o.
MAX_DIFF_SIZE=100000
DIFF_LENGTH=${#DIFF}
if [ "$DIFF_LENGTH" -gt "$MAX_DIFF_SIZE" ]; then
    echo "⚠️  Warning: Diff is very large (${DIFF_LENGTH} chars). Truncating to first ${MAX_DIFF_SIZE} characters for API request."
    DIFF="${DIFF:0:$MAX_DIFF_SIZE}"
    DIFF="${DIFF}"$'\n'$'\n'"[... diff truncated due to size ...]"
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

JQ_ERROR_FILE=$(mktemp)
# Ensure the file is deleted even if the script crashes or is killed.
trap 'rm -f "$JQ_ERROR_FILE"' EXIT

# Build JSON payload with jq (handles escaping properly)
PAYLOAD=$(
  model="$MODEL" \
  max_tokens="$MAX_TOKENS" \
  context="$CONTEXT" \
  instructions="$REVIEW_INSTRUCTIONS" \
  jq -n \
  '{
    model: $ENV.model,
    messages:[
      {
        role: "system",
        content: $ENV.instructions
      },
      {
        role: "user",
        content: ("Please review the following pull-request style changes:\n\n" + $ENV.context)
      }
    ],
    temperature: 0.2,
    max_tokens: ($ENV.max_tokens | tonumber)
  }' 2>"$JQ_ERROR_FILE"
)
JQ_EXIT_CODE=$?
JQ_ERROR=$(cat "$JQ_ERROR_FILE" 2>/dev/null || echo "")

# Validate that jq succeeded and produced valid JSON.
if [ $JQ_EXIT_CODE -ne 0 ] || [ -z "$PAYLOAD" ] || [ "$PAYLOAD" = "null" ]; then
    display_error_message "❌ Error: Failed to build API request payload"
    if [ -n "$JQ_ERROR" ]; then echo "jq error: $JQ_ERROR"; fi
    exit 1
fi

CURL_RESPONSE_FILE=$(mktemp)
CURL_HTTP_CODE_FILE=$(mktemp)

# Ensure temp files are cleaned up on exit.
trap 'rm -f "$CURL_RESPONSE_FILE" "$CURL_HTTP_CODE_FILE" "$JQ_ERROR_FILE"' EXIT

# Call API.
set +e
curl -s -f -X POST "${OPENAI_API_URL}/chat/completions" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  -w "%{http_code}" -o "$CURL_RESPONSE_FILE" > "$CURL_HTTP_CODE_FILE"
CURL_EXIT_CODE=$?
set -e

HTTP_STATUS=$(cat "$CURL_HTTP_CODE_FILE" 2>/dev/null || echo "")
RESPONSE=$(cat "$CURL_RESPONSE_FILE" 2>/dev/null || echo "")

if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    echo "--- RAW API RESPONSE ---"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    echo "--- END RAW API RESPONSE ---"
fi

# Handle curl errors
if [ $CURL_EXIT_CODE -ne 0 ] || [ "$HTTP_STATUS" -lt 200 ] ||[ "$HTTP_STATUS" -ge 300 ]; then
    display_error_message "❌ Error: API request failed (cURL code: $CURL_EXIT_CODE, HTTP Status: $HTTP_STATUS)"
    if [ -n "$RESPONSE" ]; then
        echo "API Response (truncated): ${RESPONSE:0:300}..."
    fi
    exit 1
fi

# Extract message.
JQ_REVIEW_MSG_ERROR_FILE=$(mktemp)
trap 'rm -f "$JQ_REVIEW_MSG_ERROR_FILE" "$CURL_RESPONSE_FILE" "$CURL_HTTP_CODE_FILE" "$JQ_ERROR_FILE"' EXIT

set +e
REVIEW_MSG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>"$JQ_REVIEW_MSG_ERROR_FILE")
JQ_REVIEW_MSG_EXIT_CODE=$?
set -e

if [ $JQ_REVIEW_MSG_EXIT_CODE -ne 0 ] || [ -z "$REVIEW_MSG" ] || [ "$REVIEW_MSG" = "null" ]; then
    display_error_message "❌ Error: Failed to parse API response"
    exit 1
fi

# Print the final output
echo ""
echo "=========================================="
echo "         🤖 AI CODE REVIEW REPORT         "
echo "=========================================="
echo ""

# Try to use 'glow' for pretty Markdown rendering in the terminal if it's installed
if command -v glow &> /dev/null; then
    echo "$REVIEW_MSG" | glow -
else
    echo "$REVIEW_MSG" | render_markdown
fi

echo ""
echo "======================================================"
echo "  Model: ${MODEL} | Max tokens: ${MAX_TOKENS}"
echo "======================================================"
echo ""
