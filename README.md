# CITY / SHELF

A small personal Bash book manager for **urban planning**: cities, housing,
transport and public space. Recommendations always leave room for exploration.

## Demo video

[Watch the narrated demo](https://youtu.be/dZ_2-PsLe-s?si=f5Ye5wf0Ff5EoCyr)

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

## Details and tests

See [GUIDE.md](GUIDE.md) for file responsibilities, data formats, recommendation
scoring and storage limitations. Run `bash tests/test.sh` for the 22 isolated
integration tests. GitHub upload and video production are excluded as requested.
