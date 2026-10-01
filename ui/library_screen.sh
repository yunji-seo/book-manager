#!/usr/bin/env bash
# Interaction only: obtain input, invoke a workflow, display returned rows.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
workflow=$ROOT/workflows/manage_library.sh
case "${1:-browse}" in
    add)
        title=$(gum input --prompt 'Title > ' --placeholder 'The Image of the City') || exit 0
        author=$(gum input --prompt 'Author > ' --placeholder 'Kevin Lynch') || exit 0
        status=$(gum choose want-to-read owned reading finished) || exit 0
        if bash "$workflow" add "$title" "$author" "$status"; then
            gum style --foreground 42 'Book saved. Known titles receive offline metadata.'
        fi
        exit ;;
    search)
        query=$(gum input --prompt 'Search > ' --placeholder 'Title, author, genre or status') || exit 0
        rows=$(bash "$workflow" search "$query") ;;
    browse) rows=$(bash "$workflow" list) ;;
    *) fail 'Usage: library_screen.sh [browse|add|search]' ;;
esac
if [[ -z $rows ]]; then gum style 'No matching books. Add a book to start your library.'; exit 0; fi
while :; do
    # Unique numeric prefixes make selection safe even for identical display titles.
    options=$(printf '%s\n' "$rows" | awk -F '\t' '{printf "%d. %s | %s | %s | rating %s\n",NR,$1,$2,$4,$5}')
    selected=$(printf '%s\nBack\n' "$options" | gum choose) || exit 0
    [[ $selected != Back ]] || exit 0
    number=${selected%%.*}
    row=$(printf '%s\n' "$rows" | sed -n "${number}p")
    IFS=$'\t' read -r title author genre status rating link year <<< "$row"
    gum style --border rounded --padding '1 2' -- "$title" "$author" "$genre | $year" "Status: $status | Rating: $rating/5 (0 = unrated)" "$link"
    action=$(gum choose 'Update Status' 'Update Rating' 'Back') || exit 0
    case "$action" in
        'Update Status')
            value=$(gum choose owned want-to-read reading finished) || exit 0
            bash "$workflow" update-status "$title" "$author" "$value" ;;
        'Update Rating')
            value=$(gum choose 0 1 2 3 4 5) || exit 0
            bash "$workflow" update-rating "$title" "$author" "$value" ;;
        Back) continue ;;
    esac
    gum style --foreground 42 'Updated.'
    exit 0
done
