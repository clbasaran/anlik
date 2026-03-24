#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Starting automated Firebase Security Rules deployment..."

# 1. Ensure firebase-tools is present
if ! command -v firebase &> /dev/null
then
    echo "❌ firebase-tools not found. Please run setup script first."
    exit 1
fi

echo "📝 Creating firestore.rules (Test Mode)..."
cat > firestore.rules << 'EOF'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
EOF

echo "📝 Creating storage.rules (Test Mode)..."
cat > storage.rules << 'EOF'
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true;
    }
  }
}
EOF

echo "📝 Creating firebase.json to map rules..."
cat > firebase.json << 'EOF'
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
EOF

echo "🔥 Deploying Security Rules to stripmate-app..."
firebase deploy --only firestore,storage --project stripmate-app

echo "✅ Security Rules Deployed Successfully!"
echo ""
echo "⚠️ IMPORTANT MANUAL STEP FOR AUTHENTICATION ⚠️"
echo "There is currently no stable Firebase/gcloud CLI command to programmatically enable Anonymous Authentication."
echo "You MUST explicitly enable it via the Firebase Web Console once:"
echo "1. Go to https://console.firebase.google.com/project/stripmate-app/authentication/providers"
echo "2. Click 'Add new provider' and select 'Anonymous'."
echo "3. Toggle 'Enable' and hit 'Save'."
echo "Once that manual toggle is done, the app will authenticate flawlessly."
