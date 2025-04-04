#!/bin/bash
set -e

PACKAGE_NAME=$1
DEFAULT_VERSION="0.1.0"

cd packages/$PACKAGE_NAME

# Ensure semantic-release is installed
if ! command -v npx &> /dev/null; then
  echo "❌ npx not found!" >&2
  exit 1
fi

# Check if any tags exist for this package
if ! git tag -l "${PACKAGE_NAME}/v*" | grep -q .; then
  # No tags found - use first release
  VERSION="0.1.0"
else
  # Tags exist - use semantic-release to determine next version
  VERSION=$(npx semantic-release \
    --dry-run \
    --no-ci \
    --tag-format "${PACKAGE_NAME}/v\${version}" \
    --plugins "@semantic-release/commit-analyzer,@semantic-release/release-notes-generator" \
    --debug 2>&1 | grep -oP "(?:version: '|The next release version is )\K[0-9]+\.[0-9]+\.[0-9]+" || true)

  if [ -z "$VERSION" ]; then
    VERSION=$DEFAULT_VERSION
  fi
fi

# Output just the version number without any extra output
printf "%s" "${VERSION}" > /dev/null # suppress any debug output
echo "${VERSION}"
