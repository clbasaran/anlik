#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Starting automated Firebase configuration..."

# 1. CLI Verification
if ! command -v firebase &> /dev/null
then
    echo "⚠️ firebase-tools not found. Installing via npm..."
    npm install -g firebase-tools
else
    echo "✅ firebase-tools is installed."
fi

# 2. Authentication
echo "🔐 Ensuring Firebase CLI is authenticated..."
firebase login --reauth

# 3. Fetch Config & 4. Precise Injection
# Define the target directory path based on the Xcode 16 root group synchronization
TARGET_DIR="App"

echo "📂 Creating target directory if it doesn't exist: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "📥 Fetching GoogleService-Info.plist for celal.StripMate (stripmate-app)..."
# Download the config directly into the target directory
firebase apps:sdkconfig ios celal.StripMate --project stripmate-app --out "$TARGET_DIR/GoogleService-Info.plist"

echo "✅ Config successfully injected into $TARGET_DIR/GoogleService-Info.plist"
echo "✨ Xcode 16 PBXFileSystemSynchronizedRootGroup will automatically index this file."
echo "🎉 Firebase Setup Complete!"
