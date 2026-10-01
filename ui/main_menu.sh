#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
bash "$ROOT/workflows/manage_library.sh" init
while :; do
    gum style --foreground 39 --border rounded --padding '1 2' 'CITY / SHELF' 'A reading map for urban planning'
    choice=$(gum choose 'Browse Library' 'Add Book' 'Search Library' 'Get Recommendations' 'Quit') || exit 0
    case "$choice" in
        'Browse Library') bash "$ROOT/ui/library_screen.sh" browse || true ;;
        'Add Book') bash "$ROOT/ui/library_screen.sh" add || true ;;
        'Search Library') bash "$ROOT/ui/library_screen.sh" search || true ;;
        'Get Recommendations') bash "$ROOT/ui/recommendations_screen.sh" || true ;;
        Quit) exit 0 ;;
    esac
done
