#!/bin/bash
set -e

echo "=== Building Flutter web app ==="

# Determine project root
PROJECT_ROOT="${VERCEL_PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT"

# Flutter SDK path (should be in project root)
FLUTTER_SDK_PATH="$PROJECT_ROOT/flutter"

# Verify Flutter is available
if [ ! -f "$FLUTTER_SDK_PATH/bin/flutter" ]; then
  echo "Error: Flutter not found. Running install script..."
  bash install.sh
fi

# Add Flutter to PATH
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

# Use full path to flutter to be safe
FLUTTER_CMD="$FLUTTER_SDK_PATH/bin/flutter"

# Verify Flutter works
echo "Verifying Flutter installation..."
$FLUTTER_CMD --version

# Ensure we're in the project root
cd "$PROJECT_ROOT"

# Clean previous build
echo "Cleaning previous build..."
$FLUTTER_CMD clean || true

# Get dependencies (in case install.sh didn't run)
echo "Getting Flutter dependencies..."
$FLUTTER_CMD pub get

# Build Flutter web app
echo "Building Flutter web app (release mode)..."
$FLUTTER_CMD build web --release

echo "=== Build complete! ==="

