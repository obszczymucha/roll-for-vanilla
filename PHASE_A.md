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

## Deliberate deviation from the doc's literal text

Flagged in a code comment in `main.lua`. §A3 says to move *all* of core's backbone links
after `Extensions.enable()`. I kept `matched_name`/`awarded_loot`/`present_players` added
*before* it (only `bonus_roll` moved after, conditionally) — moving all four would break
`RollForNetherVortex`, whose `on_enable` anchors to those names the moment it runs. I
verified this empirically both ways; only this ordering keeps NetherVortex green.

## Verification

- **Verified green:** core's suite (65 files, 0 failures) and `RollForNetherVortex`'s
  suite (synced copy, 0 failures) — both pass.
- **Not verified:** actual in-game behavior (icon colors, tooltip text, `/sr` family,
  Gargul export) — no WoW client available in this environment, so that manual pass from
  §A9's acceptance list is still outstanding.

Nothing was committed. Phase B (scaffolding `RollForSoftResIt` in the addons repo) and
Phase C have not been touched.
