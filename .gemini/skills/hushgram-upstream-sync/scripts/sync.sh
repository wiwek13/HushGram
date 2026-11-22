#!/usr/bin/env bash
# ==============================================================================
# HushGram Upstream Sync Skill Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Identify target HushGram repository without hardcoding user personal paths
if [ -n "${HUSHGRAM_DIR:-}" ] && [ -d "${HUSHGRAM_DIR}" ]; then
    REPO_DIR="${HUSHGRAM_DIR}"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_DIR="$(git rev-parse --show-toplevel)"
elif [ -d "${HOME}/Documents/Projects/HushGram" ]; then
    REPO_DIR="${HOME}/Documents/Projects/HushGram"
else
    echo "Error: Cannot locate HushGram repository. Please set HUSHGRAM_DIR." >&2
    exit 1
fi

echo "==> Using HushGram repository at: ${REPO_DIR}"
cd "${REPO_DIR}"

# Execute upstream sync script within repository
if [ -f "scripts/upstream-sync.sh" ]; then
    exec bash scripts/upstream-sync.sh "$@"
elif [ -f "scripts/sync.sh" ]; then
    exec bash scripts/sync.sh "$@"
else
    echo "Error: scripts/upstream-sync.sh not found in ${REPO_DIR}" >&2
    exit 1
fi
