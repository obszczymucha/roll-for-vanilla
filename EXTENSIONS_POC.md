# RollFor Extensions — Design & Proof of Concept

Status: **POC landed.** The extension API is implemented in RollFor core, Nether Vortex
has moved out into `RollForNetherVortex`, and both suites are green. The resistance
bonus rolls migration (section 6) has not started.
Audience: whoever implements the rest of this after the Nether Vortex slice lands.

## 1. Goal

Nether Vortex rolling rules and resistance bonus rolls are both niche: they matter to
people running Tempest Keep and Mount Hyjal / Black Temple respectively, and to nobody
else. Today they are welded into RollFor's core and everybody carries the code and the
UI whether they want it or not.

The goal is to make RollFor **extendible**: a host addon with published seams, and
separate extension addons that register into it and can be enabled/disabled from
RollFor's own options window.

Two extensions are in scope:

| Extension | Addon folder | Difficulty |
|---|---|---|
| Nether Vortex | `RollForNetherVortex` | shallow — two decorators |
| Resistance bonus rolls | `RollForResistanceBonusRolls` | deep — touches the rolling engine |

**Nether Vortex goes first, deliberately.** It is ~150 lines of pure decorator, so it
exercises the extension API without also stressing it. If the API is wrong, we find out
cheaply. Resistance bonus rolls is the one that will actually bend the design, and it
should not be the thing we learn on.

## 2. What is actually coupled

### 2.1 Nether Vortex — shallow

| Location | Coupling |
|---|---|
| `src/SoftResNetherVortexDecorator.lua` | splits item 30183 into qty-1 / qty-2 pseudo-items, filters rollers by SR count |
| `src/NetherVortexAwardedLootDecorator.lua` | per-quantity award tracking |
| `main.lua:274` | links the awarded-loot decorator into the chain |
| `main.lua:297,303,305` | links the softres decorator into the chain |
| `src/RollSimulator.lua:309-310` | reaches in by name: `main.nether_vortex_softres` |
| `test/IntegrationTestBuilder.lua:9-10,119-122` | hardcodes both decorators into its chain |
| `test/utils.lua:940,942` | module load list |
| `test/SoftResRollSpec_test.lua:1271+` | `NetherVortexSpec` test class |

That is the whole surface. (`AutoLootDb.lua`'s "Nether*" hits are unrelated loot-table
names; `LootList_test.lua` uses 30183 only as a convenient stackable item.)

### 2.2 Resistance bonus rolls — deep

`src/resistances/` (14 files, 2191 lines) is pleasantly self-contained. The *bonus roll*
concept is not — it is threaded through the rolling engine:

| Location | Coupling |
|---|---|
| `src/Types.lua:44,57` | `RollType.BonusRoll` in a closed enum |
| `src/Types.lua:185,202` | `bonus_rolls` field on `RollingPlayer`, param on `make_rolling_player` |
| `src/modules.lua` | `roll_type_color` / `abbrev` / `abbrev_chat` / `rank` / `tier` all branch on `BonusRoll`; `colors.gold` exists for it |
| `src/RollingLogicUtils.lua:23` | `{ field = "bonus_rolls", roll_type = RT.BonusRoll }` |
| `src/RollingLogicUtils.lua:328` | `spend_bonus_roll` |
| `src/RollTracker.lua:119,158,199,250` | four hardcoded `for _ = 1, player.bonus_rolls` placeholder loops |
| `src/SoftResRollingLogic.lua` | registry as ctor arg, token spend, refund on cancel |
| `src/TieRollingLogic.lua` | same |
| `src/RollResultAnnouncer.lua:180-199` | `" +N bonus"` aggregation |
| `src/RollingPopupContentTransformer.lua:45,80` | placeholder + sort ordering |
| `src/RollingLogic.lua:51-54` | roll-allowance sentence |
| `src/SoftResBonusRollDecorator.lua` | softres chain decorator |
| `src/Config.lua:41,63,65,215-225,530` | `resistance_bonus_rolls_enabled`, `resistance_check_throttle` + accessors |
| `src/OptionsFrame.lua:233,236` | two `add_*` calls |
| `src/GuiElements.lua:1140-1450` | `resistance_row`, `eligibility_row`, `bonus_roll_row` (~330 lines) |
| `main.lua` | construction, `describe_lockout_loss()`, lockout-reset subscriber, `on_group_changed` fan-out |

