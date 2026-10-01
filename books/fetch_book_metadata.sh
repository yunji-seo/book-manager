#!/usr/bin/env bash
# Input: title and author. Output: title, author, genre, year, link (TSV).
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
[[ $# == 2 ]] || fail 'Usage: fetch_book_metadata.sh TITLE AUTHOR'
valid_text "$1"; valid_text "$2"
export META_TITLE=$1 META_AUTHOR=$2
awk -F '\t' 'BEGIN { OFS="\t" }
function norm(s) { gsub(/^ +| +$/,"",s); gsub(/ +/," ",s); return tolower(s) }
norm($1)==norm(ENVIRON["META_TITLE"]) && norm($2)==norm(ENVIRON["META_AUTHOR"]) {
    print $1,$2,$3,$4,$5; found=1; exit
}
END { if(!found) print ENVIRON["META_TITLE"],ENVIRON["META_AUTHOR"],"Unknown","-","-" }
' "$ROOT/books/catalog.tsv"
