#!/bin/bash
#ddev-generated

#
# Helper script to generate AI commit message from staged changes.
#

set -eu

source "$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_helpers.sh"

# Configuration from environment.
# These are expected to be defined via DDEV global config, which makes them
# available to all DDEV projects. Example:
#   ddev config global --web-environment-add="OPENAI_API_URL=https://your-api-url"
#   ddev config global --web-environment-add="OPENAI_API_KEY=your-api-key"
OPENAI_API_URL="${OPENAI_API_URL:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
MODEL="google_genai.gemini-2.5-flash"

# Validate environment variables.
if [ -z "$OPENAI_API_URL" ]; then
    display_error_message "❌ Error: OPENAI_API_URL environment variable not set"
    echo "Set it in DDEV global config, then restart your DDEV project:"
    echo ""
    echo "  ddev config global --web-environment-add=\"OPENAI_API_URL=https://your-api-url\""
    echo "  ddev restart"
    exit 0
fi

if [ -z "$OPENAI_API_KEY" ]; then
    display_error_message "❌ Error: OPENAI_API_KEY environment variable not set"
    echo "Set it in DDEV global config, then restart your DDEV project:"
    echo ""
    echo "  ddev config global --web-environment-add=\"OPENAI_API_KEY=your-api-key\""
    echo "  ddev restart"
    exit 0
fi

# Check for staged changes.
if git diff --cached --quiet; then
    display_status_message "No staged changes to commit. Stage files with 'git add' first."
    exit 0
fi

# Read commit message instructions.
INSTRUCTIONS_FILE="$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/git-commit-message-instructions.md"
if [ -f "$INSTRUCTIONS_FILE" ]; then
    COMMIT_INSTRUCTIONS=$(cat "$INSTRUCTIONS_FILE")
else
    display_warning_message "⚠️  Warning: Instructions file not found at ${INSTRUCTIONS_FILE}"
    COMMIT_INSTRUCTIONS="Follow standard git commit message conventions."
fi

# Gather git context.
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "no tags")
STAT=$(git diff --cached --stat)
DIFF=$(git diff --cached -M -w)

# Truncate diff if it's too large to avoid exceeding API token limits.
# Most APIs have input token limits, and very large diffs can cause failures.
MAX_DIFF_SIZE=10000
DIFF_LENGTH=${#DIFF}
if [ "$DIFF_LENGTH" -gt "$MAX_DIFF_SIZE" ]; then
    display_warning_message "⚠️  Warning: Diff is very large (${DIFF_LENGTH} chars). Truncating to first ${MAX_DIFF_SIZE} characters for API request."
    DIFF="${DIFF:0:$MAX_DIFF_SIZE}"
    DIFF="${DIFF}"$'\n'$'\n'"[... diff truncated due to size ...]"
fi

# Build context.
CONTEXT="Branch: ${BRANCH}
Latest tag: ${TAG}

--- STAGED FILES ---
${STAT}

--- CHANGES ---
${DIFF}"

echo "🤖 Generating commit message using ${MODEL}..."
JQ_ERROR_FILE=$(mktemp)
# Build JSON payload with jq (handles escaping properly)
# Pass variables via env (rather than passing them as arguments), read them in jq using $ENV
# This is more robust and avoids issues with argument length limits.
PAYLOAD=$(
  model="$MODEL" \
  context="$CONTEXT" \
  instructions="$COMMIT_INSTRUCTIONS" \
  jq -n \
  '{
    model: $ENV.model,
    messages: [
      {
        role: "system",
        content: ("You are a git commit message generator. Follow these rules:\n\n" + $ENV.instructions + "\n\nCRITICAL: Do not invent or hallucinate information. Only use the provided context. Output only the commit message, nothing else.")
      },
      {
        role: "user",
        content: ("Analyze these changes and generate a commit message in the format TICKET-ID: description:\n\n" + $ENV.context)
      }
    ],
    temperature: 0.3,
    max_tokens: 2000
  }' 2>"$JQ_ERROR_FILE"
)
JQ_EXIT_CODE=$?
JQ_ERROR=$(cat "$JQ_ERROR_FILE" 2>/dev/null || echo "")
# Ensure the file is deleted even if the script crashes or is killed.
trap 'rm -f "$JQ_ERROR_FILE"' EXIT

# Validate that jq succeeded and produced valid JSON.
if [ $JQ_EXIT_CODE -ne 0 ] || [ -z "$PAYLOAD" ] || [ "$PAYLOAD" = "null" ]; then
    display_error_message "❌ Error: Failed to build API request payload"
    if [ $JQ_EXIT_CODE -ne 0 ] && [ -n "$JQ_ERROR" ]; then
        echo "jq error: $JQ_ERROR"
    elif [ $JQ_EXIT_CODE -ne 0 ]; then
        echo "jq command failed (exit code: $JQ_EXIT_CODE). This may indicate invalid input data."
    fi
    exit 1
fi

# Call API.
RESPONSE=$(curl -s -X POST "${OPENAI_API_URL}/chat/completions" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Extract message.
COMMIT_MSG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)

if [ -z "$COMMIT_MSG" ] || [ "$COMMIT_MSG" = "null" ]; then
    display_error_message "❌ Error: Failed to generate commit message"
    echo "API Response (truncated, may contain sensitive info):"
    echo "${RESPONSE:0:200}..."
    echo "For full details, rerun with WUNDERIO_DEBUG=1"
    exit 1
fi

# Debug: Show what was sent and received.
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    echo "🔍 DEBUG INFO:"
    echo "Model: $MODEL"
    echo "Context length: ${#CONTEXT} chars"
    echo "Instructions length: ${#COMMIT_INSTRUCTIONS} chars"
    echo ""
    echo "Raw API Response:"
    echo "$RESPONSE" | jq '.'
    echo ""
    echo "Extracted message: '$COMMIT_MSG'"
    echo ""
fi

echo ""
echo "📝 Generated commit message:"
echo "---"
echo "$COMMIT_MSG"
echo "---"
echo ""
read -p "Commit with this message? [Y/n] " -n 1 -r
echo ""


if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    git commit -m "$COMMIT_MSG"
    display_status_message "✅ Committed successfully!"
else
    echo "Commit cancelled"
    exit 0
fi