## 3. The extension API

### 3.1 Registration

RollFor exposes a global registry. An extension addon declares
`## Dependencies: RollFor` in its TOC, which makes the client both refuse to load it
without RollFor and guarantee RollFor loads first. The extension therefore registers at
file scope, long before `PLAYER_LOGIN`:

```lua
RollFor.Extensions.register( {
  name = "nether_vortex",           -- unique id, also the db key
  title = "Nether Vortex",          -- shown in the options window
  description = "Nether Vortex rolling rules.",
  api_version = 1,                  -- the extension API this was built against
  default_enabled = true,
  on_enable = function( ctx ) ... end,
  on_ready = function( ctx ) ... end,   -- optional, see 3.3
} )
```

`register` validates the spec and records it. An `api_version` the host does not support
prints a clear message and leaves the extension permanently disabled for the session —
it never half-loads. Registration happens whether or not the extension is enabled, so
disabled extensions still appear in the options list with a checkbox to turn them on.

### 3.2 The context object

`main.lua`'s composition root is a `local M` that is never assigned onto `RollFor`, so
today nothing outside `main.lua` can reach any built component. That stays true —
extensions do **not** get the composition root. They get a deliberately narrow context:

```lua
---@class ExtensionContext
---@field db fun( key: string ): table            -- scoped under RollForCharDb.extensions.<name>
---@field api fun(): table                        -- the WoW API table; call it, m.api style
---@field config Config
---@field chat Chat
---@field group_roster GroupRoster
---@field player_info PlayerInfo
---@field ace_timer AceTimer
---@field event_bus EventBus
---@field popup_builder fun( bottom_margin: number?, side_margin: number? ): PopupBuilder
---@field frame_builder FrameBuilder
---@field gui_elements table                      -- row widgets, keyed by line type
---@field softres_chain Chain
---@field awarded_loot_chain Chain
---@field softres_source { register: fun( spec: SoftResSourceSpec ): boolean }
---@field softres_tap fun( name: string ): any?    -- nil before the chain is built or if no such tap
---@field minimap { register: fun( c: MinimapContribution ), refresh: fun() }
---@field on_group_changed fun( callback: fun() )
---@field on_lockout_reset fun( callback: fun() )
---@field lockout_loss fun( describe: fun(): { count: number, noun: string }[] )
---@field get fun( name: string ): any            -- on_ready and chain factories; built components by name
```

This is the surface we are committing to. It is the one thing in this document that is
expensive to change later, so it should stay small and grow only on demand.

Context is now v2 (`RollFor.Extensions.API_VERSION`): the soft-res extraction in
`SR-EXTENSION.md` added `api`, `softres_source`, `softres_tap` and `minimap`. An extension
built against v1 (`api_version = 1`, e.g. `RollForNetherVortex`) keeps loading unchanged --
the compatibility check only rejects an extension declaring an `api_version` *greater*
than the host's.

### 3.3 Two phases

The chains are built early in `create_components()`, but frames and slash commands need
components that do not exist until the end of it. So extensions get two callbacks:

```
create_components()
  1. primitives            db, config, event_bus, ace_timer, chat, group_roster,
                           player_info, popup_builder
  2. Extensions.enable()   -> on_enable( ctx ): DECLARE ONLY
                              insert chain links, register config toggles,
                              register hooks. No building.
  3. build awarded_loot chain
  4. build softres chain
  5. ... the rest of create_components(), unchanged ...
  6. Extensions.ready()    -> on_ready( ctx ): build frames, slash commands,
                              read built components via ctx.get()
```

`on_enable` must be side-effect-free beyond declaration; anything that needs a built
component belongs in `on_ready`. Nether Vortex only uses `on_enable`. Resistance bonus
rolls will use both.

### 3.4 Ordered decorator chains

Both features are decorators, and order is load-bearing. A plain "append" hook would be
wrong. `src/Chain.lua` provides named links with anchored insertion and a topological
build:

```lua
chain.add( {
  name    = "nether_vortex",
  after   = "awarded_loot",
  before  = "present_players",
  factory = function( inner ) return NV.new( inner ) end
} )
```

Core registers its own links under stable names so extensions have something to anchor
to. A link anchored to a name that does not exist is a **build-time error with a clear
message** — silently mis-ordering the softres chain would produce wrong loot decisions
that nobody would trace back to here.

The softres chain, current order preserved:

