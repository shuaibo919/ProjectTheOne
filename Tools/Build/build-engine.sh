#!/usr/bin/env bash
# Build the Godot editor from the Engine/ submodule (source-local).
# No borrowed binaries: the editor used by this project is produced here.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PY="$REPO/.venv/Scripts/python.exe"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 8)}"

if [[ ! -f "$PY" ]]; then
	echo "missing $PY" >&2
	echo "run Tools/Build/setup-env.sh first" >&2
	exit 1
fi

export VSLANG=1033
mkdir -p "$REPO/.build-temp"
export TMP="$(cygpath -w "$REPO/.build-temp")"
export TEMP="$TMP"

cd "$REPO/Engine"
echo "Building Engine: windows / editor / x86_64, -j$JOBS (angle disabled)"
"$PY" -m SCons platform=windows target=editor arch=x86_64 angle=no with_hj_game=yes -j"$JOBS" "$@"

echo
echo "Engine binary: $REPO/Engine/bin/godot.windows.editor.x86_64.exe"
