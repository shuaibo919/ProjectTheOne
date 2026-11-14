#!/usr/bin/env bash
# 重新生成 AncientBuilding 参数参考（PARAMETERS.md）。
# 用法：bash Tools/AncientBuilding/generate_param_reference.sh
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
engine="$repo/Engine/bin/godot.windows.editor.x86_64.console.exe"
project="$repo/Project"

if [[ ! -x "$engine" ]]; then
  echo "Godot console not found: $engine" >&2
  echo "Run ./build.sh first or pass the repository's Engine build." >&2
  exit 1
fi

if command -v cygpath >/dev/null 2>&1; then
  export APPDATA="$(cygpath -w "$repo/.appdata")"
else
  export APPDATA="$repo/.appdata"
fi
export LOCALAPPDATA="$APPDATA"

"$engine" --headless --path "$project" \
  --script res://addons/ancient_building/cli/main.gd \
  -- params --out res://addons/ancient_building/PARAMETERS.md

echo "Regenerated: Project/addons/ancient_building/PARAMETERS.md"
