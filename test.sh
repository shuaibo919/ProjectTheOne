#!/usr/bin/env bash
# Run the AncientBuilding acceptance suite.
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/Tools/Test/Test-AncientBuilding.sh" "$@"
