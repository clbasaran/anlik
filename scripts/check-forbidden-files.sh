#!/usr/bin/env bash
# Pre-commit guard: block known-secret filenames from being committed.

set -euo pipefail

PATTERNS=(
  "*.dev.vars"
  "*.env"
  "*GoogleService-Info.plist"
  "*google-services.json"
  ".codex/*"
  ".blitz/*"
  ".mcp.json"
  "*.p8"
  "*.p12"
  "*serviceAccountKey*"
  "*-credentials.json"
  "*makeAdmin*"
  "*set-admin-claim*"
  "*_debug-*"
  "firepit-log.txt"
  "android/gradle.properties"
)

blocked=0
for file in "$@"; do
  for pat in "${PATTERNS[@]}"; do
    case "$file" in
      $pat)
        echo "BLOCKED: $file matches forbidden pattern '$pat'"
        blocked=1
        break
        ;;
    esac
  done
done

if [ "$blocked" -ne 0 ]; then
  echo ""
  echo "Refusing to commit files matching forbidden patterns."
  echo "Edit scripts/check-forbidden-files.sh to update the deny list."
  exit 1
fi

exit 0
