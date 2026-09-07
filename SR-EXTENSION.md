# Soft-res as an extension — implementation plan

Status: **done.** All three phases have landed. This document is the specification it was
built to; `PHASE_A.md` and `PHASE_C.md` record where the result differs from it and why.
Read those two alongside this one -- this file was not rewritten to match what shipped.

Companion document: `EXTENSIONS_POC.md` describes the extension system this builds on.
Read section 3 of it (the extension API) first. This document assumes it.

---

## 0. Rules for the implementer

Read these before anything else. They are here because the obvious shortcut is wrong in
each case.

1. **Do the phases in order and stop at each phase boundary.** Phase A alone must ship:
   every test green, the addon behaving exactly as it does today. Do not begin Phase B
   until Phase A is committed and green. Do not begin Phase C until Phase B is committed
   and green *in both repositories*.
2. **Do not rename anything that is not named in this document.** `RollType.SoftRes`,
   `RollingStrategy.SoftResRoll`, `M.softres`, `colors.softres`, the `/sr` family of
   commands, `SoftResRollingLogic` — all keep their names. This is an extraction, not a
   vocabulary change.
3. **Do not "improve" code while moving it.** A moved file should differ from its original
   only in the ways this document lists. If you spot a bug in moved code, write it down
   and move it unchanged; fixing it in the same commit makes the diff unreviewable.
4. **Do not make the core test double smarter.** See §9.3. It is deliberately dumb, and
   when a test fails against it the answer is to move the test, never to teach the double
   another behaviour.
5. **When something is ambiguous, prefer the option that keeps core ignorant of soft-res.**
   That is the point of the exercise.
6. **Run the full suite after every numbered step**, not at the end of a phase.
   `./test.sh` from the repository root.

---

## 1. What we are doing and why

RollFor's soft-res support is welded to softres.it: the import string format, the
zlib/base64/JSON decoding, the JSON shape, and the import window are all specific to that
one website. A second website, raidres.top, is coming, with a different format and
different capabilities.

So soft-res import — and everything downstream of it that is site-shaped — becomes an
extension addon: **RollForSoftResIt**. RollFor core keeps the *consumers* of soft-res data
(the rolling engine, the loot frame, the announcements) and grows a seam that a soft-res
*source* plugs into. Later, RollForRaidres plugs into the same seam, and only then do we
find out whether a shared "SR core" extension is worth extracting.

### 1.1 Decisions already taken

These were decided by the addon author. Do not relitigate them in code.

| Question | Decision |
|---|---|
| How much moves out | Everything movable: the store, the four soft-res decorators, name matching, `SoftResCheck`, the import GUI, the transformer, the decoder, and the soft-res half of `RollSimulator` |
| Where the addon lives | `RollForSoftResIt/` in `~/.projects/lua/wow-2.5.x-addons.git/master`, alongside `RollFor` and `RollForNetherVortex`. Its own release, exactly like Nether Vortex |
| Addon / id / title | Folder `RollForSoftResIt`, extension id `softres_it`, title `SoftRes (softres.it)` |
| Multiple sources at once | Out of scope. Exactly one source may be registered. A second registration is refused with an error |
| Whether the data model grows for raidres | Out of scope. The normalized model (`Roller`, `ItemData`) does not change in this work |
| Who owns the chain registry | **Core.** `ctx.softres_chain` stays a core-owned registry so `RollForNetherVortex` keeps working unchanged. The source extension *contributes* the backbone links into it |
| Soft-res specs | Move to `RollForSoftResIt` with a vendored harness, same as Nether Vortex |
| Enable/disable of the extension | Same as every extension: requires a UI reload |

### 1.2 What is explicitly NOT in scope

- Any change to `RollForNetherVortex`. If you find yourself editing it, you have taken a
  wrong turn — go back to §5.3.
- The resistance bonus rolls migration (section 6 of `EXTENSIONS_POC.md`).
- Raidres. Nothing in this work is allowed to be justified by "raidres will need it".
- Renaming core's soft-res vocabulary.
- Merging data from two sources.

---

## 2. The shape of the seam

Today:

```
main.lua builds SoftRes.new( db )  ->  chain of 4 decorators  ->  M.softres  ->  ~10 consumers
         ^ site-specific decode + transform live inside it
```

After:

```
RollForSoftResIt                         RollFor core
-----------------                        ------------
decode + transform                       SoftResSource registry  (new)
SoftResStore  --------- base ----------> chain (core registry)
4 decorators  --------- links --------->   |
taps          --------- taps ---------->   v
import GUI                               M.softres  ->  ~10 unchanged consumers
name matching                            NullSoftRes when nothing registered
SoftResCheck                             minimap contribution registry (new)
simulation                               event bus (existing, extended)
```

Core never knows what a base64 string is. Core never knows what website the data came
from. Core knows there is *a* soft-res source, or there is not, and either way it works.

### 2.1 The core-facing SoftRes interface

This is the entire contract. **Six read methods.** Core consumers use nothing else.

```lua
---@class SoftRes
---@field get fun( item_data: ItemData ): Roller[]
---@field get_all_rollers fun(): Roller[]
---@field is_player_softressing fun( player_name: string, item_data: ItemData? ): boolean
---@field get_items fun(): ItemData[]
---@field get_hr_item_ids fun(): ItemId[]
---@field is_item_hardressed fun( item_id: ItemId ): boolean
```

`import`, `clear` and `persist` are **removed from the core-facing interface**. They are
internal to the source. Today's `---@field import fun( data: RaidResData )` on `SoftRes`
is a leak of the softres.it JSON shape into a core type annotation and it goes away.

The store must be a **flat table of plain functions** — no `self`, no metatables. Every
decorator in the chain does `m.clone( softres )` and overrides fields, so anything the
store hides behind a metatable is lost the moment it is decorated.

---

## 3. File inventory

### 3.1 Stays in core, unchanged

`SoftResBonusRollDecorator.lua`, `SoftResLootListDecorator.lua`,
`SoftResRollingLogic.lua`, `NonSoftResRollingLogic.lua`, `TieRollingLogic.lua`,
`RollingStrategyFactory.lua`, `RollController.lua`, `LootController.lua`,
`DroppedLootAnnounce.lua`, `Chain.lua`, `Extensions.lua`, `Types.lua`, `GuiElements.lua`.

They consume soft-res data; they are not soft-res *sources*. `SoftResBonusRollDecorator`
belongs to the future resistance-bonus-rolls extension, not to this one — leave it alone.

### 3.2 Stays in core, rewritten

| File | What it becomes |
|---|---|
| `src/SoftRes.lua` | Types + `softres_item_data` + `M.null()`. **No store, no decode.** ~70 lines |
| `src/EventBus.lua` | `notify` returns a count; gains `has_subscribers` |
| `src/MinimapButton.lua` | Loses all soft-res knowledge; gains the contribution registry |
| `src/RollSimulator.lua` | Loses the soft-res half |
| `src/GargulBridge.lua` | Reads the import string off `SoftResSource` |
| `main.lua` | The composition changes described in §4.7 |

