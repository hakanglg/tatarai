#!/bin/sh

# Flutter CI post clone script

# Navigate to the workspace
cd $CI_WORKSPACE

# Use the system Flutter if available, otherwise install it
if command -v flutter >/dev/null 2>&1; then
  echo "Using system Flutter..."
else
  echo "Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable $CI_WORKSPACE/flutter
  export PATH="$PATH:$CI_WORKSPACE/flutter/bin"
fi

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Install CocoaPods if needed
if ! command -v pod >/dev/null 2>&1; then
  echo "Installing CocoaPods..."
  sudo gem install cocoapods
fi

# Build iOS
echo "Building iOS..."
cd ios
pod install --repo-update

# Output the current environment for debugging
echo "Environment information:"
flutter --version
pod --version
echo "CI_WORKSPACE: $CI_WORKSPACE" 