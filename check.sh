#!/usr/bin/env bash

# The checks ./test.sh cannot make. Run both before committing.
#
#   1. lua-language-server over every workspace. Annotation drift, shadowed locals, a doc
#      block left above the wrong function -- none of which a passing suite notices.
#   2. Declared test cases against the ones luaunit actually ran. A case not named
#      `should_*` is filtered out silently and subtracts from nothing, so a suite can
#      report "6 tests" for years while a seventh rots.
#
# Read the output; a non-zero exit says something was found but not which check found it.

set -o pipefail

CORE="$(cd "$(dirname "$0")" && pwd)"

# Derived from this script's own location rather than $HOME, which is not the same thing in
# every shell that runs this. The two repos are siblings: <...>/lua/roll-for-vanilla and
# <...>/lua/wow-2.5.x-addons.git, the same layout sync-bcc.sh copies between.
ADDONS="${ROLLFOR_ADDONS:-$CORE/../../wow-2.5.x-addons.git/master}"

if [[ ! -d "$ADDONS" ]]; then
  echo "No addons tree at $ADDONS. Set ROLLFOR_ADDONS to point at it." >&2
  exit 2
fi

FAILED=0

# `master/RollFor` is skipped: it is a byte copy of this repo's RollFor/, synced there for
# the extension suites to run against, so checking it is checking the same files twice.
workspaces() {
  echo "$CORE"

  local d
  for d in "$ADDONS"/RollFor*; do
    [[ -d "$d" && "$(basename "$d")" != "RollFor" ]] && echo "$d"
  done
}

# Hint, not Warning: unused-local and redefined-local live there, and they are where the
# findings have been.
check_annotations() {
  echo "Checking annotations..." >&2

  local dir out tail_line
  while read -r dir; do
    out=$(lua-language-server --check "$dir" --checklevel=Hint --logpath="$(mktemp -d)" \
      </dev/null 2>&1 |
      tr '\r' '\n' | grep -viE '^[[:space:]]*$|^(Initializing|>|=)')
    tail_line=$(echo "$out" | tail -1)

    printf "%-24s %s\n" "$(basename "$dir")" "$tail_line"

    if ! echo "$tail_line" | grep -q "no problems found"; then
      echo "$out" | grep -v "^Diagnosis" | sed 's/^/    /'
      FAILED=1
    fi
  done < <(workspaces)
}

# Every case a file declares, minus luaunit's fixtures, against what luaunit ran. The Spec
# pattern allows digits -- Base64Spec is a real one.
check_unrun_cases() {
  echo >&2
  echo "Checking for cases that never run..." >&2

  local dir f declared ran
  while read -r dir; do
    [[ -d "$dir/test" ]] || continue

    for f in "$dir"/test/*_test.lua; do
      [[ -e "$f" ]] || continue

      declared=$(grep -E '^function [A-Za-z_0-9]*Spec[:.]' "$f" |
        grep -vE '[:.](setUp|tearDown)\(' | wc -l)

      ran=$(cd "$(dirname "$f")" && lua "$(basename "$f")" -T Spec -m should -o text \
        </dev/null 2>&1 |
        grep -oE 'Ran [0-9]+ tests' | grep -oE '[0-9]+')
      ran=${ran:-0}

      if [[ "$declared" -gt "$ran" ]]; then
        printf "  %s/%-40s declared %s, ran %s\n" \
          "$(basename "$dir")" "$(basename "$f")" "$declared" "$ran"
        grep -E '^function [A-Za-z_0-9]*Spec[:.]' "$f" |
          grep -vE '[:.](setUp|tearDown)\(|[:.]should_' | sed 's/^/      never runs: /'
        FAILED=1
      fi
    done
  done < <(workspaces)
}

check_annotations
check_unrun_cases

echo >&2
[[ $FAILED -eq 0 ]] && echo "Clean." >&2 || echo "Problems found. See above." >&2
exit $FAILED