### 3.3 New in core

| File | Purpose |
|---|---|
| `src/SoftResSource.lua` | The registry a source extension registers with |

### 3.4 Moves to RollForSoftResIt

| Core file | Becomes | Notes |
|---|---|---|
| `src/SoftRes.lua` (the `M.new` body) | `src/SoftResStore.lua` | The store only |
| `src/SoftRes.lua` (`M.decode`) | `src/Decoder.lua` | base64 → zlib → JSON |
| `src/SoftResDataTransformer.lua` | `src/SoftResDataTransformer.lua` | verbatim |
| `src/SoftResAwardedLootDecorator.lua` | same name | verbatim |
| `src/SoftResPresentPlayersDecorator.lua` | same name | minus the `GroupAwareSoftRes` annotation, which stays in core |
| `src/SoftResAbsentPlayersDecorator.lua` | same name | verbatim |
| `src/SoftResMatchedNameDecorator.lua` | same name | verbatim |
| `src/NameAutoMatcher.lua` | same name | verbatim |
| `src/NameManualMatcher.lua` | same name | verbatim |
| `src/NameMatchReport.lua` | same name | fix its copy-pasted `if m.SoftResCheck then return end` guard to `if m.NameMatchReport then return end` while you are there — it is a real bug, it makes the file a no-op when `SoftResCheck` loaded first |
| `src/SoftResCheck.lua` | same name | verbatim |
| `src/SoftResGui.lua` | same name | verbatim |
| soft-res half of `src/RollSimulator.lua` | `src/Simulation.lua` | §6.6 |

### 3.5 Deleted outright

`src/SoftResCheckResultPrinter.lua` — it is an empty module that returns an empty table and
nothing references it. It is not in the TOC either. Delete the file.

### 3.6 Dead files you will trip over

Three files in `src/` are in neither `RollFor.toc` nor any test, and nothing references
them: `SoftResRollGuiData.lua`, `TieRollGuiData.lua`, and `LootAutoProcess.lua` (that last
one is loaded by `test/utils.lua` but is absent from the TOC, so it does not exist in
game). `SoftResRollGuiData.lua` calls `m.SoftRes.softres_item_data`, so it *will* show up
when you grep for soft-res consumers.

**Ignore all three.** Do not move them, do not update them, do not delete them — deleting
them is a separate cleanup and mixing it in makes this diff harder to review. They are
listed here only so that finding them does not send you down a wrong path.

---

## 4. Phase A — core seams, nothing moves

**Goal: at the end of Phase A the addon behaves identically, every existing test passes,
and core's own soft-res implementation reaches the rest of core only through the new
seams.** This is the phase that makes the rest safe. Do not skip it, do not merge it into
Phase B.

### A1. EventBus

`src/EventBus.lua`:

```lua
---@class EventBus
---@field subscribe fun( event_name: string, callback: fun( data: any? ) )
---@field notify fun( event_name: string, data: any? ): number -- how many callbacks ran
---@field has_subscribers fun( event_name: string ): boolean
```

`notify` returns the number of callbacks it invoked. `has_subscribers` returns whether
there is at least one. Existing callers ignore the return value; nothing else changes.

Rename `M.config_event_bus` to `M.event_bus` throughout `main.lua`, and
`ctx.event_bus` keeps pointing at it (it already does). It is no longer only about config.
There are exactly five hits, all in `main.lua` — no test names it.

#### The event catalogue

Every event core emits or listens for. Payloads are exact. Do not invent others.

| Event | Payload | Emitted by | Core subscribers |
|---|---|---|---|
| `config_change_requires_ui_reload` | `{ extension = string? }` | `Extensions.set_enabled`, `Config` | `main.lua` → confirmation dialog (exists today) |
| `minimap_icon_left_click` | none | `MinimapButton` | none. See §4.4 for the default |
| `player_login` | none | `main.on_player_login` | none |
| `softres_imported` | `{ source = string, raw = string?, interactive = boolean }` | the source | `GargulBridge`, `AutoMasterLoot`, minimap refresh |
| `softres_cleared` | `{ source = string }` | the source | `WinnerTracker`, minimap refresh |
| `simulation_started` | `{ players = Player[], reservations = { name = string, rolls = number }[], item = DroppedItem }` | `RollSimulator` | none in core after Phase C |

**Naming note for the author:** you asked for the event to be called
`MinimapIconLeftClick`. Every existing event on this bus and on `RollController` is
snake_case (`config_change_requires_ui_reload`, `rolling_started`), so this document uses
`minimap_icon_left_click` for consistency. If you want the PascalCase name, it is three
places: the emit in `MinimapButton`, the default check in `main.lua`, and the subscribe in
the extension.

**The `interactive` flag matters.** Today, `main.import_encoded_softres_data( data,
callback )` broadcasts to Gargul and calls `auto_master_loot.on_softres_import()` **only
when a callback was passed** — that is, only when a human clicked Import, not when the
saved string is re-imported at login. Preserve that exactly: `interactive = true` for a
GUI import, `false` for the login reload. Core's Gargul and auto-master-loot subscribers
must check the flag. The minimap refresh runs either way.

### A2. SoftResSource registry and the null object

New file `src/SoftResSource.lua`, loaded in the TOC immediately after `src/SoftRes.lua`:

```lua
---@class SoftResSourceSpec
---@field id string                              -- "softres_it"
---@field title string                           -- "SoftRes (softres.it)"
---@field base fun(): SoftRes                    -- the undecorated store; the chain's base
---@field has_data fun(): boolean                -- is anything actually loaded right now
---@field get_import_string fun(): string?       -- optional; what Gargul is answered with
```

API:

- `M.register( spec )` — validates and stores. Returns `true`/`false`. If a source is
  already registered, prints `m.err` naming both and returns `false`; **the first
  registration wins**. Validate that `id`, `title` are non-empty strings and that `base`
  and `has_data` are functions; refuse and return `false` otherwise.
- `M.get()` — the spec, or `nil`.
- `M.base()` — `source.base()`, or `m.SoftRes.null()` when there is none.
- `M.has_data()` — `false` when there is none.
- `M.get_import_string()` — `nil` when there is none or the source does not supply one.
- `M.clear()` — tests only, mirroring `Extensions.clear()`.

Rewrite `src/SoftRes.lua` down to types plus:

```lua
function M.softres_item_data( item_id, item_quantity )   -- unchanged, still used by 7 core files
function M.null()                                        -- a flat table implementing the 6 read methods
```

`M.null()` returns a **new table each call** (decorators mutate clones; a shared singleton
would be corrupted by a decorator that clones and overrides). Its methods return `{}`,
`{}`, `false`, `{}`, `{}`, `false` respectively.

