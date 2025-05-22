#!/bin/bash

# Define version and URLs
VERSION="v0.10.0"
FILENAME="shellcheck-${VERSION}.linux.x86_64.tar.xz"
URL="https://github.com/koalaman/shellcheck/releases/download/${VERSION}/${FILENAME}"

# Target directory
DEST_DIR="/usr/local/bin"

echo "📥 Downloading ShellCheck ${VERSION} for Linux..."
if ! curl -sSL "$URL" -o "$FILENAME"; then
  echo "❌ Failed to download ShellCheck."
  exit 1
fi

echo "📦 Extracting $FILENAME..."
tar -xf "$FILENAME"

# Extracted directory is usually named like: shellcheck-v0.10.0
EXTRACTED_DIR="shellcheck-${VERSION}"

echo "🚀 Installing to ${DEST_DIR}..."
sudo cp "${EXTRACTED_DIR}/shellcheck" "$DEST_DIR"

echo "🧹 Cleaning up..."
rm -rf "$FILENAME" "$EXTRACTED_DIR"

echo "✅ ShellCheck installed successfully!"
shellcheck --version
