#!/usr/bin/env bash
# The ONLY component that opens library CSV storage. Public rows are TSV.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
db=${BOOK_DB:-"$ROOT/data/books.csv"}
export DB_OP=${1:-list}
shift || true
case "$DB_OP" in
    init|list) [[ $# == 0 ]] || fail 'Unexpected arguments.' ;;
    search) [[ $# == 1 ]] || fail 'Usage: search QUERY'; export DB_QUERY=$1 ;;
    exists) [[ $# == 2 ]] || fail 'Usage: exists TITLE AUTHOR'; export DB_TITLE=$1 DB_AUTHOR=$2 ;;
    add)
        [[ $# == 7 ]] || fail 'Usage: add TITLE AUTHOR GENRE STATUS RATING LINK YEAR'
        for value in "$@"; do valid_text "$value"; done
        export DB_TITLE=$1 DB_AUTHOR=$2 DB_GENRE=$3 DB_STATUS=$4 DB_RATING=$5 DB_LINK=$6 DB_YEAR=$7 ;;
    update-status|update-rating)
        [[ $# == 3 ]] || fail 'Usage: update-status/update-rating TITLE AUTHOR VALUE'
        for value in "$@"; do valid_text "$value"; done
        export DB_TITLE=$1 DB_AUTHOR=$2
        if [[ $DB_OP == update-status ]]; then export DB_STATUS=$3; else export DB_RATING=$3; fi ;;
    *) fail "Unknown database operation: $DB_OP" ;;
esac
if [[ $DB_OP == add || $DB_OP == update-status ]]; then
    case "$DB_STATUS" in owned|want-to-read|reading|finished) ;; *) fail 'Invalid reading status.' ;; esac
fi
if [[ $DB_OP == add || $DB_OP == update-rating ]]; then
    [[ $DB_RATING =~ ^[0-5]$ ]] || fail 'Rating must be 0 (unrated) or 1-5.'
fi
if [[ $DB_OP == add ]]; then
    [[ $DB_YEAR == '-' || $DB_YEAR =~ ^[0-9]{4}$ ]] || fail 'Year must be four digits or -.'
fi
directory=$(dirname -- "$db")
[[ -d $directory ]] || mkdir -p -- "$directory"
temp=''; locked=false
cleanup() {
    [[ -z $temp ]] || rm -f -- "$temp"
    if $locked; then rmdir -- "$db.lock"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
lock() {
    local attempt
    for ((attempt=0; attempt<50; attempt++)); do
        if mkdir -- "$db.lock" 2>/dev/null; then locked=true; return; fi
        sleep 0.1
    done
    fail "Database is busy ($db.lock)."
}
# Reads see either the old complete file or the new complete file.
case "$DB_OP" in add|update-*) lock ;; esac
if [[ ! -f $db ]]; then
    $locked || lock
    if [[ ! -f $db ]]; then
        temp=$(mktemp "$db.tmp.XXXXXX")
        printf 'title,author,genre,status,rating,link,year\n' > "$temp"
        mv -- "$temp" "$db"; temp=''
    fi
fi
case "$DB_OP" in
    init) ;;
    add|update-*)
        temp=$(mktemp "$db.tmp.XXXXXX")
        awk -f "$ROOT/data/csv_operations.awk" "$db" > "$temp"
        mv -- "$temp" "$db"; temp='' ;;
    *) awk -f "$ROOT/data/csv_operations.awk" "$db" ;;
esac
