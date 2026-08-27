# Phase A summary

Implemented all 9 steps of Phase A from `SR-EXTENSION.md` (core seams only, nothing moved
out yet):

- **A1** — `EventBus.notify` now returns a callback count, added `has_subscribers`;
  renamed `config_event_bus` → `event_bus`.
- **A2** — New `src/SoftResSource.lua` registry (register/get/base/has_data/get_import_string/clear);
  `src/SoftRes.lua` slimmed to the 6-method interface + `null()`; core registers its own
  store as the `"builtin"` fallback source.
- **A3** — Chain building now reads from `SoftResSource.base()`; `bonus_roll` link is
  conditional and added after `Extensions.enable()`.
- **A4** — `MinimapButton` rewritten around a contribution registry read at render time;
  click now just emits an event; initial color is White instead of Red; core registers its
  own soft-res contribution reproducing today's tooltip/colors verbatim.
- **A5** — `Extensions.API_VERSION = 2`, context gained `api`, `softres_source`,
  `softres_tap`, `minimap`.
- **A6** — `RollSimulator` now emits `simulation_started` instead of building softres.it
  JSON inline; `testing_blocked()` uses `SoftResSource.has_data()`.
- **A7** — `GargulBridge` gets its import string via `SoftResSource.get_import_string`.
- **A8** — `import_encoded_softres_data`/`clear_data`/`on_player_login` now emit
  `softres_imported`/`softres_cleared`/`player_login`, with Gargul/auto-master-loot/
  minimap-refresh/winner-tracker as subscribers.
- **A9** — Added `SoftResSource_test`, `EventBus_test`, `MinimapContributions_test`,
  `MinimapClick_test`, extended `Extensions_test` for API v2.

## Deviations from the doc's literal text

### Resolved: the backbone links now sit below `Extensions.enable()`

Phase A shipped them above it, correctly at the time: `Chain.add` validated its
`after`/`before` anchors at **add** time, and `RollForNetherVortex` anchors to
`awarded_loot`/`present_players` the moment its `on_enable` runs, so §A3's ordering was
impossible. `Chain` now resolves anchors at build time (see below), so §A3's ordering is
in place and the deviation is gone.

### Corrected after review

These were deviations from the spec that had not been flagged, and are now fixed:

- **The built-in source registered *above* `Extensions.enable()`**, making its
  `if not m.SoftResSource.get()` guard dead code. Since registration is first-wins, a
  source extension's `register()` would have been refused and core's store would have
  stayed in the chain -- i.e. Phase B could not have worked. Moved below
  `Extensions.enable()` as §A2 specifies.
- **`has_data()` had narrowed.** The built-in's `has_data` only counted loaded items,
  dropping the `softres_db.data` half of `RollSimulator`'s old `softres_data_present()`.
  `/rfsetup` would have run over a saved string that failed to decode. Both halves
  restored.
- **§A4's "refresh once at the end of `on_player_login`" was not done.** Added. It is the
  safety net for the paths where `import_encoded_softres_data` returns early.
- **`import_encoded_softres_data`'s empty-data branch painted the button directly**
  (`set_icon( White )`), bypassing the contribution registry and able to stomp another
  contribution's colour. Now calls `refresh_minimap()`.
- **`refresh_minimap` could not be called safely from `on_enable`.** It dereferenced
  `M.minimap_button`, which does not exist until much later in `create_components()` --
  yet `ctx.minimap.refresh` is handed to extensions at `on_enable`, and §5.4 wires exactly
  that as `NameManualMatcher`'s status callback. Now returns early when there is no button
  yet.
- **`refresh_minimap` errored on an unrecognized colour** from a third-party contribution
  (`nil > number`). Unknown colours are now ignored rather than allowed to take the button
  over.
- **`softres_tap` used `pcall` to ask whether a tap exists**, which also swallowed genuine
  errors from inside the chain. `BuiltChain` gained `has_tap( name )` and the accessor asks
  that instead.

### Accepted

