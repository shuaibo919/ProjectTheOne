#!/usr/bin/env bash
# AncientBuilding acceptance suite (M1-M5), Git Bash edition.
# Mirrors Tools/Test/Test-AncientBuilding.ps1 without PowerShell.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Isolate user data inside the repo: the engine crashes when it cannot write %APPDATA%.
APP_ROOT="$(cygpath -w "$REPO/.appdata")"
mkdir -p "$REPO/.appdata"
export APPDATA="$APP_ROOT"
export LOCALAPPDATA="$APP_ROOT"
# THEONE_APPDATA_MARK
ENGINE="${THEONE_ENGINE:-$REPO/Engine/bin/godot.windows.editor.x86_64.exe}"
PROJECT="$REPO/Project"
CLI="res://addons/ancient_building/cli/main.gd"
PRESET="res://addons/ancient_building/resources/presets/DA_House_A.json"
SCENE="res://Generated/AncientBuilding/Samples/DA_House_A.tscn"
SCENE_FILE="$PROJECT/Generated/AncientBuilding/Samples/DA_House_A.tscn"

FAILS=0

check() {
	local label="$1"
	shift
	if "$@"; then
		echo "ok   $label"
	else
		echo "FAIL $label"
		FAILS=$((FAILS + 1))
	fi
}

contains() {
	printf '%s' "$2" | grep -qF -- "$1"
}

engine_run() {
	"$ENGINE" --headless --path "$PROJECT" "$@" 2>&1
}

cli() {
	engine_run --script "$CLI" -- "$@"
}

if [[ ! -f "$ENGINE" ]]; then
	echo "engine not built: $ENGINE" >&2
	echo "run ./build.sh first (or set THEONE_ENGINE)" >&2
	exit 1
fi

# Extension list must exist before headless runs on a fresh clone.
"$ENGINE" --headless --editor --quit --path "$PROJECT" >/dev/null 2>&1

for tool in test_module_key test_layout test_roof test_batch; do
	check "unit check $tool.gd" "$ENGINE" --headless --path "$PROJECT" --script "res://Tests/Checks/$tool.gd" >/dev/null 2>&1
done

rm -f "$SCENE_FILE"

build=$(cli build --file "$PRESET")
check "build exits with 46 instances" contains '"instances": 46' "$build"
check "build reports 9 unique meshes" contains '"unique_meshes": 9' "$build"
check "build reports no errors" contains '"errors": []' "$build"

bake=$(cli bake --file "$PRESET" --out "$SCENE")
check "bake exits" contains '"instances": 46' "$bake"
check "baked scene exists" test -f "$SCENE_FILE"

individual=$(cli inspect --scene "$SCENE")
check "baked scene holds 46 nodes" contains '"children": 46' "$individual"
check "baked nodes are MeshInstance3D" contains '"MeshInstance3D": 46' "$individual"

convert=$(cli convert --scene "$SCENE")
check "convert groups into 9 MultiMeshes" contains '"groups": 9' "$convert"
check "convert keeps 46 instances" contains '"instances": 46' "$convert"

batched=$(cli inspect --scene "$SCENE")
check "converted scene holds 9 nodes" contains '"children": 9' "$batched"
check "converted nodes are MultiMeshInstance3D" contains '"MultiMeshInstance3D": 9' "$batched"

revert=$(cli revert --scene "$SCENE")
check "revert exits" contains '"instances": 46' "$revert"

restored=$(cli inspect --scene "$SCENE")
check "reverted scene holds 46 nodes" contains '"children": 46' "$restored"

hash_build=$(printf '%s' "$build" | grep -o '"layout_hash": "[^"]*"' | head -n 1)
hash_final=$(printf '%s' "$restored" | grep -o '"layout_hash": "[^"]*"' | head -n 1)
check "layout hash survives bake/convert/revert" test "$hash_build" = "$hash_final"

echo
if [[ "$FAILS" -gt 0 ]]; then
	echo "ANCIENTBUILDING CHECK FAILED: $FAILS assertion(s)"
	exit 1
fi
echo "ANCIENTBUILDING CHECK PASSED"
