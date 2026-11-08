#!/usr/bin/env bash
# One-command build: engine (if missing) then the native extension.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE="$REPO/Engine/bin/godot.windows.editor.x86_64.exe"

if [[ ! -f "$ENGINE" ]]; then
	echo "Engine binary not found, building the engine first."
	"$REPO/Tools/Build/build-engine.sh"
fi

"$REPO/Tools/Build/build-native.sh" "$@"
echo
echo "Ready: $ENGINE"
