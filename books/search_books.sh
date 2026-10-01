#!/usr/bin/env bash
# Accept a literal search term as one argument or one stdin line.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
[[ $# -le 1 ]] || fail 'Usage: search_books.sh [QUERY]'
if [[ $# == 1 ]]; then query=$1; else IFS= read -r query || [[ -n $query ]]; fi
exec bash "$ROOT/data/book_database.sh" search "$query"
