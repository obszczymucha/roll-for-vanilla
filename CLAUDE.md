# CLAUDE.md

## Original WoW UI source code
The original Blizzard WoW UI source code is available for referecne at:

    $HOME/.projects/lua/wow-ui-source.git/classic_anniversary

This is the reference client UI source (version `2.5.6.68502`). The Blizzard
`Interface/` code (default frames, XML/Lua templates, `FrameXML`, etc.) lives
under that directory. Consult it when you need to know how the stock client UI
behaves or what APIs/templates an addon is extending.


## Other addons
Other addons (specifically ModUi) are available for reference at:

    $HOME/.projects/lua/wow-2.5.x-addons.git/master


## List of dumped function names and variables
Keys from _G variable are located in:
WowApiDump_20260822.txt


## Diagnostics: lua-language-server
Installed at `/usr/local/bin/lua-language-server` (3.19.1). Run it on a
workspace directory:

    lua-language-server --check <dir> --checklevel=Hint --logpath=<tmpdir>

- **`--checklevel=Hint`, not `Warning`.** `unused-local`, `redefined-local`
  and friends are Hint. A Warning-level run reporting "no problems found"
  says nothing about them, and they are where the real findings have been:
  two different locals called `softres` in one file, a mock argument the
  double ignores.
- **Progress goes to stderr with carriage returns.** Pipe through
  `tr '\r' '\n'` or the findings are buried in a progress bar.
- **Exit code is 1 for findings *and* for a bad path.** Read the output; a
  non-zero exit does not tell you which.

### Every workspace, not just core
This repo, plus the eight addons under
`$HOME/.projects/lua/wow-2.5.x-addons.git/master/RollFor*`. Each has its own
`.luarc.json` naming what it can see (`Lua.workspace.library` points at
`../RollFor`, and at `../RollForSoftRes` for the soft-res leaves), so checking
core proves nothing about the addons. The `test/mocks/` directories are
duplicated per addon, so a fix in one copy is four copies short.

The glob also matches `master/RollFor`, core's synced copy. Redundant rather
than wrong -- it is a byte copy of the `RollFor/` the first check covered --
so the loop below prints ten lines, not nine.

    for d in "$PWD" $HOME/.projects/lua/wow-2.5.x-addons.git/master/RollFor*; do
      lua-language-server --check "$d" --checklevel=Hint --logpath=$(mktemp -d) 2>&1 |
        tr '\r' '\n' | grep -viE '^[[:space:]]*$|^(Initializing|>|=)'
    done

### When to run it
Alongside `./test.sh`, never instead of it -- they catch disjoint things.
Specifically, after:

- any change to `---@` annotations, including adding one;
- **renaming anything.** A rename can quietly shadow: `softres_it` was unique
  until it became `softres`, which already meant something else in that file;
- **moving or inserting a function.** A doc block left above the wrong
  function silently transfers its `---@param`/`---@return` to it. That has
  happened three times here (`RollController`, `LootList`, and a test stub).

### What it does not catch
- **A test that never runs.** luaunit's `-m should` filter skips any case not
  named `should_*`, and nothing subtracts it from the count. Compare declared
  `function XSpec:` count per file against luaunit's reported "Ran N tests" --
  that is what found a dead auto-loot test that had rotted three ways.
- **Duplicate spec-table names across files.** Harmless at run time, since
  `test.sh` runs each file as its own process, but the checker only sees it
  within a workspace.
- **Anything visual.** Frame layout, dropdowns and options pages need a human
  in the client.

## Target client: BCC only
BCC (`RollFor/RollFor.toc`, Interface 20505) is the only target. The vanilla
build has been removed, so:

- Don't check whether an API exists in 1.12 and don't add vanilla fallbacks.
- Don't reintroduce a `m.vanilla` / `m.bcc` split. `src/compat.lua` exists for
  shared helpers, not for branching on the client.
- The reference client under `wow-ui-source.git/classic_anniversary` is the
  authority on what an API returns.
