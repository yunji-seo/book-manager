#!/usr/bin/env bash
# Input: newline-separated interests as one argument. Output: candidate TSV.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
export REC_INTERESTS=${1:-$(cat "$ROOT/config/interests.txt")}
awk -F '\t' 'BEGIN { OFS="\t"; n=split(tolower(ENVIRON["REC_INTERESTS"]),terms,"\n") }
{
    hits=0; matched=""; text=tolower($1 " " $3 " " $6)
    for(i=1;i<=n;i++) {
        term=terms[i]; gsub(/^ +| +$/,"",term)
        if(term!="" && index(text,term)) { hits++; matched=matched (matched?", ":"") term }
    }
    if(hits) print $1,$2,$3,$4,$5,50+5*hits,"interests","Matches: " matched
}' "$ROOT/books/catalog.tsv"