Keep the `---@class SoftRes`, `---@class GroupAwareSoftRes` and `---@class ItemData`
annotations here, in core. `GroupAwareSoftRes` currently lives in
`SoftResPresentPlayersDecorator.lua`, which is leaving — move the annotation into
`src/SoftRes.lua` now, in Phase A.

**Still in Phase A, core registers its own built-in soft-res as a source.** In
`main.lua`, after `m.Extensions.enable(...)`:

```lua
-- The built-in soft-res, registered through the same seam an extension uses. It goes in
-- last and only if nothing else claimed the slot, so installing a source extension
-- replaces it rather than colliding with it. Deleted in Phase C.
if not m.SoftResSource.get() then
  m.SoftResSource.register( {
    id = "builtin",
    title = "softres.it (built in)",
    base = function() return M.unfiltered_softres end,
    has_data = function() return getn( M.unfiltered_softres.get_items() ) > 0 end,
    get_import_string = function() return M.softres_db.data end
  } )
end
```

This is what makes Phase B shippable: with the built-in as a fallback, a user who installs
`RollForSoftResIt` gets the extension, and a user who does not still has working soft-res.

### A3. Chain ordering changes in `main.lua`

Today `main.lua` adds four backbone links and one tap, *then* calls
`m.Extensions.enable()`. That order inverts: a source extension has to contribute its
backbone before core can hang anything off it.

**Prerequisite, done.** `Chain` used to resolve a link's anchors inside `add()`, which made
this inversion impossible — `RollForNetherVortex` anchors to `awarded_loot` and
`present_players` the moment its `on_enable` runs, and they would not be in the chain yet.
`Chain` now resolves anchors at build time, so a link may anchor to a name that has not
been added yet, and a link whose anchor never arrives is dropped with an `m.err` rather
than throwing. It does not throw because `build()` runs in the composition root, outside
the `pcall` that isolates one extension's mistakes from everything else.

New order inside `create_components()`:

1. `m.Extensions.enable( make_extension_context )` — extensions register their source,
   contribute chain links and declare taps.
2. **Then** core adds its own backbone links, but only in Phase A/B where core still owns
   them (in Phase C these move out and core adds none of them). See §5.0 — in Phase B
   these have to become conditional, or they collide with the extension's.
3. Core adds the `bonus_roll` link, **conditionally**:

```lua
-- Anchored to a link a source extension contributes, so it is only addable when a source
-- is actually installed. With no source there are no soft-ressers to annotate, so
-- skipping it changes nothing.
if M.softres_chain.has( "present_players" ) then
  M.softres_chain.add( {
    name = "bonus_roll",
    after = "present_players",
    factory = function( inner )
      return m.SoftResBonusRollDecorator.new( inner, M.resistance_bonus_roll_registry, M.config )
    end
  } )
end
```

4. Build:

```lua
M.awarded_loot = M.awarded_loot_chain.build( M.raw_awarded_loot ).final
M.softres_built = M.softres_chain.build( m.SoftResSource.base() )
M.softres = M.softres_built.final
```

5. `M.unfiltered_view` becomes `M.softres_built.tap( "unfiltered" )` **only when the tap
   exists**. The `unfiltered` tap is declared by whoever declares `present_players`, so
   with no source there is no tap. `Chain.build`'s `tap()` errors on an unknown name, so
   guard it — see §4.6 for the accessor extensions use.

**Ordering hazard, read twice:** the `awarded_loot` soft-res link's factory needs the
*decorated* awarded loot, which core builds in step 4 — after `Extensions.enable` ran but
at the moment the soft-res chain is built. This works because `Chain` runs factories at
build time, and core builds the awarded-loot chain **before** the soft-res chain. The
extension's factory therefore calls `ctx.get( "awarded_loot" )` *inside the factory body*,
not in `on_enable`. Getting this wrong yields a `nil` awarded loot and silently disables
"players who already won this item can't roll again". Test for it (§9.4).

### A4. MinimapButton

`MinimapButton.new` loses two parameters and gains two:

```lua
-- before
m.MinimapButton.new( M.api, db( "minimap_button" ), M.softres_gui.toggle, M.softres_check, M.config )
-- after
m.MinimapButton.new( M.api, db( "minimap_button" ), M.config, M.event_bus, M.minimap_contributions )
```

`M.minimap_contributions` is a plain array owned by `main.lua`, rebuilt at the top of
`create_components()` exactly like `extension_hooks` is today, so a reload does not
accumulate the previous run's entries.

A contribution:

```lua
---@class MinimapContribution
---@field commands { cmd: string, args: string?, description: string }[]?
---@field hint string?                                        -- what a click does
---@field status fun(): { color: string, lines: string[]? }?  -- consulted at render time
```

Rules, all of them load-bearing:

- **Contributions are read at render time, not at construction.** The button is built in
  `create_components()` and extensions register during `on_ready`, which is later. A
  button that snapshots the list at construction shows nothing. This is the single most
  likely mistake in this section.
- **Icon colour** = the highest-severity `status().color` across all contributions, where
  severity is `White(0) < Green(1) < Orange(2) < Red(3)`. No contributions, or all
  returning `nil` → `White`.
- **Tooltip layout**, top to bottom: the title; blank; core's own command lines (the
  `/htr`, `/rf`, `/rr`, `/irr`, `/arf`, `/rfreset`, `/cr`, `/fr`, `/rf config` lines that
  are there today); each contribution's `commands` in registration order; blank; the first
  contribution's `hint`, or `"Click to open options."` when no contribution supplies one;
  then for each contribution whose `status()` returns `lines`, a blank line followed by
  those lines.
- **Remove from core's hardcoded list**: `/sr`, `/sro`, `/src`, `/srs`, and the
  `"Click to manage softres."` line. Those become the extension's contribution. Also
  remove `print_players_who_did_not_softres` and the `softres_check` import entirely.
- **`ColorType` becomes a module-level field** (`m.MinimapButton.ColorType`) as well as an
  instance field, so an extension can name a colour without holding the instance.
- **Left click** emits `minimap_icon_left_click` and does nothing else. The default lives
  in `main.lua`:

```lua
-- Nobody claimed the click, so it does what a bare /rf does. Not "nobody handled it" --
-- literally "nobody subscribed": with a source extension installed, the extension's
-- subscription is the behaviour, and core must not also open the options window on top
-- of it.
M.event_bus.subscribe = M.event_bus.subscribe -- (no change; shown for context)

local function on_minimap_left_click()
  if M.event_bus.notify( "minimap_icon_left_click" ) == 0 then
    M.interface_options.open()
  end
end
```

  Wire `on_minimap_left_click` in as the button's click handler; the button itself only
  emits. Keep the existing `self:OnEnter()` + `GameTooltip:Hide()` behaviour after the
  emit.
- **Initial icon colour changes from `Red` to `White`.** Today the button constructs as
  `Red` ("outdated data") and is corrected a moment later at login. With no source
  installed, `Red` would be a lie that never gets corrected. Construct `White`, then
  refresh. This is a deliberate, visible behaviour change — mention it in the commit.
