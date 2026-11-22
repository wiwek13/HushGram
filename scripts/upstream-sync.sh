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
ARGUS_URL="https://github.com/argus2968/HushGram.git"
TARGET_BRANCH="${1:-main}"

# Ensure Java 21 environment for Android SDK 36 tests
if [ -z "${JAVA_HOME:-}" ] || ! "${JAVA_HOME}/bin/java" -version 2>&1 | grep -q 'version "2[1-9]'; then
    if [ -d "/opt/homebrew/Cellar/openjdk@21/21.0.13.1/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="/opt/homebrew/Cellar/openjdk@21/21.0.13.1/libexec/openjdk.jdk/Contents/Home"
    elif [ -d "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    elif command -v /usr/libexec/java_home >/dev/null 2>&1 && /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
        export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
    fi
fi
if [ -n "${JAVA_HOME:-}" ]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
fi

echo "==> Using Java: $(java -version 2>&1 | head -n 1)"

echo "==> Checking git remote configurations..."
if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "Adding upstream remote: ${UPSTREAM_URL}"
    git remote add upstream "${UPSTREAM_URL}"
fi

if ! git remote get-url argus >/dev/null 2>&1; then
    echo "Adding argus remote: ${ARGUS_URL}"
    git remote add argus "${ARGUS_URL}"
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
    echo "==> Repository is already up-to-date with upstream. Running validation check..."
    python3 scripts/gen-l10n.py
    ./gradlew :extensions:instagram:testDebugUnitTest --tests "app.hushgram.extension.instagram.profile.*" -F lenient
    ./gradlew :patches:test -F lenient
    echo "==> Up-to-date and all tests passed!"
    exit 0
fi

echo "==> New upstream commits detected. Starting reconciliation..."

# Attempt a merge without committing to inspect and resolve conflicts
if ! git merge --no-commit "upstream/${UPSTREAM_BRANCH}"; then
    echo "==> Merge conflicts encountered. Applying intelligent follower-history reconciliation..."

    # 1. Protect standalone follower-history files
    for file in \
        extensions/instagram/src/main/java/app/hushgram/extension/instagram/profile/FollowersCheck.java \
        extensions/instagram/src/main/java/app/hushgram/extension/instagram/profile/FollowersChip.java \
        extensions/instagram/src/main/java/app/hushgram/extension/instagram/settings/FollowersScreen.java \
        extensions/instagram/src/test/java/app/hushgram/extension/instagram/profile/FollowerHistoryTest.java; do
        if git show "HEAD:${file}" >/dev/null 2>&1; then
            git checkout HEAD -- "${file}"
            git add "${file}"
        fi
    done

    # 2. Check for unresolved conflicts in hook files
    UNRESOLVED=$(git diff --name-only --diff-filter=U || true)
    if [ -n "${UNRESOLVED}" ]; then
        echo "==> Unresolved conflicting files require review:"
        echo "${UNRESOLVED}"
    fi
fi

echo "==> Validating and compiling localization catalogs..."
python3 scripts/gen-l10n.py
git add extensions/shared/library/src/main/java/app/hushgram/extension/shared/L10nTranslations.java extensions/shared/library/src/main/l10n/*.tsv 2>/dev/null || true

echo "==> Synchronizing patch catalog and documentation..."
./gradlew :patches:generatePatchesList -F lenient
python3 scripts/gen-readme-patches.py
git add patches-list.json README.md 2>/dev/null || true

echo "==> Executing targeted test verification suite..."
./gradlew :extensions:instagram:testDebugUnitTest --tests "app.hushgram.extension.instagram.profile.*" -F lenient
./gradlew :patches:test -F lenient

echo "==> Sync and verification completed successfully!"