| # | Link | Owner |
|---|---|---|
| base | `SoftRes.new( softres_db )` | core |
| 1 | `matched_name` | core |
| 2 | `awarded_loot` | core |
| 3 | *slot* | `nether_vortex` (extension) |
| — | **tap: `unfiltered`** | |
| 4 | `present_players` | core |
| 5 | *slot* | `bonus_roll` (extension) |
| — | **tap: `final`** | |

### 3.5 Taps, not intermediate names

`main.lua` currently hands `M.nether_vortex_softres` to `SoftResCheck` and
`RollSimulator`. Neither of them wants "the vortex decorator" — they want *the full
softres view before group filtering*. Naming that reference after an extension is
exactly the coupling we are removing, and it breaks outright when the extension is
disabled.

So the chain exposes **taps**: named points whose meaning is owned by core and which
exist regardless of which extensions are loaded.

```lua
local softres = ctx.softres_chain.build( base )
softres.tap( "unfiltered" )   -- SoftResCheck, RollSimulator
softres.tap( "final" )        -- everyone else
```

`RollSimulator.lua:309-310` stops naming `main.nether_vortex_softres` and reads
`tap( "unfiltered" )` instead.

### 3.6 Config and options

`Config.new` hardcodes its `toggles` table and its defaults in `init()`. It gains
runtime registration, callable from `on_enable`:

```lua
ctx.config.register_toggle( "nether_vortex_announce", {
  cmd = "nv-announce", display = "Nether Vortex announcements"
}, true )
```

`OptionsFrame` already renders from `config.toggles`, so a toggle registered in
`on_enable` shows up with no further work. It additionally grows an **Extensions**
section listing `Extensions.all()` — title, description, and an enable checkbox.

### 3.7 GUI seams

Mostly already in place, which is a pleasant surprise:

- `ListPopup` is fully generic — it becomes public API as-is.
- `FrameBuilder` already resolves row widgets by name via
  `options.gui_elements[ line_type ]`, so extensions adding row types is just letting
  them write keys into that table (`ctx.gui_elements`).
- Shared row styling (`resistance_row_hover_color`, header colors, overhang) is borrowed
  by all three resistance rows and must be promoted to a public helper before those rows
  move out.
- `popup_builder` must be handed over on the context, not recomputed — the
  `classic_look` margin arithmetic in `main.lua:186-192` is not something an extension
  should be duplicating.

### 3.8 Lifecycle hooks

Three fan-outs are hardcoded in `main.lua` and need contributor hooks:

- **`on_group_changed`** — currently calls three resistance frames by name
  (`main.lua:919-921`).
- **`on_lockout_reset`** — the `raid_lockout.subscribe` handler resets the bonus-roll
  registry and eligibility.
- **`lockout_loss`** — `describe_lockout_loss()` counts "bonus rolls" and "eligible
  players". `DropSimulator`'s confirmation dialog reuses the same sentence, so this must
  remain a single list that extensions contribute `{ count, noun }` entries to. Two
  divergent sentences here would mean agreeing to lose one thing and losing another.

## 4. Enable / disable semantics

**Toggling requires a UI reload.** Decided deliberately.

Every component downstream captures its collaborators at construction — `M.softres` is
handed to a dozen things in `create_components()`. Removing a chain link at runtime
would leave all of them holding the old object. Making the chains re-resolving façades
is possible but means auditing every capture site, for a setting that gets flipped
roughly never.

`Extensions.set_enabled( name, value )` writes to the db and notifies
`config_change_requires_ui_reload` on the event bus, which raises the existing
confirmation dialog — the same path `classic_look` already uses.

State lives in `RollForCharDb.extensions`, consistent with the rest of RollFor's
per-character config.

## 5. POC: RollForNetherVortex

### 5.1 Layout

Lives in the AddOns tree at `~/.projects/lua/wow-2.5.x-addons.git/master`, alongside the
deployed `RollFor`.