- `main.lua`'s `update_minimap_icon()` becomes `refresh_minimap()`, which recomputes from
  the contribution list and calls `set_icon`. It is called: on `softres_imported`, on
  `softres_cleared`, from `M.on_group_changed` (after the extension hooks fan out, as
  today), and once at the end of `on_player_login`.

In Phase A, `main.lua` registers core's *own* built-in contribution reproducing today's
tooltip and colours exactly (the `/sr` family, `"Click to manage softres."`, the
`check_softres` → colour mapping, the "Missing softres:" player list). In Phase C that
registration is deleted and the extension's takes over. **Copy the strings verbatim** —
tests assert on them.

### A5. ExtensionContext v2

`m.Extensions.API_VERSION` goes to `2`. The existing check (`spec.api_version >
M.API_VERSION` → incompatible) already accepts `api_version = 1`, so
`RollForNetherVortex` keeps loading untouched. **Verify that by running its suite**, do
not assume it.

New fields on the context, built in `make_extension_context` in `main.lua`:

```lua
---@field api fun(): table                      -- the WoW API table; call it, m.api style
---@field softres_source { register: fun( spec: SoftResSourceSpec ): boolean }
---@field softres_tap fun( name: string ): any? -- nil before the chain is built or if no such tap
---@field minimap { register: fun( c: MinimapContribution ), refresh: fun() }
```

- `api` is `M.api` — the *function*, not the table. `SoftResGui`, `NameManualMatcher` and
  `MinimapButton` all call `api()`, and moved code must not have to change shape.
- `softres_tap` returns `nil` rather than erroring when the chain is not built yet or the
  tap does not exist. It is called from `on_ready` and from chain factories, never from
  `on_enable`.
- Document in `Extensions.lua` that `ctx.get( name )` is valid **from `on_ready` and from
  inside chain factories**, not from `on_enable`. Today's comment says "on_ready only" and
  that is now too narrow — see the hazard in §4.3.

Update the `---@class ExtensionContext` block in `src/Extensions.lua` and the copy in
`EXTENSIONS_POC.md` §3.2.

### A6. RollSimulator

Two changes only in Phase A:

- `testing_blocked()`'s "is real data loaded" check becomes `m.SoftResSource.has_data()`.
  Delete the `main.unfiltered_softres.get_items()` reference.
- `setup()` emits `simulation_started` with the payload from the catalogue, in place of
  doing the soft-res work inline. In Phase A, `main.lua` subscribes to that event and does
  exactly what the inline code did (move the code, do not copy it). In Phase C that
  subscriber is deleted and the extension's takes over.

The `reservations` payload is normalized: `{ { name = "Psikutas", rolls = 2 }, ... }`. Core
never builds softres.it JSON again. `RollSimulator`'s current
`{ id = item.id, quality = ... }`-per-roll construction and its
`metadata = { origin = "raidres" }` literal both die here.

### A7. GargulBridge

`M.gargul_bridge = m.GargulBridge.new( ..., function() return M.softres_db.data end, ... )`
becomes `..., function() return m.SoftResSource.get_import_string() end, ...`.

`GargulBridge` itself does not change — it already takes the getter as a parameter. It
keeps its `softres` parameter (it reads `softres.get()` to whisper roll-offs to
soft-ressers; that is a consumer, and consumers stay).

### A8. `main.lua` cleanups that belong to Phase A

- `M.import_encoded_softres_data` emits `softres_imported` at the end, with the right
  `interactive` flag, and the Gargul broadcast + `auto_master_loot.on_softres_import()` +
  minimap refresh become subscribers rather than inline calls.
- `clear_data()` emits `softres_cleared`; `winner_tracker.clear()` and the minimap refresh
  become subscribers. The soft-res-side clears (`softres_gui.clear`, `name_matcher.clear`,
  `softres.clear`) stay inline for now — they move out in Phase C.
- `on_player_login` emits `player_login` **at exactly the point where
  `M.import_encoded_softres_data( M.softres_db.data )` is called today** (after
  `raid_lockout.refresh()`, before the `LootFrame:UnregisterAllEvents()` block). In
  Phase A core still does the import inline right after the emit; in Phase C the emit is
  all that is left and the extension does the import from its subscription. Preserving
  this position preserves the login ordering exactly.

### A9. Phase A acceptance

- `./test.sh` green, all 57 suites.
- `RollForNetherVortex`'s suite green against the synced core (`./sync-bcc.sh` once, then
  its own `test.sh`).
- In game: minimap icon colours, tooltip text, click behaviour, `/sr`, `/src`, `/srs`,
  `/sro`, `/rfsetup`, Gargul export — all indistinguishable from before.
- New tests listed in §9.4 for the registry, the null object, the event bus and the
  minimap contributions.

---

## 5. Phase B — build RollForSoftResIt

Core is untouched in this phase except for the TOC/`sync-bcc.sh` notes below. Core still
has its built-in soft-res, now registering itself as a *fallback* source, so the addon
works with or without the extension installed. **Phase B is shippable.**

### 5.0 First task: make core's built-in soft-res all-or-nothing

**Done — landed in core ahead of the rest of Phase B**, because it is core-only and
shippable on its own: while no source extension exists `SoftResSource.get()` is always
nil, the `if` is always taken, and behaviour is identical. Doing it first keeps the rest
of Phase B to the other repo. Implemented as a file-scope `builtin_softres` local in
`main.lua`, set immediately after `Extensions.enable()` and read by the four places that
contribute soft-res (`create_components` twice, `subscribe_for_component_events`,
`setup_slash_commands`) plus the login import. See the note at the end of this section.

Core and the extension cannot both own `matched_name`, `awarded_loot` and
`present_players` — whichever adds a name second gets `link 'matched_name' is already in
the chain`. So before anything else in this phase, core's built-in soft-res becomes a
single unit that exists only when nothing else claimed the source slot:

```lua
if not m.SoftResSource.get() then
  -- register the built-in source, add the three backbone links and the "unfiltered" tap,
  -- build SoftResCheck and SoftResGui, register the minimap contribution and the click
  -- subscription, register the /sr family, and subscribe the temporary
  -- simulation_started handler.
end
```

That list is §6.2's deletion list turned into an `if`, which is the point: Phase C then
deletes the block rather than unpicking it.

**Gating only the chain links is not enough, and it fails immediately.** Core builds
`M.softres_check` from `softres_tap( "unfiltered" )`, and that tap is declared alongside
`present_players`. Skip the links but keep the rest and `SoftResCheck` is constructed on
`nil`; core's minimap contribution then calls `check_softres` during login and the addon
dies with `attempt to index a nil value (upvalue 'softres')`. This was tried — that is the
actual error.

