#!/bin/bash
#ddev-generated

#
# Helper script to generate AI commit message from staged changes.
#

set -eu
if [[ -n "${WUNDERIO_DEBUG:-}" ]]; then
    set -x
fi

source "$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/_helpers.sh"

# Configuration from environment.
# These are expected to be defined via the project root .env file, which DDEV
# loads into the web container environment. Example:
#   API_URL=https://your-api-url
#   API_KEY=your-api-key
API_URL="${API_URL:-}"
API_KEY="${API_KEY:-}"
DEFAULT_MODEL="google_genai.gemini-2.5-flash"
MODEL="${1:-$DEFAULT_MODEL}"

# Validate environment variables.
if [ -z "$API_URL" ]; then
    display_error_message "❌ Error: API_URL environment variable not set"
    echo "Set it in your project root .env file, then run 'ddev restart'."
    echo ""
    echo "Example:"
    echo "  echo 'API_URL=https://your-api-url' >> .env"
    exit 0
fi

if [ -z "$API_KEY" ]; then
    display_error_message "❌ Error: API_KEY environment variable not set"
    echo "Set it in your project root .env file, then run 'ddev restart'."
    echo ""
    echo "Example:"
    echo "  echo 'API_KEY=your-api-key' >> .env"
    exit 0
fi

# Check for staged changes.
if git diff --cached --quiet; then
    display_status_message "No staged changes to commit. Stage files with 'git add' first."
    exit 0
fi

# Read commit message instructions
INSTRUCTIONS_FILE="$WUNDERIO_GLOBAL_CACHE_WUNDERIO/core/git-commit-message-instructions.md"
if [ -f "$INSTRUCTIONS_FILE" ]; then
    COMMIT_INSTRUCTIONS=$(cat "$INSTRUCTIONS_FILE")
else
    echo "⚠️  Warning: Instructions file not found at ${INSTRUCTIONS_FILE}"
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
    display_error_message "⚠️  Warning: Diff is very large (${DIFF_LENGTH} chars). Truncating to first ${MAX_DIFF_SIZE} characters for API request."
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
# Build JSON payload with jq (handles escaping properly)
PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg context "$CONTEXT" \
  --arg instructions "$COMMIT_INSTRUCTIONS" \
  '{
    model: $model,
    messages: [
      {
        role: "system",
        content: ("You are a git commit message generator. Follow these rules:\n\n" + $instructions + "\n\nCRITICAL: Always include the ticket ID from the branch name followed by a colon and space, then a descriptive summary (e.g., \"THLP-116: add login button\"). Use present tense, imperative mood. First line max 72 chars. Output ONLY the commit message, nothing else.")
      },
      {
        role: "user",
        content: ("Analyze these changes and generate a commit message in the format TICKET-ID: description:\n\n" + $context)
      }
    ],
    temperature: 0.3,
    max_tokens: 2000
  }')

# Call API
RESPONSE=$(curl -s -X POST "${API_URL}/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Extract message
COMMIT_MSG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)

if [ -z "$COMMIT_MSG" ] || [ "$COMMIT_MSG" = "null" ]; then
    display_error_message "❌ Error: Failed to generate commit message"
    echo "API Response (truncated, may contain sensitive info):"
    echo "${RESPONSE:0:200}..."
    echo "For full details, rerun with WUNDERIO_DEBUG=1"
    exit 1
fi

# Debug: Show what was sent and received
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
