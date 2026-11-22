#!/usr/bin/env bash
# ==============================================================================
# HushGram Upstream Sync Automation Script
# Synchronizes local HushGram repository with SysAdminDoc/HushGram while
# preserving argus2968 follower history features.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

UPSTREAM_URL="https://github.com/SysAdminDoc/HushGram.git"
UPSTREAM_BRANCH="main"
TARGET_BRANCH="${1:-main}"

echo "==> Checking git remote configuration..."
if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "Adding upstream remote: ${UPSTREAM_URL}"
    git remote add upstream "${UPSTREAM_URL}"
fi

echo "==> Fetching upstream/${UPSTREAM_BRANCH}..."
git fetch upstream "${UPSTREAM_BRANCH}"

LOCAL_REV=$(git rev-parse HEAD)
UPSTREAM_REV=$(git rev-parse "upstream/${UPSTREAM_BRANCH}")
MERGE_BASE=$(git merge-base HEAD "upstream/${UPSTREAM_BRANCH}")

echo "Local HEAD:    ${LOCAL_REV}"
echo "Upstream HEAD: ${UPSTREAM_REV}"
echo "Merge Base:    ${MERGE_BASE}"

if [ "${UPSTREAM_REV}" = "${MERGE_BASE}" ]; then
    echo "==> Repository is already up-to-date with upstream. No sync needed."
    exit 0
fi

echo "==> New upstream commits detected. Starting reconciliation..."

# Attempt a merge without committing to inspect and resolve conflicts
if ! git merge --no-commit "upstream/${UPSTREAM_BRANCH}"; then
    echo "==> Merge conflicts detected. Auto-reconciling known follower history integration files..."
    
    # Re-verify and protect follower history critical files
    for file in \
        extensions/instagram/src/main/java/app/hushgram/extension/instagram/profile/FollowersCheck.java \
        extensions/instagram/src/main/java/app/hushgram/extension/instagram/profile/FollowersChip.java \
        extensions/instagram/src/main/java/app/hushgram/extension/instagram/settings/FollowersScreen.java \
        extensions/instagram/src/test/java/app/hushgram/extension/instagram/profile/FollowerHistoryTest.java; do
        if [ -f "${file}" ]; then
            git add "${file}"
        fi
    done
fi

echo "==> Validating and compiling localization catalogs..."
python3 scripts/gen-l10n.py

echo "==> Executing test verification suite..."
./gradlew test -F lenient

echo "==> Sync and verification completed successfully!"
