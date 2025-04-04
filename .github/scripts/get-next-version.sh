#!/bin/bash
set -e

PACKAGE_NAME=$1
DEFAULT_VERSION="0.1.0"

cd packages/$PACKAGE_NAME

# Ensure semantic-release is installed
if ! command -v npx &> /dev/null; then
  echo "❌ npx not found!"
  exit 1
fi

# Updated grep pattern to match both formats that might appear in the output
VERSION=$(npx semantic-release \
  --no-ci \
  --plugins "@semantic-release/commit-analyzer,@semantic-release/release-notes-generator" \
  --debug 2>&1 | grep -oP "(?:version: '|The next release version is )\K[0-9]+\.[0-9]+\.[0-9]+" || true)

if [ -z "$VERSION" ]; then
  VERSION=$DEFAULT_VERSION
fi

echo "$VERSION"
