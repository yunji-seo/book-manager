#!/usr/bin/env bash
# Shared paths and input validation; no application or storage logic.
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export LC_ALL=C
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
valid_text() {
    [[ -n ${1// /} ]] || fail 'A required value is empty.'
    [[ $1 != *[$'\001'-$'\037'$'\177']* ]] || fail 'Control characters, tabs and newlines are not supported.'
}
