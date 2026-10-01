#!/usr/bin/env bash
# Coordinate components; all storage stays behind the database interface.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
action=${1:-list}; shift || true
case "$action" in
    add)
        [[ $# -ge 2 && $# -le 4 ]] || fail 'Usage: add TITLE AUTHOR [STATUS] [RATING]'
        metadata=$(bash "$ROOT/books/fetch_book_metadata.sh" "$1" "$2")
        IFS=$'\t' read -r title author genre year link <<< "$metadata"
        bash "$ROOT/data/book_database.sh" add "$title" "$author" "$genre" "${3:-want-to-read}" "${4:-0}" "$link" "$year" ;;
    search) exec bash "$ROOT/books/search_books.sh" "$@" ;;
    list|init|update-status|update-rating|exists) exec bash "$ROOT/data/book_database.sh" "$action" "$@" ;;
    *) fail "Unknown library action: $action" ;;
esac
