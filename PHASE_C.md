# Phase C summary

Core's built-in soft-res is gone. `SR-EXTENSION.md` §6 as written, plus the deviations
below. Phase B's second half (§9.2's suite migration) landed just before this; it is
recorded in that commit rather than here.

## What shipped

- **§6.1** — deleted `SoftResDataTransformer`, the four soft-res decorators,
  `NameAutoMatcher`, `NameManualMatcher`, `NameMatchReport`, `SoftResCheck`, `SoftResGui`,
  `SoftResCheckResultPrinter`, and the store + decode halves of `SoftRes.lua`. What that
  file keeps is the types, `softres_item_data` and `null()`. Dropped from `RollFor.toc`
  and from `test/utils.lua`'s load list.
- **§6.2** — out of `main.lua`: the six `builtin_softres` blocks and the flag itself,
  `clear_data`, `GroupAwareSoftResFn` and its two aliases, `import_softres_data`,
  `import_encoded_softres_data`, `on_softres_command` and the `/sr` registration. What is
  left is §6.2's own list: the chain built on `SoftResSource.base()`, the conditional
  `bonus_roll` link, the event emissions, and the consumers, which did not change.
- **§6.3** — the no-source notice, printed once at the end of `on_player_login`.
- **§6.4** — `RollFor.toc` notes, `README.md`, `EXTENSIONS_POC.md`'s decisions table.
  `RollForSoftResIt/README.md` was already written in Phase B.
- **§6.5** — `sync-bcc.sh` left alone, as instructed.
- **§9.3** — `test/mocks/SoftResSource.lua`, and `IntegrationTestBuilder` building on it
  with no backbone links.

## Deviations

### The double enriches rollers with a class

§9.3 says six read methods over a literal table and nothing else. It also has to set
`class` on each roller, because every real source does -- its present-players decorator
looks one up while it filters -- and the rows core renders read that field.
`BonusRowContract_test` fails on nothing but a missing `player_class` without it.

The double takes a `find_class` function and calls it. It never drops a player for not
being in the group, which is the half that would make it a liar. Trap 5 is about
filtering, and this is not filtering.

### `PreviewSpec_test` was split, not moved

§9.2 expected it to stay whole. Two of its nineteen specs award an item and then assert
the winner list no longer offers the player who won -- awarded-loot filtering, which §9.1
says moves. They are now `RollForSoftResIt/test/PreviewAwardedLootSpec_test.lua`. The
other seventeen need data and not filtering and stayed in core.

Splitting a file is a bigger deviation than moving one, and it is still the smaller
mistake: moving all nineteen would have taken core's rolling-popup contract out of core.

### `MinimapClick_test`'s real-addon specs were rewritten, not moved

They asserted Phase A's behaviour -- core claiming the click for its own soft-res window.
There is no such window now, so they assert what the button actually does without a
source: the fallback opens the options window. Same two specs, opposite expectation.

### RollForNetherVortex's test harness had to change

§1.2 forbids touching that addon and §6.7 already carved out one test-only exception. This
is the second, and it is forced: its vendored harness *was* core's old one, so it loaded
ten files core had just deleted. It now carries core's dumb double, a copy of the
awarded-loot decorator (its integration spec genuinely asserts that filtering), and a
stand-in source registered as a real extension -- `create_components()` clears the source
registry on every login, so the extension seam is the only way in.

No production file in that addon was touched by this work. The TOC change below was the
author's call, separately.

### Two things the spec did not ask for

**`Chain.build( base, { report = false } )`.** RollFor plus an extension that anchors into
the soft-res chain, with no source installed, printed one error per unplaceable link at
every login -- a working configuration being told it is broken, in a message about a chain
link the user has never heard of. `main.lua` now asks for silence when
`SoftResSource.get()` is nil. The link is still left out; with a source present an
unplaceable link is a real anchor typo and still reports.

**RollForNetherVortex now declares `## Dependencies: RollFor, RollForSoftResIt`.** The
author's decision, and it supersedes §6.7's second case: there is no longer a "Nether
Vortex with no soft-res source" login to verify, because the client refuses to load it.
It also makes the load order explicit -- dependencies load first, so the source now
registers before Nether Vortex anchors to its links, rather than relying on build-time
anchor resolution to survive alphabetical load order. That resolution stays; nothing else
should depend on it by accident.

The dependency names softres.it specifically. If a second source addon ships, that is the
line that has to change, and §12's "two sources at once" question arrives with it.

## Still open

The `import_timestamp` bug from `PHASE_A.md` is now RollForSoftResIt's, carried over
unchanged as §0 rule 3 requires: `persist` writes it into the store's db, `SoftResCheck`
reads it from `softres_check`, so `ResultType.FoundOutdatedData` is unreachable and the
icon never goes Red.

## Verification

- Core 55 files / 785 tests, RollForSoftResIt 136 tests, RollForNetherVortex 38 tests --
  all green, the extensions against a freshly synced core.
- In game, by the author: the no-source login, the `/sr` family, the upgrade path on a
  character with an existing list, and Nether Vortex with the source installed.
