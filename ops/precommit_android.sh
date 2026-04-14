#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT}/ops/check_android_naming_gate.py"
"${ROOT}/ops/android_terminal_host.py" deploy

echo "android-precommit: clean"
