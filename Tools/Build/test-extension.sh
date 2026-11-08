#!/usr/bin/env bash
# Load the built GDExtension in a headless run and verify class registration.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Isolate user data inside the repo: the engine crashes when it cannot write %APPDATA%.
APP_ROOT="$(cygpath -w "$REPO/.appdata")"
mkdir -p "$REPO/.appdata"
export APPDATA="$APP_ROOT"
export LOCALAPPDATA="$APP_ROOT"
# THEONE_APPDATA_MARK
ENGINE="${THEONE_ENGINE:-$REPO/Engine/bin/godot.windows.editor.x86_64.exe}"

if [[ ! -f "$ENGINE" ]]; then
	echo "engine not built: $ENGINE" >&2
	echo "run Tools/Build/build-engine.sh (or set THEONE_ENGINE)" >&2
	exit 1
fi

# The engine reads .godot/extension_list.cfg; generate it on a fresh clone.
"$ENGINE" --headless --editor --quit --path "$REPO/Project" >/dev/null

"$ENGINE" --headless --path "$REPO/Project" --script res://Tests/smoke_extension.gd
