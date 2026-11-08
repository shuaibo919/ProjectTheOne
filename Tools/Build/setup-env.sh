#!/usr/bin/env bash
# Create or refresh the local build environment with uv (Python + SCons).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v uv >/dev/null 2>&1; then
	echo "uv not found. Install: https://docs.astral.sh/uv/" >&2
	exit 1
fi

cd "$REPO"
uv sync
"$REPO/.venv/Scripts/python.exe" --version
"$REPO/.venv/Scripts/python.exe" -m SCons --version | head -n 2
