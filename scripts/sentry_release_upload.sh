#!/usr/bin/env bash
# Upload Flutter release symbols to Sentry (Android mapping via Gradle plugin; Dart + iOS via CLI).
#
# Required env:
#   SENTRY_AUTH_TOKEN
#   SENTRY_ORG
#   SENTRY_PROJECT (default: flutter)
#
# Usage (from frontend/):
#   VERSION=1.0.0 BUILD=37 ./scripts/sentry_release_upload.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-37}"
RELEASE="matchvibe@${VERSION}+${BUILD}"
ORG="${SENTRY_ORG:?Set SENTRY_ORG}"
PROJECT="${SENTRY_PROJECT:-flutter}"
AUTH="${SENTRY_AUTH_TOKEN:?Set SENTRY_AUTH_TOKEN}"

echo "Creating Sentry release ${RELEASE}..."
sentry-cli releases new "$RELEASE" --org "$ORG" --project "$PROJECT" --auth-token "$AUTH"
sentry-cli releases set-commits "$RELEASE" --auto --org "$ORG" --project "$PROJECT" --auth-token "$AUTH" || true

if [[ -d "build/app/outputs/symbols" ]]; then
  echo "Uploading Dart symbol files..."
  sentry-cli dart-symbol-files upload build/app/outputs/symbols \
    --org "$ORG" --project "$PROJECT" --auth-token "$AUTH"
fi

if [[ -d "build/ios/iphoneos/Runner.app.dSYM" ]]; then
  echo "Uploading iOS dSYM..."
  sentry-cli debug-files upload build/ios/iphoneos/Runner.app.dSYM \
    --org "$ORG" --project "$PROJECT" --auth-token "$AUTH"
fi

sentry-cli releases finalize "$RELEASE" --org "$ORG" --project "$PROJECT" --auth-token "$AUTH"
echo "Done: ${RELEASE}"