**What the change actually touched.** The store, `NameManualMatcher` and the built-in
`SoftResSource.register` moved down from above `Extensions.enable()` into the block (the
matcher is core's, and nothing between the two points used it). `/src` and `/srs` register
themselves from `SoftResCheck.new`, and `/sro` from `NameManualMatcher.new`, so they are
gated by construction rather than by an `if` of their own; only `/sr` needed one.
`M.on_group_changed` gained a `if M.name_matcher then` guard — it is the one consumer that
called into the built-in from outside the block. `test/utils.lua`'s `import_soft_res`
skips core's import path when a test has registered a source extension, since there is no
longer a core store to import into.

`SoftResSourcePrecedence_test` is where this is pinned: its probe extension now
contributes the backbone itself, as a real source must, and `BuiltInSteppedAsideSpec`
asserts core built none of its own — no store, matcher, `SoftResCheck` or gui, no `/sr`
family, no minimap contribution, no `simulation_started` subscriber — while `/rfreset`
still registers.

### 5.1 Layout

```
~/.projects/lua/wow-2.5.x-addons.git/master/RollForSoftResIt/
  RollForSoftResIt.toc
  RollForSoftResIt.lua                    -- registers the extension
  src/
    Decoder.lua                           -- base64 -> zlib -> JSON
    SoftResDataTransformer.lua            -- JSON -> SoftResData / HardResData
    SoftResStore.lua                      -- the store
    SoftResAwardedLootDecorator.lua
    SoftResPresentPlayersDecorator.lua
    SoftResAbsentPlayersDecorator.lua
    SoftResMatchedNameDecorator.lua
    NameAutoMatcher.lua
    NameManualMatcher.lua
    NameMatchReport.lua
    SoftResCheck.lua
    SoftResGui.lua
    Simulation.lua
    Minimap.lua                           -- the minimap contribution
    OptionsPage.lua
  test/
    ... vendored harness + the migrated suites (§9)
  test.sh
  README.md
  .editorconfig                           -- copy from RollForNetherVortex
  .luarc.json                             -- copy from RollForNetherVortex
```

### 5.2 TOC

```
## Interface: 20506
## Title: RollFor - SoftRes (softres.it)
## Author: Obszczymucha
## Version: 1.0
## Notes: softres.it soft-res import for RollFor.
## Dependencies: RollFor
## IconTexture: Interface\AddOns\RollFor\assets\icon-white
## X-RollFor-Extension: softres_it

src\Decoder.lua
src\SoftResDataTransformer.lua
src\SoftResStore.lua
src\SoftResAwardedLootDecorator.lua
src\SoftResPresentPlayersDecorator.lua
src\SoftResAbsentPlayersDecorator.lua
src\SoftResMatchedNameDecorator.lua
src\NameAutoMatcher.lua
src\NameManualMatcher.lua
src\NameMatchReport.lua
src\SoftResCheck.lua
src\SoftResGui.lua
src\Simulation.lua
src\Minimap.lua
src\OptionsPage.lua

RollForSoftResIt.lua
```

### 5.3 Namespace

The addon owns a `RollForSoftResIt` global and writes its modules there. It reads core
helpers off `RollFor` (`m.clone`, `m.getn`, `m.filter`, `m.map`, `m.colors`,
`m.pretty_print`, `m.slash_cmd`, `m.create_backdrop_frame`, `m.SoftRes.softres_item_data`,
`m.Chain.BASE`) — those are the published surface.

**Every moved file's `if m.X then return end` guard must be rewritten** to test the new
namespace (`if sr.SoftResCheck then return end` where `sr = RollForSoftResIt`), and the
trailing `m.X = M` becomes `sr.X = M`. Miss one and the module silently becomes a no-op
whenever core happens to define a same-named field. `NameMatchReport.lua` already has this
bug today (§3.4) — do not carry it over.

### 5.4 Registration

`RollForSoftResIt.lua`:

```lua
local function on_enable( ctx )
  local store = sr.SoftResStore.new( ctx.db( "softres" ) )

  local name_matcher = sr.NameManualMatcher.new(
    ctx.db( "name_matcher" ), ctx.api,
    sr.SoftResAbsentPlayersDecorator.new( ctx.group_roster, store ),
    sr.NameAutoMatcher.new( ctx.group_roster, store, 0.57, 0.4 ),
    function() ctx.minimap.refresh() end )

  ctx.softres_source.register( {
    id = "softres_it",
    title = "SoftRes (softres.it)",
    base = function() return store end,
    has_data = function() return RollFor.getn( store.get_items() ) > 0 end,
    get_import_string = function() return ctx.db( "softres" ).data end
  } )

  -- The backbone. These names are what RollForNetherVortex anchors to, so renaming one is
  -- a breaking change for that addon, not a local rename.
  ctx.softres_chain.add( {
    name = "matched_name",
    after = RollFor.Chain.BASE,
    factory = function( inner ) return sr.SoftResMatchedNameDecorator.new( name_matcher, inner ) end
  } )

  ctx.softres_chain.add( {
    name = "awarded_loot",
    after = "matched_name",
    -- ctx.get inside the factory, not outside: factories run at build time, by which
    -- point core has finished building the awarded-loot chain.
    factory = function( inner )
      return sr.SoftResAwardedLootDecorator.new( ctx.get( "awarded_loot" ), inner )
    end
  } )

  ctx.softres_chain.add( {
    name = "present_players",
    after = "awarded_loot",
    factory = function( inner ) return sr.SoftResPresentPlayersDecorator.new( ctx.group_roster, inner ) end
  } )

  ctx.softres_chain.tap( { name = "unfiltered", before = "present_players" } )

  -- Keeps name matching current as people join and leave.
  ctx.on_group_changed( function() name_matcher.auto_match() end )

  -- stash store / name_matcher for on_ready
end
```

and `on_ready` builds `SoftResCheck` (needs `ctx.softres_tap( "unfiltered" )`),
`SoftResGui`, `Simulation`, the minimap contribution, and registers the slash commands.

`options_page` is declared on the spec (not from `on_enable`), same as Nether Vortex, so a
*disabled* extension still gets the page carrying its Enabled checkbox. Base it on
`RollForNetherVortex/src/OptionsPage.lua` — summary paragraph plus the Enabled checkbox.

Registration happens at file scope at the bottom of the file, same as Nether Vortex.

### 5.5 What each moved piece needs from the context

| Moved thing | Needs | Where from |
|---|---|---|
| `SoftResStore` | its db | `ctx.db( "softres" )` |
| `SoftResGui` | api, import fn, softres_check, softres, clear fn, announce reset, is-simulating | `ctx.api`, own, own, `ctx.get( "softres" )`, own, `ctx.get( "dropped_loot_announce" ).reset`, `ctx.get( "roll_simulator" ).is_simulating` |
| `SoftResCheck` | unfiltered view, roster, name matcher, timer, absent fn, db | `ctx.softres_tap( "unfiltered" )`, `ctx.group_roster`, own, `ctx.ace_timer`, own, `ctx.db( "softres_check" )` |
| `NameManualMatcher` | db, api, absent unfiltered store, auto matcher, status changed cb | `ctx.db( "name_matcher" )`, `ctx.api`, own, own, `ctx.minimap.refresh` |
| `Simulation` | softres, unfiltered tap, bonus roll registry, config, gui | `ctx.get( "softres" )`, `ctx.softres_tap( "unfiltered" )`, `ctx.get( "resistance_bonus_roll_registry" )`, `ctx.config`, own |
| minimap contribution | softres_check | own |
| slash commands | — | `RollFor.slash_cmd` |

### 5.6 The import flow, after the move

`SoftResGui`'s Import button → the extension's `import_encoded( text, interactive )`:

1. `sr.Decoder.decode( text )` — on failure, print the same messages as today
   (`"Couldn't decode softres data!"`, `"Couldn't decompress softres data!"`,
   `"Could not load soft-res data!"`) and stop.
2. `store.import( data )` (which transforms and sorts, as today).
3. `name_matcher.auto_match()`.
4. `store.persist( text )` on a successful interactive import — the raw string and the
   import timestamp live in the extension's db now.
5. `ctx.event_bus.notify( "softres_imported", { source = "softres_it", raw = text,
   interactive = interactive } )`.

Login: subscribe to `player_login`, then `import_encoded( ctx.db( "softres" ).data,
false )` and `softres_gui.load( ... )` — the two calls `main.on_player_login` makes today.

Clear: the extension's `/sr init` path clears its store, gui and name matcher, then emits
`softres_cleared`.

### 5.7 SavedVariables migration

Existing users have their data under core's keys. On first run the extension migrates,
once:

| From (`RollForCharDb`) | To (`RollForCharDb`) |
|---|---|
| `softres` | `extension_softres_it_softres` |
| `name_matcher` | `extension_softres_it_name_matcher` |
| `softres_check` | `extension_softres_it_softres_check` |

Copy, do not move — leave the originals in place so a user who reverts to an older RollFor
still has their list. Guard with a flag in the extension's own db
(`migrated_from_core = true`) so it happens exactly once. Only copy a key if the
destination is empty.

Do the migration in `on_enable`, before the store is constructed.

### 5.8 Test harness

Vendored, exactly as `RollForNetherVortex` does it, including the
`package.path = "./?.lua;" .. package.path .. ";../../RollFor/?.lua;../../RollFor/libs/?.lua;../?.lua"`
ordering — **core must win those lookups**, because both ship a `src/`. Copy
`RollForNetherVortex/test/{luaunit,mocking,gui_helpers,utils,IntegrationTestBuilder}.lua`,
`mocks/` and `fixtures/` as the starting point, then re-adapt `utils.lua`'s module load
list and `IntegrationTestBuilder`'s chain to this addon. Mark every intentional delta from
core's copy with an `EXTENSION:` comment, same as Nether Vortex does, and record the
provenance in the file header.

The vendored `utils.lua` keeps `create_softres_data` (the softres.it JSON builder) — that
vocabulary belongs here now, not in core.

### 5.9 Phase B acceptance

- The extension's suite green.
- Core's suite still green (core is unchanged in this phase).
- `RollForNetherVortex`'s suite green.
- In game with the extension installed: the extension's source wins, core's built-in
  fallback is not registered, everything behaves as before.
- In game with the extension *not* installed: core's built-in still works.

---

## 6. Phase C — delete the built-in

This is the breaking commit. It lands in both repositories at the same time.

### 6.1 Delete from core

Files: `src/SoftResDataTransformer.lua`, `src/SoftResAwardedLootDecorator.lua`,
`src/SoftResPresentPlayersDecorator.lua`, `src/SoftResAbsentPlayersDecorator.lua`,
`src/SoftResMatchedNameDecorator.lua`, `src/NameAutoMatcher.lua`,
`src/NameManualMatcher.lua`, `src/NameMatchReport.lua`, `src/SoftResCheck.lua`,
`src/SoftResGui.lua`, `src/SoftResCheckResultPrinter.lua`, and the store + decode halves of
`src/SoftRes.lua`.

Drop all of them from `RollFor.toc` and from `test/utils.lua`'s module load list.

### 6.2 Delete from `main.lua`

`clear_data` (the soft-res half), `update_minimap_icon`'s soft-res mapping,
`on_softres_status_changed`, `M.present_softres`, `M.absent_softres`, `M.softres_db`,
`M.unfiltered_softres`, `M.name_matcher`, the four backbone `softres_chain.add` calls, the
`unfiltered` tap declaration, `M.softres_check`, `M.softres_gui`, `M.import_softres_data`,
`M.import_encoded_softres_data`, `on_softres_command`, the `/sr` registration, the built-in
`SoftResSource.register` block, the built-in minimap contribution, and the temporary
`simulation_started` subscriber.

`GroupAwareSoftResFn` and its two aliases go with them.

What is left in `main.lua`: `M.softres = M.softres_chain.build( m.SoftResSource.base()
).final`, the conditional `bonus_roll` link, the event emissions, and the consumers —
which do not change at all.

### 6.3 The no-source experience

With no source extension installed, RollFor still loads and every non-soft-res feature
works. Make that explicit rather than mysterious: at the end of `on_player_login`, if
`m.SoftResSource.get()` is `nil`, print once:

```
No soft-res source installed. Soft-res features are unavailable — install RollForSoftResIt.
```

`m.pretty_print`, not `m.err`. Do not print it more than once per session.

### 6.4 Docs to update in the same commit

- `RollFor.toc` `## Notes:` — currently promises "soft ressing support via softres.it".
  It no longer ships that. Reword: `An automated item roller with soft-res support
  (requires a soft-res source addon).`
- `README.md` — the soft-res import section (lines ~84, ~146–190) has to say the import
  lives in `RollForSoftResIt` and where to get it. The screenshots stay valid.
- `EXTENSIONS_POC.md` — add this extraction to §7's decisions table and note that the
  context is now v2.
- `RollForSoftResIt/README.md` — new; what it is, that it requires RollFor, and the
  import instructions moved out of core's README.

### 6.5 `sync-bcc.sh`

It syncs only `RollFor/`. That is still correct — `RollForSoftResIt` lives in the addons
repo and is edited there directly. Do not add it to the sync script; you would overwrite
the addon with nothing. Leave the script alone.

### 6.6 The simulation move

Core's `RollSimulator` keeps: argument parsing, the fake group, `roll_controller.preview`,
`/rfr` roll injection, `testing_blocked` (now via `SoftResSource.has_data()`), and the
`simulation_started` emission.

`RollForSoftResIt/src/Simulation.lua` subscribes to `simulation_started` and does what
core's lines 290–320 and 371–376 do today:

1. Import the reservations into the store (normalized: `rolls` copies of the item per
   player, since duplicate entries are what grant extra rolls).
2. Build the stand-in — `m.clone( ctx.get( "softres" ) )` with `get` / `get_all_rollers`
   coming from `ctx.softres_tap( "unfiltered" )` plus class enrichment — and overwrite
   `softres.get` / `softres.get_all_rollers` in place.
3. `softres_gui.refresh()`.

**Known wart, do not try to fix it here:** step 2 re-wraps the stand-in in
`RollFor.SoftResBonusRollDecorator`, so this addon reaches for a core module belonging to
a feature that is itself destined to become an extension. Guard it
(`if RollFor.SoftResBonusRollDecorator then ... end`) and leave a comment pointing at
section 6 of `EXTENSIONS_POC.md`, where bonus rolls will grow their own simulation
contribution. Carry over the existing comment about why the stand-in rebuilds the layers
above the tap rather than hardcoding them — that comment records a real bug that was fixed
once already.

### 6.7 Phase C acceptance

- Core's suite green, with core's suite no longer containing any soft-res *pipeline* test.
- The extension's suite green.
- `RollForNetherVortex`'s suite green **and** its in-game behaviour verified: it anchors
  to `awarded_loot` and `present_players`, which are now contributed by RollForSoftResIt.
  Two cases, and they are different:

  **Both installed.** Addons load alphabetically, so `RollForNetherVortex` registers — and
  therefore enables — *before* `RollForSoftResIt` contributes the links it anchors to. This
  works only because `Chain` resolves anchors at build time; it is the reason that change
  was made. Verify in game that Nether Vortex still lands between `awarded_loot` and
  `present_players`, because nothing about the load order is under either addon's control.

  **RollForSoftResIt uninstalled.** Nether Vortex's link can never be placed, so the chain
  leaves it out at build time and prints `link 'nether_vortex' is anchored after
  'awarded_loot', which is not in the chain. ... It has been left out.` Login is otherwise
  unaffected. **Verify that specific path by hand** — it is the one place where this design
  is allowed to be user-visible ugly, and it must at least be legible.

  Nether Vortex's own `ExtensionRegistration_test` encoded the old add-time contract and
  was updated to the new one when `Chain` changed. That is the only edit to that addon this
  work is allowed to make, §1.2 notwithstanding, and it is a test-only one.
- Fresh install with no source: no errors, the one-line notice, white minimap icon, a
  tooltip with no soft-res commands in it, `/rf` opens options, rolling without soft-res
  works.
- Upgrade path: an existing character's saved soft-res string is migrated and still loaded.

---

## 7. Consumers that must not change

Listed so that a diff touching them is a red flag. Each takes `M.softres` or
`M.unfiltered_view` and needs no edit beyond what §4 already describes:

`RollController`, `RollingStrategyFactory`, `LootController`, `DroppedLootAnnounce`,
`SoftResLootListDecorator`, `SoftResRollingLogic`, `SoftResBonusRollDecorator`,
`GargulBridge` (except the getter), `show_how_to_roll`, and `main.lua`'s hard-res check in
`on_roll_command`.

---

## 8. Slash commands

| Command | Today | After |
|---|---|---|
| `/sr` | core, `on_softres_command` | extension |
| `/src` | core, registered inside `SoftResCheck` | extension |
| `/srs` | core, registered inside `SoftResCheck` | extension |
| `/sro` | core, registered inside `NameManualMatcher` | extension |
| everything else | core | core |

`m.slash_cmd` already refuses to register a command that exists and logs it at debug
level, so a stale core registration would be silently shadowed rather than erroring.
Delete core's registrations properly; do not rely on that.

---

## 9. Tests

### 9.1 The rule for where a test lives

> A test stays in core if it passes against the **naive** test double (§9.3). A test moves
> to the extension if it needs group filtering, awarded-loot filtering, name matching,
> hard-res-after-award behaviour, import/decode, the import GUI, or `SoftResCheck`.

Mechanically: convert the file to the double, run it, and **if it fails, move it**. Do not
extend the double to make it pass. That is rule 4 from §0 and it is the rule most likely to
be broken under time pressure.

### 9.2 Expected classification

This is my expectation, not authority — §9.1 decides. It is here so that a wildly
different outcome tells you something went wrong.

| Suite | Expected | Why |
|---|---|---|
| `SoftRes_test` | move | the store |
| `SoftResDataTransformer_test` | move | the JSON shape |
| `SoftResGui_test` | move | the import window |
| `SoftResAwardedLootDecorator_test` | move | a moved decorator |
| `SoftResBonusRollDecorator_test` | move | needs the chain under it |
| `NameAutoMatcher_test` | move | moved module |
| `SoftResRollSpec_test` | move | absent players, awarded loot |
| `softres_rolls_test` | move | same, via the full addon load |
| `RollSimulator_test` | move | asserts the stand-in bypassing the group filter |
| `DroppedLootAnnounce_test`, `..._integration_test` | move | soft-res announcements depend on filtering |
| `SrRowContract_test` | probably stays | needs data, not filtering |
| `BonusRowContract_test` | probably stays | bonus rolls are core for now |
| `BonusRollSpec_test` | probably stays | same |
| `PreviewSpec_test` | probably stays | needs data, not filtering |
| `LootList_test`, `LootListSpec_test` | probably stays | `SoftResLootListDecorator` stays in core |
| `AutoLootSpec_test` | probably stays | only needs an item to be soft-ressed |
| `Chain_test`, `Extensions_test`, `ConfigExtensionSettings_test`, `ExtensionOptionsWiring_test`, `OptionsFrameSpec_test` | stays | core machinery |
| `mainspec_rolls_test`, `offspec_rolls_test`, `tie_rolls_test`, `both_spec_rolls_test`, `RaidRollSpec_test`, `NormalRollSpec_test`, `InstaRaidRollSpec_test` | stays, untouched | no soft-res at all |

A moved suite is **moved, not copied**. Two copies of `SoftResRollSpec` drifting apart is
worse than either one alone.

### 9.3 Core's test double

New `test/mocks/SoftResSource.lua`: a source built from the existing
`u.soft_res_item( player, item_id, quality )` vocabulary, implementing **only** the six
read methods over a literal table. No group filtering. No awarded-loot filtering. No name
matching. No import. No persistence. Roughly 60 lines.

Rewrite `u.soft_res( ... )` / `u.import_soft_res( data )` in `test/utils.lua` to register
this double instead of building softres.it JSON and calling `rf.import_softres_data`.
Delete `u.create_softres_data`, `u.import_softres_via_gui` and `u.mock_softres_gui` from
core's copy (they live in the extension's vendored copy).

