#!/usr/bin/env bash
# Launch the locally built Godot editor with the Project.
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/Tools/Build/launch-editor.sh" "$@"
