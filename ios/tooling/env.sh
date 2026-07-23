#!/usr/bin/env bash
# Source before flutter/ios commands when xcode-select still points at CLT:
#   source ios/tooling/env.sh
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="${ROOT}/ios/tooling:${PATH}"