`IntegrationTestBuilder`'s `soft_res_data(...)` registers the double and builds the chain
with **no backbone links** — which is exactly what core looks like with no source
installed. Its `bonus_roll` link then has nothing to anchor to, so add it without an anchor
(appended last) when `present_players` is absent, mirroring §4.3.

Put a comment at the top of the double saying, in as many words: *this is deliberately
dumb; if your test needs filtering, your test belongs in RollForSoftResIt.*

### 9.4 New core tests

- `test/SoftResSource_test.lua` — registers; refuses a second registration and keeps the
  first; validates the spec; `base()` returns a working null when nothing is registered;
  `has_data()`/`get_import_string()` are safe with no source.
- `test/EventBus_test.lua` — `notify` returns the callback count; `has_subscribers`;
  notifying an event with no subscribers returns `0` and does not error.
- `test/MinimapContributions_test.lua` — colour severity resolution across two
  contributions; contributions registered *after* the button is built still show up
  (this is the §4.4 trap, and it deserves a test that would catch it);
  tooltip ordering; the default hint with no contributions.
- `test/MinimapClick_test.lua` — with no subscriber the click opens options; with a
  subscriber it does not, and the subscriber runs.
- Extend `test/Extensions_test.lua` for `API_VERSION = 2` still accepting
  `api_version = 1`.

