#!/bin/bash
set -e

echo "Installing Flutter SDK..."

# Install Flutter SDK
FLUTTER_SDK_PATH="$HOME/flutter"

if [ ! -d "$FLUTTER_SDK_PATH" ]; then
  echo "Downloading Flutter SDK (stable branch)..."
  cd $HOME
  git clone --branch stable https://github.com/flutter/flutter.git --depth 1 $FLUTTER_SDK_PATH
fi

# Add Flutter to PATH
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

# Precache Flutter web dependencies (speeds up builds)
echo "Precaching Flutter web dependencies..."
flutter precache --web || true

# Verify Flutter installation
echo "Flutter version:"
flutter --version

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

echo "Installation complete!"

