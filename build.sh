#!/usr/bin/env bash
# Build everything (engine if missing + native extension). Shortcut for Tools/Build/build-all.sh.
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/Tools/Build/build-all.sh" "$@"
