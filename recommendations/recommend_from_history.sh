#!/usr/bin/env bash
# Optional argument: a library TSV snapshot. Standalone use asks the data layer.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
snapshot=${1:-/dev/stdin}
if [[ $# == 0 ]]; then
    bash "$ROOT/data/book_database.sh" list | bash "${BASH_SOURCE[0]}" /dev/stdin
    exit
fi
awk -F '\t' 'BEGIN { OFS="\t" }
FILENAME!=ARGV[2] {
    weight=2; if($4=="reading") weight=3; if($4=="finished") weight=4
    if($5>0) weight=$5-2
    genre[tolower($3)]+=weight; author[tolower($2)]+=weight
    next
}
{
    affinity=genre[tolower($3)]+author[tolower($2)]
    if(affinity>0) {
        score=60+affinity; if(score>90) score=90
        print $1,$2,$3,$4,$5,score,"history","Similar to saved genres/authors; affinity " affinity
    }
}' "$snapshot" "$ROOT/books/catalog.tsv"