```
RollForNetherVortex/
  RollForNetherVortex.toc
  RollForNetherVortex.lua                    -- registers the extension
  src/NetherVortex.lua                       -- the item id, shared by both decorators
  src/SoftResNetherVortexDecorator.lua       -- moved from RollFor core
  src/NetherVortexAwardedLootDecorator.lua   -- moved from RollFor core
  test/
    luaunit.lua                              -- vendored
    mocking.lua                              -- vendored
    gui_helpers.lua                          -- vendored
    utils.lua                                -- vendored, adapted (see 5.5)
    IntegrationTestBuilder.lua               -- vendored, adapted
    mocks/, fixtures/                        -- vendored
    SoftResNetherVortexDecorator_test.lua    -- moved
    NetherVortexAwardedLootDecorator_test.lua-- moved
    NetherVortexSpec_test.lua                -- moved from SoftResRollSpec_test.lua
    ExtensionRegistration_test.lua           -- new
  test.sh
  README.md
```

The entry point is `RollForNetherVortex.lua`, not `main.lua`. The test harness puts
RollFor and this addon on the same Lua path, and `require( "main" )` cannot mean two
different files.

### 5.2 TOC

```
## Interface: 20506
## Title: RollFor - Nether Vortex
## Notes: Nether Vortex rolling rules for RollFor.
## Dependencies: RollFor
## X-RollFor-Extension: nether_vortex

src\NetherVortex.lua
src\SoftResNetherVortexDecorator.lua
src\NetherVortexAwardedLootDecorator.lua

RollForNetherVortex.lua
```

### 5.3 Namespace

The extension owns a `RollForNetherVortex` global and writes its modules there, not onto
`RollFor`. It still reads core helpers off `RollFor` (`m.clone`, `m.getn`,
`m.SoftRes.softres_item_data`) — those are part of the published surface.

### 5.4 Registration

```lua
RollFor.Extensions.register( {
  name = "nether_vortex",
  title = "Nether Vortex",
  api_version = 1,
  default_enabled = true,
  on_enable = function( ctx )
    ctx.awarded_loot_chain.add( {
      name = "nether_vortex",
      after = "base",
      factory = function( inner ) return NVAwardedLoot.new( inner ) end
    } )

    ctx.softres_chain.add( {
      name = "nether_vortex",
      after = "awarded_loot",
      before = "present_players",
      factory = function( inner ) return NVSoftRes.new( inner ) end
    } )
  end
} )
```

No `on_ready`, no config, no GUI. That is the entire extension.

### 5.5 Tests

Harness is **vendored**, per decision: `luaunit.lua`, `mocking.lua`, `mocks/` and
`utils.lua` are copied into `RollForNetherVortex/test/`. `package.path` resolves RollFor
from the sibling folder in the AddOns tree, which mirrors the real install exactly:

```lua
package.path = "./?.lua;" .. package.path ..
    ";../../RollFor/?.lua;../../RollFor/libs/?.lua;../?.lua"
```

RollFor comes **before** the addon's own root: both ship a `src/`, and core has to win
those lookups. Two adaptations to the vendored harness carry the addon itself, both
marked with `EXTENSION:` comments:

- `utils.load_extension()` loads this addon's modules after RollFor's `main.lua` and
  before `PLAYER_LOGIN` — the same order the client produces from `## Dependencies`.
- `IntegrationTestBuilder` feeds the chains through the addon's own `on_enable`, so the
  integration tests exercise the real registration rather than a copy of it. Its
  `without_nether_vortex()` builds RollFor as if the addon were switched off.

Two consequences, both accepted:

1. **The sibling `RollFor` is a sync artifact.** `sync-bcc.sh` must have run for the
   extension's tests to see core changes. That script's `TARGET_DIR` currently points at
   `wow-2.5.2-addons.git`, which no longer exists — it is `wow-2.5.x-addons.git`. Fixing
   that is part of this work.
2. **Releasing is two releases.** `release.sh` zips `RollFor` from this repo; the
   extension lives in the AddOns repo and ships from there. Nothing tries to zip across
   the two, and nothing should.
