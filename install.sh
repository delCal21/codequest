#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="

# Determine project root
PROJECT_ROOT="${VERCEL_PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT"

# Install Flutter SDK in project root (better for Vercel caching)
FLUTTER_SDK_PATH="$PROJECT_ROOT/flutter"

if [ ! -d "$FLUTTER_SDK_PATH" ]; then
  echo "Downloading Flutter SDK (stable branch)..."
  git clone --branch stable https://github.com/flutter/flutter.git --depth 1 "$FLUTTER_SDK_PATH"
else
  echo "Flutter SDK already exists, updating..."
  cd "$FLUTTER_SDK_PATH"
  git pull || true
  cd "$PROJECT_ROOT"
fi

# Add Flutter to PATH
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

# Verify Flutter installation
echo "Verifying Flutter installation..."
"$FLUTTER_SDK_PATH/bin/flutter" --version

# Enable web support
echo "Enabling Flutter web support..."
"$FLUTTER_SDK_PATH/bin/flutter" config --enable-web || true

# Precache Flutter web dependencies (speeds up builds)
echo "Precaching Flutter web dependencies..."
"$FLUTTER_SDK_PATH/bin/flutter" precache --web || true

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
"$FLUTTER_SDK_PATH/bin/flutter" pub get

echo "=== Installation complete! ==="

