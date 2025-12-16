#ddev-generated
# Git Commit Message Instructions

To ensure consistent and informative commit messages, follow these rules. They are designed to integrate smoothly with GitHub Copilot's suggestions and your ticket-based development workflow.

## Commit Message Format

Each commit message **must** follow this structure:

```
TICKET-ID: short summary of the change

[Optional: blank line]
[Optional: bulleted list of detailed changes]
```

### Example: Simple Commit (Single Change)

_Given branch:_ `feature/MET-123-a-new-feature`

```
MET-123: add login button to homepage
```

### Example: Multi-line Commit (Multiple Changes or Explanation)

```
MET-123: implement user authentication flow

- Add login form to homepage
- Connect login form to backend auth API
- Create AuthContext for managing logged-in state
```

---

## Rules for Commit Messages

### 1. Ticket Number
- Always begin the commit message with the ticket number (e.g., `MET-123`).
- Infer the ticket number from the branch name when possible.
- Format: `TICKET-ID: message`

### 2. Summary Line
- Keep the first line concise (max 72 characters recommended).
- Use present tense: "add", "fix", "update", not "added", "fixed", "updated".
- Do **not** end the summary line with a period.

### 3. Body (Optional, for Complex Changes)
- Start the body after a blank line.
- Use bullet points if there are multiple noteworthy changes.
- Be descriptive enough to help reviewers and future developers understand why the changes were made.

### 4. Grammar & Tone
- Write in imperative mood (like giving a command): "Refactor API handler", not "Refactored API handler".
- Keep messages professional and relevant to the codebase.

---

## Examples of Good vs. Bad

**Good:**
- `MET-234: fix crash on login when user has no profile image`
- `MET-567: add config support`
- `MET-890: refactor dashboard components`

**Bad:**
- `fixed stuff`
- `Update`
- `debug`