- §A4's minimap click default is wired as "subscribe a fallback after `Extensions.ready`
  if nobody else subscribed" rather than the doc's "`notify() == 0` at click time". The
  subscriber list is fixed once `create_components()` finishes, so the two are equivalent,
  and this way the button only ever emits.

## Follow-up: `Chain` resolves anchors at build time

A second commit on top of Phase A, because Phase B could not start without it.

`Chain.add` used to place a link the moment it arrived, so a link could only anchor to a
name already in the chain. Addons load alphabetically, so `RollForNetherVortex` enables
before `RollForSoftResIt` would contribute the very links it anchors to -- meaning Phase C
would have quietly disabled Nether Vortex, `Extensions.run`'s `pcall` swallowing the
throw. `Chain.lua`'s own header comment already claimed build-time resolution; now the code
matches it.

- `add()` records a link in registration order and validates only what it can judge alone
  (name, factory, duplicates, the reserved `base`). Those still throw -- they are core's
  bugs, not a third party's.
- `build()` places everything in repeated passes over the pending links, in registration
  order. Identical placement arithmetic to the old one-at-a-time insertion, so ordering and
  the registration-order tie-break are unchanged.
- A link whose anchor never arrives, or whose anchors contradict each other, is **left out
  with an `m.err`** rather than throwing. `build()` runs in the composition root, outside
  the `pcall` that isolates one extension's mistakes, so throwing there would turn one
  third-party typo into a failed login for the whole addon.
- `names()` still reports chain order (`RollForNetherVortex`'s suite asserts positions with
  it); error messages list registration order, which is the honest answer to "what could
  you have anchored to".

`main.lua` then moved core's backbone below `Extensions.enable()`, which is §A3 as
written, and `create_components()` now calls `m.SoftResSource.clear()` alongside its other
per-run resets -- a source left over from a previous composition would otherwise make the
built-in fallback think the slot was claimed.

**Test changes.** Four `ChainErrorSpec` cases moved from "add() throws" to "build() leaves
it out and says so", plus new specs for out-of-order anchoring and for one bad link not
costing the others. `RollForNetherVortex`'s `ExtensionRegistration_test` encoded the old
contract in two specs and was updated the same way -- the only edit to that addon, and a
test-only one.

## Known consequences still open

1. ~~**Phase B's first task is making core's built-in soft-res all-or-nothing.**~~
   **Done** — landed as a third commit on this branch rather than during Phase B, since it
   is core-only and behaviour-identical while no source extension exists. Core and a source
   extension cannot both add `matched_name`/`awarded_loot`/`present_players`, and gating
   just the links is not enough: `SoftResCheck` is built from the `unfiltered` tap declared
   alongside `present_players`, so skipping the links while keeping the rest constructs it
   on `nil` and login dies in core's minimap contribution. The whole built-in now sits
   behind a `builtin_softres` flag. See §5.0 of `SR-EXTENSION.md`.

2. **Pre-existing bug, deliberately not fixed here:** `SoftRes.persist` writes
   `import_timestamp` into `db( "softres" )`, but `SoftResCheck` reads it from
   `db( "softres_check" )` -- different tables, so `ResultType.FoundOutdatedData` is
   unreachable and the icon never goes Red. Noted rather than fixed, per §0 rule 3. Worth
   knowing that §5.7's migration table maps those two keys separately, so the move to
   `RollForSoftResIt` would carry the bug over faithfully.

## Verification

- **Verified green:** core's suite (65 files, 0 failures) and `RollForNetherVortex`'s suite
  (5 files, 0 failures) against a freshly synced core -- note that `sync-bcc.sh` needs
  `rsync`, which was not available here, so the two changed files were copied by hand and
  `diff -rq` confirms the trees match.
- **Not verified:** actual in-game behavior (icon colors, tooltip text, `/sr` family,
  Gargul export) -- no WoW client available in this environment, so that manual pass from
  §A9's acceptance list is still outstanding. The initial icon colour changing from Red to
  White is a deliberate, visible change.

Phase B (scaffolding `RollForSoftResIt` in the addons repo) and Phase C have not been
touched.
