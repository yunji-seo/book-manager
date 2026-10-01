#!/usr/bin/env bash
# Fan out with &, capture $!, synchronize with wait, then combine through a pipe.
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
limit=${1:-5}
interests=${2:-$(cat "$ROOT/config/interests.txt")}
scratch=$(mktemp -d)
pids=(); names=(history interests discovery)
cleanup() {
    local pid
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
    rm -rf -- "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
bash "$ROOT/data/book_database.sh" list > "$scratch/library.tsv"
printf '[running] history + interests + discovery\n' >&2
bash "$ROOT/recommendations/recommend_from_history.sh" "$scratch/library.tsv" > "$scratch/history" &
pids+=("$!")
bash "$ROOT/recommendations/recommend_from_interests.sh" "$interests" > "$scratch/interests" &
pids+=("$!")
bash "$ROOT/recommendations/recommend_for_discovery.sh" "$scratch/library.tsv" "$interests" > "$scratch/discovery" &
pids+=("$!")
started=$SECONDS
while :; do
    active=0
    for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then active=$((active+1)); fi; done
    [[ $active -gt 0 ]] || break
    printf '[running] %s agent(s); %ss elapsed\n' "$active" "$((SECONDS-started))" >&2
    sleep 0.2
done
failed=0
for i in "${!pids[@]}"; do
    if wait "${pids[$i]}"; then printf '[done] %s\n' "${names[$i]}" >&2
    else printf '[failed] %s\n' "${names[$i]}" >&2; failed=1; fi
done
pids=()
[[ $failed == 0 ]] || fail 'A recommendation agent failed; no partial result returned.'
printf '[refining] deduplicate, exclude library, rank, reserve exploration slot\n' >&2
cat "$scratch/history" "$scratch/interests" "$scratch/discovery" |
    bash "$ROOT/recommendations/refine_recommendations.sh" "$limit" "$scratch/library.tsv"
