#!/usr/bin/env bash
# stdin: 8-field candidates. stdout: up to LIMIT candidates, score descending.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
limit=${1:-5}
[[ $limit =~ ^[1-9][0-9]?$ ]] || fail 'Limit must be 1-99.'
snapshot=${2:-}
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
if [[ -z $snapshot ]]; then
    snapshot=$scratch/library.tsv
    bash "$ROOT/data/book_database.sh" list > "$snapshot"
fi
# Strongest duplicate wins. Title+author comparison ignores case and extra spaces.
sort -t $'\t' -k6,6nr -k1,1 | awk -F '\t' '
function norm(s) { gsub(/^ +| +$/,"",s); gsub(/ +/," ",s); return tolower(s) }
FILENAME!=ARGV[2] { owned[norm($1) SUBSEP norm($2)]=1; next }
NF==8 && $6 ~ /^[0-9]+$/ {
    k=norm($1) SUBSEP norm($2)
    if(!owned[k] && !seen[k]++) print
}' "$snapshot" - > "$scratch/unique.tsv"
# Reserve one slot for exploration; otherwise high-similarity scores crowd it out.
awk -F '\t' -v limit="$limit" '
{ row[NR]=$0; if($7=="discovery" && !discovery) discovery=NR }
END {
    slots=limit-(discovery?1:0); count=0
    for(i=1;i<=NR && count<slots;i++) if(i!=discovery) { print row[i]; count++ }
    if(discovery) print row[discovery]
}' "$scratch/unique.tsv" | sort -t $'\t' -k6,6nr -k1,1
