#!/bin/sh

# Flutter CI post clone script

# Navigate to the project directory
cd $CI_WORKSPACE

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable $CI_WORKSPACE/flutter
export PATH="$PATH:$CI_WORKSPACE/flutter/bin"

# Enable macOS desktop support
flutter config --enable-macos-desktop

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build iOS
echo "Building iOS..."
cd ios
pod install --repo-update

# Output the current environment for debugging
echo "Current environment:"
env 