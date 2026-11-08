#!/usr/bin/env bash
# Run the project with the locally built engine (main scene is not defined yet).
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
	exit 1
fi

exec "$ENGINE" --path "$REPO/Project" "$@"
