#!/usr/bin/env bash
# Launch the locally built editor with the Project.
# Builds the engine first when the binary is missing.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Isolate user data inside the repo: the engine crashes when it cannot write %APPDATA%.
APP_ROOT="$(cygpath -w "$REPO/.appdata")"
mkdir -p "$REPO/.appdata"
export APPDATA="$APP_ROOT"
export LOCALAPPDATA="$APP_ROOT"
# THEONE_APPDATA_MARK
ENGINE="$REPO/Engine/bin/godot.windows.editor.x86_64.exe"

if [[ ! -f "$ENGINE" ]]; then
	echo "Engine binary not found, building the engine first."
	"$REPO/Tools/Build/build-engine.sh"
fi

exec "$ENGINE" --editor --path "$REPO/Project" "$@"