### 9.5 New extension tests

- `ExtensionRegistration_test` — modelled on Nether Vortex's: the addon registers, its
  source is the one core uses, its four links land in the right order, and the
  `unfiltered` tap resolves to the value before `present_players`.
- `AwardedLootFactoryTiming_test` — the §4.3 hazard: the `awarded_loot` link's factory sees
  the *decorated* awarded loot, so a player who already won the item is filtered out. This
  test is the reason the hazard is written down; write it early.
- `Migration_test` — core's old db keys are copied to the extension's, once, and not when
  the destination already has data.
- Plus every migrated suite from §9.2.

---

## 10. Order of work, as a checklist

**Phase A** (core only, one commit per numbered item is fine):

1. `EventBus`: count-returning `notify`, `has_subscribers`, rename `config_event_bus`.
2. `src/SoftRes.lua` slimmed to types + `softres_item_data` + `null()`; store and decode
   stay where they are for now but the *interface annotation* is the six read methods.
3. `src/SoftResSource.lua` + core's built-in fallback registration.
4. Chain order in `create_components`: `Extensions.enable` first, conditional
   `bonus_roll`, build from `SoftResSource.base()`, guarded tap.
5. `MinimapButton`: contribution registry, click event, core's own contribution, `White`
   initial colour.
6. `ctx` v2 (`api`, `softres_source`, `softres_tap`, `minimap`), `API_VERSION = 2`.
7. `RollSimulator`: `has_data()`, `simulation_started` emission + temporary core
   subscriber.
