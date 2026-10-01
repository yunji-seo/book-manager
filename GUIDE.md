# CITY / SHELF

A small personal Bash book manager for **urban planning**: cities, housing,
transport and public space. Recommendations always leave room for exploration.

## Run

Requires Bash 3.2+, `awk`, standard Unix utilities and
[Gum](https://github.com/charmbracelet/gum#installation). No Python, API key,
network connection or AI subscription is required to run the application.

```bash
# macOS / Homebrew
brew install gum

# Then, inside book-manager:
bash app.sh
```

Windows: install Git for Windows (includes Git Bash) and Gum. In PowerShell:

```powershell
winget install --id Git.Git -e
winget install --id charmbracelet.gum -e
```

Open a **new Git Bash** window, navigate to this project, and run `bash app.sh`.
Gum must be on PATH (`gum --version`). For Linux, use the official Gum installation
instructions linked above. Arrow keys select, Enter confirms, Ctrl+C cancels the
current prompt. The main menu offers Browse Library, Add Book, Search Library,
Get Recommendations and Quit. Select a saved book to view its details or update
its status/rating. Select a recommendation to inspect its reason and save it.

To enable the assignment's direct `./...` examples on Unix:

```bash
find . -name '*.sh' -exec chmod +x {} \;
./app.sh
```

## Architecture

`app.sh` only checks Gum and starts `ui/main_menu.sh`. The three UI scripts handle
prompts, selections and presentation; they call workflows, which coordinate book
and recommendation components. `manage_library.sh` sends input through metadata
enrichment to the database, and routes searches through `search_books.sh`.
`get_recommendations.sh` starts three independent Bash programs with `&`, captures
their PIDs with `$!`, reports running/done states to stderr, and synchronizes with
`wait`. It combines their output with `cat ... | refine_recommendations.sh`; the UI
receives only the final TSV on stdout. Only `data/book_database.sh` opens
`books.csv`, using its private AWK helper for CSV handling. This preserves
**UI → Workflows → Components → Data → Storage**.

## Personalization

The default interests are urban planning, housing, transport and public space,
based on the user's chosen field. The curated offline catalog includes Jane
Jacobs, Kevin Lynch, Jan Gehl, Donald Shoup, and books about housing inequality.
The history strategy rewards genres/authors from saved, currently read and highly
rated books; the interests strategy matches explicit topics; discovery deliberately
looks outside both the library's genres and the stated interests. Refinement keeps
the strongest duplicate, excludes saved books, ranks candidates and reserves one
slot for discovery when available. No reading history is invented: the library
starts empty. Edit `config/interests.txt` (one term per line) for persistent changes,
or enter comma-separated interests in the recommendation screen for one session.

## Try the complete workflow

In the menu, add **The Image of the City / Kevin Lynch** as `reading`. Browse it,
change its status to `finished`, and rate it `5`. Search `Lynch`. Get recommendations
using saved interests, inspect the reasons, and save a new book to `want-to-read`.
Run recommendations again: the saved book will be excluded.

The same components also work without Gum:

```bash
bash workflows/manage_library.sh add 'The Image of the City' 'Kevin Lynch' reading
bash workflows/manage_library.sh update-rating 'The Image of the City' 'Kevin Lynch' 5
bash workflows/manage_library.sh list
echo 'urban' | bash books/search_books.sh
bash workflows/get_recommendations.sh 5
# stdout can be redirected; progress still appears on stderr:
bash workflows/get_recommendations.sh 5 > recommendations.tsv
```

## Small, explicit interfaces

All data output is UTF-8, headerless, tab-separated, one book per line. Diagnostics
and progress use stderr. Tabs, newlines and control characters in user fields are
rejected. Commas, quotes, backslashes and Korean text are supported. Book identity
is title + author, ignoring ASCII case and repeated/leading/trailing spaces.

| Interface | Fields or arguments |
|---|---|
| Database rows | title, author, genre, status, rating, link, year |
| Metadata output | title, author, genre, year, link |
| Recommendation rows | title, author, genre, year, link, score, strategy, reason |
| Catalog rows | title, author, genre, year, link, semicolon-separated topics |
| Database commands | init, list, search QUERY, exists TITLE AUTHOR |
| Database mutations | add TITLE AUTHOR GENRE STATUS RATING LINK YEAR; update-status TITLE AUTHOR VALUE; update-rating TITLE AUTHOR VALUE |

Statuses: `owned`, `want-to-read`, `reading`, `finished`. Rating: `0` means unrated;
`1`–`5` are ratings. Status is one reading/shelf state, not a separate ownership flag.
Unknown metadata uses `Unknown` and `-`; catalog lookup requires both title and
author, and never fabricates metadata. Years refer to original publication where
known, rather than every linked edition. Metadata/recommendations cover only the
33 catalog entries; arbitrary books can still be stored and searched.

History gives saved books weight 2, reading 3 and finished 4; an explicit rating
overrides that weight with `rating - 2`. Matching genre and author weights are
summed, producing `min(90, 60 + positive affinity)`. Interests get `50 + 5 × matched
terms`; discovery gets 35. Ties use title order, so results are reproducible.
These are transparent heuristics, not an online AI recommendation service.

## File guide

| File | Responsibility |
|---|---|
| `app.sh` | Small entry point |
| `ui/main_menu.sh` | Gum main menu |
| `ui/library_screen.sh` | Add, browse, search, detail and edit prompts |
| `ui/recommendations_screen.sh` | Interest selection, results, recommendation saving |
| `workflows/manage_library.sh` | Coordinate library operations |
| `workflows/get_recommendations.sh` | Parallel launch, progress, wait, pipe |
| `books/fetch_book_metadata.sh` | Offline title/author lookup |
| `books/search_books.sh` | Argument or stdin query → data-layer search |
| `books/catalog.tsv` | Small curated enrichment/recommendation resource |
| `recommendations/recommend_from_history.sh` | Genre/author/rating affinity |
| `recommendations/recommend_from_interests.sh` | Explicit topic matching |
| `recommendations/recommend_for_discovery.sh` | Unfamiliar fields |
| `recommendations/refine_recommendations.sh` | stdin → unique, new, ranked shortlist |
| `data/book_database.sh` | Storage boundary, validation, locking and atomic replacement |
| `data/csv_operations.awk` | Private CSV codec and record operations |
| `data/books.csv` | Persistent library, initially header only |
| `lib/common.sh` | Shared paths and field validation |
| `config/interests.txt` | Persistent personal interests |
| `tests/test.sh` | Isolated integration and concurrency checks |

The additional helper files keep CSV parsing, path setup and curated resources out
of the UI and workflows. They do not collapse or bypass any required layer.

## Verification

```bash
bash tests/test.sh
```

Tests use a temporary `BOOK_DB`, leaving the real library untouched. They cover
CRUD-style operations required here (add/read/update), CSV escaping, Korean text,
invalid input, duplicate handling, metadata, piped search, all recommendation
strategies, refinement, persistence, concurrent writes, a three-agent barrier
(proves overlap rather than merely checking for `&`), and failed-agent handling.

Database writes use a directory lock and same-directory atomic rename. A lock
times out after about five seconds. If a process is forcibly killed and leaves a
lock, remove that exact `.lock` directory only after confirming no app is writing.
Use `BOOK_DB=/path/to/another.csv` for a separate shelf. Recommendation runs use a
single library snapshot for consistent comparisons. Concurrent additions after
that snapshot may still appear; duplicate checking at save time prevents re-adding
them. This is a small local app, not a multi-user service.

GitHub upload and narrated demo video are intentionally outside this delivery,
as requested. The code, README and tests are included; no repository or video link
has been invented.
