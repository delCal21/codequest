#!/bin/bash
set -e

echo "Building Flutter web app..."

# Add Flutter to PATH (in case install.sh wasn't run)
FLUTTER_SDK_PATH="$HOME/flutter"
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

# Verify Flutter is available
if ! command -v flutter &> /dev/null; then
  echo "Error: Flutter not found. Running install script..."
  bash install.sh
fi

# Build Flutter web app
echo "Running flutter build web --release..."
flutter build web --release

echo "Build complete!"

