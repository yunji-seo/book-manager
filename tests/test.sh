#!/usr/bin/env bash
# Integration tests use an isolated database and never change the user's shelf.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export BOOK_DB=$scratch/books.csv
passed=0
ok() { passed=$((passed+1)); printf 'PASS %02d %s\n' "$passed" "$1"; }
db() { bash "$ROOT/data/book_database.sh" "$@"; }
manage() { bash "$ROOT/workflows/manage_library.sh" "$@"; }
reject() { if "$@" > "$scratch/rejected.out" 2> "$scratch/rejected.err"; then printf 'FAIL expected rejection\n' >&2; exit 1; fi; }
db init
[[ -z $(db list) ]]; ok 'new library starts empty'
manage add 'The Image of the City' 'Kevin Lynch' reading 4
row=$(db list)
[[ $row == *$'Urban Planning\treading\t4'* && $row == *$'\t1960' ]]; ok 'metadata enrichment and persistence'
db exists ' the image OF the city ' 'KEVIN LYNCH'; ok 'normalized identity lookup'
reject manage add 'THE IMAGE OF THE CITY' 'Kevin Lynch'
[[ $(db list | wc -l) == 1 ]]; ok 'duplicate rejected without changing library'
manage update-status 'The Image of the City' 'Kevin Lynch' finished
manage update-rating 'The Image of the City' 'Kevin Lynch' 5
[[ $(db list) == *$'finished\t5'* ]]; ok 'status and rating updates'
before=$(db list)
reject manage update-rating 'The Image of the City' 'Kevin Lynch' 6
reject manage update-status 'The Image of the City' 'Kevin Lynch' missing
reject manage update-status 'Not here' 'Nobody' finished
[[ $(db list) == "$before" ]]; ok 'invalid updates are atomic'
manage add 'Comma, "Quote" and \ Slash' 'An Author' owned
[[ $(db search 'Comma,') == $'Comma, "Quote" and \\ Slash\tAn Author\tUnknown\towned\t0\t-\t-' ]]; ok 'CSV commas, quotes and backslashes round trip'
manage add '도시와 공간' '김도시'
[[ $(db search '도시') == *'김도시'* ]]; ok 'Korean text round trip'
reject manage add $'Bad\tTitle' Author
reject manage add $'Bad\nTitle' Author
reject manage add '' Author
ok 'empty and multiline fields rejected'
[[ $(bash "$ROOT/books/search_books.sh" 'LYNCH') == "$(printf 'LYNCH\n' | bash "$ROOT/books/search_books.sh")" ]]; ok 'argument and stdin search agree'
[[ -z $(db search '[.*]') ]]; ok 'search is literal, not a regular expression'
db list > "$scratch/library.tsv"
bash "$ROOT/recommendations/recommend_from_history.sh" "$scratch/library.tsv" > "$scratch/history"
[[ -s $scratch/history ]]; ok 'history uses saved genres and ratings'
bash "$ROOT/recommendations/recommend_from_interests.sh" housing > "$scratch/interests"
grep -q 'Evicted' "$scratch/interests"; ok 'interests match catalog topics'
bash "$ROOT/recommendations/recommend_for_discovery.sh" "$scratch/library.tsv" 'urban planning' > "$scratch/discovery"
[[ -s $scratch/discovery ]]
if grep -q $'\tUrban Planning\t' "$scratch/discovery"; then exit 1; fi
ok 'discovery avoids familiar and requested fields'
cat "$scratch/history" "$scratch/history" "$scratch/interests" "$scratch/discovery" |
    bash "$ROOT/recommendations/refine_recommendations.sh" 5 > "$scratch/refined"
[[ $(wc -l < "$scratch/refined") == 5 ]]
[[ $(cut -f1,2 "$scratch/refined" | sort -u | wc -l) == 5 ]]
if grep -q '^The Image of the City' "$scratch/refined"; then exit 1; fi
grep -q $'\tdiscovery\t' "$scratch/refined"
ok 'pipeline deduplicates, excludes owned books and reserves exploration'
printf '' | bash "$ROOT/recommendations/refine_recommendations.sh" > "$scratch/empty"
[[ ! -s $scratch/empty ]]; ok 'empty input yields empty shortlist'
reject bash "$ROOT/recommendations/refine_recommendations.sh" 0
ok 'invalid shortlist limit rejected'
bash "$ROOT/workflows/get_recommendations.sh" > "$scratch/final" 2> "$scratch/progress"
[[ $(wc -l < "$scratch/final") == 5 ]]
[[ $(grep -c '^\[done\]' "$scratch/progress") == 3 ]]
awk -F '\t' 'NF!=8 {exit 1}' "$scratch/final"
ok 'workflow separates clean data from progress'
# Concurrent writes must not lose either update.
manage add 'Concurrent A' 'Test Author' & a=$!
manage add 'Concurrent B' 'Test Author' & b=$!
wait "$a"; wait "$b"
db exists 'Concurrent A' 'Test Author'; db exists 'Concurrent B' 'Test Author'
ok 'concurrent database writes preserve both records'
# A three-party barrier fails if the workflow launches agents sequentially.
cp -R "$ROOT" "$scratch/project"
export TEST_BARRIER=$scratch/barrier
mkdir "$TEST_BARRIER"
for name in history interests discovery; do
    case "$name" in
        history) file=recommend_from_history.sh ;;
        interests) file=recommend_from_interests.sh ;;
        discovery) file=recommend_for_discovery.sh ;;
    esac
    mv "$scratch/project/recommendations/$file" "$scratch/project/recommendations/$file.real"
    {
        printf '#!/usr/bin/env bash\nset -euo pipefail\nname=%s\n' "$name"
        cat <<'WRAPPER'
touch "$TEST_BARRIER/$name"
ready=false
for ((i=0;i<100;i++)); do
    if [[ -f $TEST_BARRIER/history && -f $TEST_BARRIER/interests && -f $TEST_BARRIER/discovery ]]; then ready=true; break; fi
    sleep 0.05
done
$ready || exit 9
exec bash "${BASH_SOURCE[0]}.real" "$@"
WRAPPER
    } > "$scratch/project/recommendations/$file"
done
bash "$scratch/project/workflows/get_recommendations.sh" > "$scratch/parallel" 2> "$scratch/parallel.log"
[[ -s $scratch/parallel ]]; ok 'all three agents overlap (barrier test)'
printf '#!/usr/bin/env bash\nexit 7\n' > "$scratch/project/recommendations/recommend_from_history.sh"
reject bash "$scratch/project/workflows/get_recommendations.sh"
[[ ! -s $scratch/rejected.out ]]
grep -q '\[failed\] history' "$scratch/rejected.err"
ok 'failed agent prevents partial recommendations'
# A fresh process must read previously saved state.
[[ $(bash "$ROOT/data/book_database.sh" list | wc -l) == 5 ]]; ok 'saved library survives process restarts'
printf '\nAll %s integration tests passed.\n' "$passed"