8. `GargulBridge` getter; the `softres_imported` / `softres_cleared` / `player_login`
   events and their core subscribers.
9. New core tests from §9.4. Full suite green. Nether Vortex suite green. **Commit.**

**Phase B** (addons repo, plus nothing in core):

9a. §5.0, in core, on its own: the built-in becomes all-or-nothing behind
    `builtin_softres`. Behaviour-identical until a source extension exists. **Done.**
10. Scaffold `RollForSoftResIt` (TOC, entry, `.editorconfig`, `.luarc.json`, `test.sh`).
11. Copy the moving files in, rewrite namespaces and guards.
12. Registration, `on_ready`, options page, minimap contribution, slash commands,
    migration.
13. Vendor the harness; migrate the suites from §9.2; both suites green. **Commit both
    repos.**

**Phase C** (both repos, one landing):

14. Delete from core: files, TOC, `main.lua`, `test/utils.lua` load list.
15. Core's test double + the `u.soft_res` rewrite; reclassify any suite that now fails
    per §9.1.
16. The no-source notice; docs (`RollFor.toc` notes, both READMEs, `EXTENSIONS_POC.md`).
17. Manual verification list from §6.7. **Commit both repos.**

---

## 11. Traps

Collected in one place. Every one of these has bitten something in this codebase already,
or is a direct consequence of a decision above.

1. **Minimap contributions read at construction instead of at render.** The button exists
   before extensions register. Symptom: an empty tooltip and a white icon, forever.
2. **`ctx.get( "awarded_loot" )` called from `on_enable` instead of from inside the chain
   factory.** Symptom: no error, and players who already won an item can roll for it
   again. Silent and expensive. §9.5 has the test.
3. **Forgetting the `interactive` flag on `softres_imported`.** Symptom: RollFor
   re-broadcasts the soft-res list to Gargul on every login, and auto-master-loot fires
   when nobody imported anything.
4. **Namespace guards not rewritten in moved files.** Symptom: a module silently becomes a
   no-op. `NameMatchReport.lua` ships this bug today; do not propagate it.
5. **Teaching the core test double to filter.** Symptom: green tests, broken addon.
6. **`m.SoftRes.softres_item_data` disappearing from core.** Six live core files call it
   (`GargulBridge`, `LootController`, `SoftResLootListDecorator`, `RollingStrategyFactory`,
   `RollController`, `DroppedLootAnnounce`), plus the dead `SoftResRollGuiData.lua` from
   §3.6. It stays in core's slim `SoftRes.lua`.
7. **`M.null()` returning a shared singleton.** Decorators clone and mutate. Return a new
   table per call.
8. **Deleting the `unfiltered` tap's consumers without noticing `RollSimulator` uses it.**
   The tap is declared by the extension; core reads it only through the guarded accessor.
9. **Renaming a backbone chain link.** `matched_name`, `awarded_loot`, `present_players`
   are `RollForNetherVortex`'s anchors. They are public API now, even though they are
   registered by a different addon than the one that used to own them.
10. **Assuming extensions enable in a useful order.** They enable in load order, which is
    alphabetical, which puts `RollForNetherVortex` before `RollForSoftResIt`. Nothing may
    depend on a source extension having enabled first. Build-time anchor resolution is what
    makes that safe; do not undo it.
11. **Core and a source extension both adding the backbone names.** Symptom: the
    extension's `on_enable` throws, `Extensions.run`'s `pcall` swallows it, and the
    extension is quietly disabled with core's soft-res still in the chain. See §5.0.
12. **Assuming the extension can be tested against a stale core.** `./sync-bcc.sh` must
    have run. A green extension suite against yesterday's `../RollFor` means nothing.
13. **Doing Phase C before Phase B is green in both repos.** There is no intermediate state
    where half the soft-res lives in each place and the addon works.

---

## 12. Deferred, deliberately

- Two sources installed at once: what "active" means, what a second import does, whether
  the minimap click opens two windows. Today: exactly one source may register; the second
  is refused with an error.
- Whether a shared "SR core" extension is worth extracting. That question is answerable
  only after RollForRaidres exists, which is the entire reason it is not answered here.
- Whether the normalized model needs to grow for raidres' capabilities.
- Bonus rolls contributing their own simulation wrap, which would remove the wart in §6.6.
- Bundling the source extension into RollFor's release zip. Decided against for now; if
  the "install a second addon" step proves too much friction in the wild, `release.sh` is
  where it would change.
