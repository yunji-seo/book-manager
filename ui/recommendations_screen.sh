#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
gum style --foreground 39 'CITY / SHELF - Recommendations' 'Three parallel perspectives, including one exploration slot.'
interests=$(cat "$ROOT/config/interests.txt")
choice=$(gum choose 'Use saved interests' 'Enter interests for this session' 'Back') || exit 0
case "$choice" in
    Back) exit 0 ;;
    'Enter interests for this session')
        interests=$(gum input --prompt 'Interests > ' --placeholder 'urban planning,housing,transport') || exit 0
        interests=${interests//,/$'\n'} ;;
esac
printf 'Interests:\n%s\n' "$interests"
# Progress goes to stderr and remains visible while stdout captures only rows.
rows=$(bash "$ROOT/workflows/get_recommendations.sh" 5 "$interests")
[[ -n $rows ]] || { gum style 'No new candidates. Try other interests or extend books/catalog.tsv.'; exit 0; }
while :; do
    options=$(printf '%s\n' "$rows" | awk -F '\t' '{printf "%d. %s | %s | %s (%s)\n",NR,$1,$3,$7,$6}')
    selected=$(printf '%s\nBack\n' "$options" | gum choose) || exit 0
    [[ $selected != Back ]] || exit 0
    number=${selected%%.*}
    row=$(printf '%s\n' "$rows" | sed -n "${number}p")
    IFS=$'\t' read -r title author genre year link score strategy reason <<< "$row"
    gum style --border rounded --padding '1 2' -- "$title" "$author | $year" "$genre | $strategy | score $score" "$reason" "$link"
    if gum confirm 'Save to your want-to-read shelf?'; then
        if bash "$ROOT/workflows/manage_library.sh" add "$title" "$author" want-to-read; then
            gum style --foreground 42 'Saved to your library.'
            exit 0
        fi
    fi
done
