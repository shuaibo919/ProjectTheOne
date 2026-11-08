#!/usr/bin/env bash
# Build the GDExtension modules (godot-cpp + Source) against the local engine build.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PY="$REPO/.venv/Scripts/python.exe"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 8)}"
TARGET="${TARGET:-template_debug}"

if [[ ! -f "$PY" ]]; then
	echo "missing $PY" >&2
	echo "run Tools/Build/setup-env.sh first" >&2
	exit 1
fi

export VSLANG=1033
mkdir -p "$REPO/.build-temp"
export TMP="$(cygpath -w "$REPO/.build-temp")"
export TEMP="$TMP"

cd "$REPO"
echo "Building native extensions: windows / $TARGET, -j$JOBS"
"$PY" -m SCons platform=windows "target=$TARGET" -j"$JOBS" "$@"

echo
echo "Extension binaries:"
echo "  $REPO/Project/bin/theone_core.windows.$TARGET.x86_64.dll"
echo "  $REPO/Project/bin/ancient_building.windows.$TARGET.x86_64.dll"
