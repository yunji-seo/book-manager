#!/usr/bin/env bash
# Explore genres absent from the library AND outside stated interests.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
if [[ $# == 0 ]]; then
    bash "$ROOT/data/book_database.sh" list | bash "${BASH_SOURCE[0]}" /dev/stdin "$(cat "$ROOT/config/interests.txt")"
    exit
fi
export REC_INTERESTS=${2:-$(cat "$ROOT/config/interests.txt")}
awk -F '\t' 'BEGIN { OFS="\t"; n=split(tolower(ENVIRON["REC_INTERESTS"]),terms,"\n") }
FILENAME!=ARGV[2] { seen[tolower($3)]=1; next }
{
    familiar=seen[tolower($3)]; text=tolower($1 " " $3 " " $6)
    for(i=1;i<=n;i++) {
        term=terms[i]; gsub(/^ +| +$/,"",term)
        if(term!="" && index(text,term)) familiar=1
    }
    if(!familiar) print $1,$2,$3,$4,$5,35,"discovery","Explore an unfamiliar field: " $3
}' "$1" "$ROOT/books/catalog.tsv"
