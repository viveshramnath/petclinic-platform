#!/usr/bin/env bash
# Hook: block-secret-commit.sh (PreToolUse on Bash)
# Purpose: Blocks git add/commit of files that may contain secrets.
# Why: Committing .env files, *.tfvars, credentials, or key files to git is a
#      security incident. Once pushed, secrets are in git history forever
#      (even after deletion). Prevention is much cheaper than rotation.
# How: Checks if the command is a git add or git commit, then scans for
#      secret-like filenames OR dangerous bulk-add patterns. Exits 2 to deny.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only check git add and git commit commands
if echo "$COMMAND" | grep -qE 'git\s+(add|commit)'; then

  # BLOCK 1: Catch bulk adds that could sweep in secret files
  # 'git add .', 'git add -A', 'git add --all' stage everything including secrets.
  # Each alternative is anchored to end-of-arg ($|\s) so it only matches the bare
  # flag/dot itself, not a filename that happens to start with '.' (e.g. .mcp.json).
  if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A($|\s)|--all($|\s)|\.($|\s))'; then
    echo "BLOCKED: 'git add .' / 'git add -A' can accidentally stage secret files." >&2
    echo "" >&2
    echo "Instead, add files explicitly by name:" >&2
    echo "  git add terraform/modules/vpc/main.tf terraform/modules/vpc/variables.tf" >&2
    echo "" >&2
    echo "Or use 'git add -p' interactively in your terminal to review each change." >&2
    echo "This protects against accidentally committing .env, .tfvars, .pem, etc." >&2
    exit 2
  fi

  # BLOCK 2: Check for specific secret-like filenames in the command
  # These patterns match actual secret FILES, not infrastructure code about secrets
  # Use word-boundary matching to avoid false positives on terraform/modules/secrets/
  SECRET_FILE_PATTERNS=(
    '\.env($|\s|/)'           # .env files (but not .envrc)
    '\.tfvars($|\s)'          # terraform.tfvars (actual secrets)
    '\.pem($|\s)'             # PEM certificates/keys
    '\.key($|\s)'             # Private key files
    '\.p12($|\s)'             # PKCS12 keystores
    '\.pfx($|\s)'             # PFX certificates
    'kubeconfig'              # Kubernetes config with cluster creds
    'aws-credentials'         # AWS credential files
    'credentials\.json'       # Service account credentials
    'credentials\.yaml'       # Credential files
  )

  for pattern in "${SECRET_FILE_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
      echo "BLOCKED: Detected potential secret file in git command." >&2
      echo "" >&2
      echo "The command appears to stage or commit a file matching: ${pattern}" >&2
      echo "" >&2
      echo "Files that may contain secrets should NEVER be committed to git." >&2
      echo "Instead:" >&2
      echo "  - Add the file to .gitignore" >&2
      echo "  - Store secrets in AWS Secrets Manager" >&2
      echo "  - Use terraform.tfvars.example with placeholder values" >&2
      echo "" >&2
      echo "If this is a false positive, run the git command directly in your terminal." >&2
      exit 2
    fi
  done
fi

exit 0
