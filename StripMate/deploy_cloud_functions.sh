#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FUNCTIONS_DIR="$ROOT_DIR/functions"

echo "Using repository functions source at: $FUNCTIONS_DIR"

if ! command -v firebase >/dev/null 2>&1; then
    echo "firebase-tools bulunamadı. Önce Firebase CLI kur."
    exit 1
fi

if [ ! -f "$FUNCTIONS_DIR/index.js" ]; then
    echo "functions/index.js bulunamadı. Deploy iptal edildi."
    exit 1
fi

if [ ! -f "$FUNCTIONS_DIR/package.json" ]; then
    echo "functions/package.json bulunamadı. Deploy iptal edildi."
    exit 1
fi

cd "$ROOT_DIR"

# Verify active Firebase project
ACTIVE_PROJECT=$(firebase use 2>/dev/null | grep -oE '[a-z0-9-]+' | head -1)
if [ -z "$ACTIVE_PROJECT" ]; then
    echo "Aktif Firebase projesi bulunamadi. 'firebase use <project-id>' ile ayarla."
    exit 1
fi
echo "Aktif proje: $ACTIVE_PROJECT"
read -p "Bu projeye deploy edilecek. Devam? (e/h) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ee]$ ]]; then
    echo "Deploy iptal edildi."
    exit 0
fi

echo "Deploying current repository Cloud Functions..."
firebase deploy --only functions