3. **The vendored `utils.lua` will drift** from the core copy. Its header records
   provenance and every intentional delta (the module load list drops the two NV modules
   and appends the extension's), so a future diff against core's is mechanical.

### 5.6 Core changes this POC requires

| Change | File |
|---|---|
| new — extension registry | `RollFor/src/Extensions.lua` |
| new — ordered decorator chain | `RollFor/src/Chain.lua` |
| chains + extension phases + hook registrars | `RollFor/main.lua` |
| `register_toggle`, dynamic defaults | `RollFor/src/Config.lua` |
| Extensions section | `RollFor/src/OptionsFrame.lua`, `OptionsFrameContentTransformer.lua` |
| `tap( "unfiltered" )` instead of `main.nether_vortex_softres` | `RollFor/src/RollSimulator.lua` |
| delete both NV files, drop from TOC | `RollFor/RollFor.toc` |
| drop NV from the module load list | `test/utils.lua:940,942` |
| build its chain from `Chain` instead of hardcoding NV | `test/IntegrationTestBuilder.lua` |
| move `NetherVortexSpec` out | `test/SoftResRollSpec_test.lua` |
| new core tests | `test/Chain_test.lua`, `test/Extensions_test.lua`, `test/ConfigExtensionSettings_test.lua`, plus `ExtensionsSectionSpec` in `test/OptionsFrameSpec_test.lua` |
| corrected `TARGET_DIR` (pointed at a path that no longer exists) | `sync-bcc.sh` |

### 5.7 Where it landed

RollFor core, 57 suites, 0 failures. `RollForNetherVortex`, 4 suites / 30 tests, 0
failures:

| Suite | Tests | Covers |
|---|---|---|
| `SoftResNetherVortexDecorator_test` | 13 | the quantity rules, through the real soft-res chain |
| `NetherVortexAwardedLootDecorator_test` | 7 | per-quantity award bookkeeping |
| `ExtensionRegistration_test` | 8 | that the addon registers, and that its links land between the right core anchors — including that a missing anchor fails loudly |
| `NetherVortexSpec_test` | 2 | end-to-end across looting sessions, and what a vortex looks like with the addon off |

The one that matters most for the API is `ExtensionRegistration_test`: it drives the
addon's real `on_enable` against a stand-in of core's backbone and asserts both the
resulting order and the failure when an anchor is renamed away.

## 6. Phasing the resistance bonus rolls migration

Do not attempt this until the Nether Vortex slice is merged and the API has sat for a
bit. Order that keeps `master` shippable at every step:

**Phase 1 — open the roll-type registry.**
`Types.register_roll_type{ id, abbrev, color, rank, tier, player_field }`. The five
if-chains in `modules.lua`, the field table in `RollingLogicUtils.lua:23`, and the four
`RollTracker` loops all read from the registry. `RollingPlayer.bonus_rolls` becomes a
generic slot.

*Alternative worth weighing first:* keep `RollType` closed and give it a single generic
"extra rolls" slot that one extension may claim. Far less churn, supports exactly one
such extension ever. Bonus rolls is the only client today.

**Phase 2 — roll-spend hooks.** Generalize `spend_bonus_roll` / `spent_tokens` / refund
into a roll-type contract: `on_roll_used(...) -> token?` and
`on_round_cancelled( tokens )`, so `SoftResRollingLogic` and `TieRollingLogic` stop
naming the registry.

**Phase 3 — announcement hooks.** The allowance sentence in `RollingLogic.lua:51-54`,
`" +N bonus"` in `SoftResRollingLogic.lua:212` and `RollResultAnnouncer.lua:196-199`,
and the sort in `RollingPopupContentTransformer.lua:80`.

**Phase 4 — GUI seams.** Promote the shared row styling, move the three row widgets out
behind `ctx.gui_elements`, move the config settings behind `register_toggle` /
`register_number`.

**Phase 5 — move the folder.** `src/resistances/` and `test/resistances/` become
`RollForResistanceBonusRolls`. `SoftResBonusRollDecorator.lua` goes with them.

## 7. Decisions taken

| Question | Decision |
|---|---|
| Scope of first pass | Full vertical slice — core API implemented, NV moved out |
| Extension test harness | Vendored into the extension |
| RollFor source for tests | Sibling `../RollFor` in the AddOns tree |
| Enable/disable | Requires UI reload |
| Extension state storage | `RollForCharDb.extensions` |
| Nether Vortex item id | Stays hardcoded (30183) — parity move, not a redesign |
| Extension entry filename | `RollForNetherVortex.lua`, so `require( "main" )` stays unambiguous |
| Extension namespace | Its own `RollForNetherVortex` global; core helpers read off `RollFor` |

## 8. Known risks

- **The context object is the real commitment.** Everything else is refactorable; a
  published surface that extensions bind to is not. Keep it small.
- **Chain ordering bugs are silent and expensive.** Hence build-time errors on unknown
  anchors rather than best-effort ordering.
- **Vendored harness drift.** Mitigated by provenance comments, not eliminated.
- **The sync step is now load-bearing for tests.** A stale `../RollFor` means the
  extension's tests pass against yesterday's core.
