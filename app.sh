#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -f "$ROOT/gum.exe" ]]; then
    export PATH="$ROOT:$PATH"
fi
if ! command -v gum >/dev/null 2>&1; then
    printf 'Gum is required. See README.md for installation instructions.\n' >&2
    exit 1
fi
exec bash "$ROOT/ui/main_menu.sh"
