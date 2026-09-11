# Extracting auto-loot, and the core/extension cleanup around it

Goal: auto-loot becomes `RollForAutoLoot`, an extension addon in the shape of
`RollForAutoRobin`. Along the way, core stops holding things that belong to
extensions, and the components auto-loot shares with the round-robin window get
honest names and a committed home.

Written to be implemented in order. Each phase leaves the tree green, so stopping
after any of them is a valid outcome.

## Decisions already taken

Do not re-litigate these; they were settled before this document was written.

1. **Pipeline anchors.** Core declares the named positions in the loot pipeline
   and fills vacant ones with no-ops. Position names stop depending on who
   occupies them. `Ordering` itself is not changed, so the soft-res chain is
   untouched.
2. **Cross-extension access.** Auto-loot publishes a small named surface;
   AutoRobin asks it by name. No claims registry, no component publishing on
   `ctx`. The precedence rule ("conflicts resolve in auto-loot's favour") stays
   where a reader finds it -- one line in AutoRobin.

   The question has to be asked *ahead of time*: `GiveMasterLoot` is
   asynchronous, so the slot auto-loot has taken is still in the corpse when the
   rotation looks at it. Reading the loot list instead of asking is not an
   available simplification -- it would read as "still there" and the rotation
   would hand out an item auto-loot is already taking.
3. **Existing users are not a concern.** No saved-variables migration. The old
   `RollForCharDb.autoloot_db` is left orphaned.
4. **Distribution.** `RollForAutoLoot` ships as its own addon like every other
   extension. `release.sh` is unchanged.
5. **The `General` node** (quality rows, not bosses) is an auto-loot feature and
   goes to the extension, not to `DropTable`.
6. **Shared tree components go on `ctx`**, and `Extensions.API_VERSION` becomes 5.

## Phase 1 -- Core declares the pipeline positions

**Why.** `LootFacadeListener.placed_for` drops any handler whose anchor is not
registered. Three handlers anchor to `auto_loot`: core's `master_loot`
(`after`), `RollForAutoRobin` (`after`), `RollForPendingLoot` (`before`). An
extension's handlers are only registered while it is enabled, so the moment
auto-loot moves out and is switched off, all three silently fall out of
`LootOpened`. Per that module's own header, a wrong position hands the item to
the wrong person rather than throwing.

**Change.** In `RollFor/src/LootFacadeListener.lua`, declare the positions:

```lua
local POSITIONS = {
  LootOpened = { "dropped_loot", "dropped_loot_announce", "auto_loot",
                 "master_loot", "auto_group_loot", "roll_controller" },
  LootSlotCleared = { "master_loot", "auto_group_loot" },
  LootClosed = { "roll_controller" },
  ChatMsgLoot = { "master_loot" }
}
```

In `start()` -- not in `register_core`, because extensions register during
`Extensions.enable`, which runs first -- walk each event's list in declared
order and, for any name with no registered handler, insert a no-op anchored
`after` the previous name in the list. Walking in order guarantees the previous
name is already present, real or placeholder.

`on_loot` rejects duplicate names, so only genuinely vacant positions get one.

**Acceptance.** A spec asserting that with no `auto_loot` handler registered,
`order( "LootOpened" )` still lists all six names in order, and a handler
anchored `after = "auto_loot"` still lands after `dropped_loot_announce`.

## Phase 2 -- Split `AutoLootDb`

`AutoLootDb` is three things wearing one name.

**New `RollFor/src/DropTable.lua`** -- the item-to-boss catalogue, which is core's
because core reads it (`BossKilled`, `DropSimulator`) and core cannot depend on
an extension:

- `M.ids` -- dungeon -> bosses -> items, i.e. today's `ids` **minus** the
  `General` node.
- `M.non_bosses` (today's `NON_BOSSES`).
- `M.find_boss`.
- The dev fetch tool at the tail of the file -- `on_command`, `on_print_command`,
  `on_item_info_received`, `dump_to_db`. It resolves stub catalogue entries, so
  it follows the catalogue. Note `on_item_info_received` is called live from
  `main.lua` on `GET_ITEM_INFO_RECEIVED` even though both slash commands are
  commented out.

**Move to `ItemUtils`**: `make_link`, `quality_color_hex` and the
`QUALITY_COLOR_HEX` constant. These are link building, which is what `ItemUtils`
is for, and moving them means AutoRobin's frame stops depending on the catalogue
module for presentation.

**`AutoLootDb` keeps** the selection layer -- `ensure_seeded`, `is_enabled`,
`is_quality_enabled`, `has_enabled_items`, `has_enabled_qualities` -- and becomes
the owner of the `General` category definition. `ensure_seeded` now seeds from
`m.DropTable.ids` merged with its own `General` node. It leaves for the extension
in Phase 4; keeping it in core for one phase keeps this step core-only.

**Callers to update**: `BossKilled`, `DropSimulator` (four sites), `main.lua`
(the `make_link` in the autoloot frame config),
`RollForBtSrLimitCheck/src/SoftResLimitCheck.lua`,
`RollForAutoRobin/src/AutoRoundRobinFrame.lua` (`make_link`).

**TOC**: add `src\DropTable.lua` ahead of `src\AutoLootDb.lua`.

**Also delete**: `AutoLootTree.is_leaf_enabled`. It has no production caller --
only its definition, two comments and five tests. The rule was reimplemented in
`AutoLootDb.is_enabled`, which walks the db directly. Delete its tests with it.

**Preserve**: `find_boss` skips `NON_BOSSES`, and every consumer guards with
`dungeon.bosses or {}`. Both matter; neither is incidental.

## Phase 3 -- Rename the shared tree components, put them on `ctx`

The catalogue holds facts; the selection tree holds what the user ticked. Name
them that way.

| now | becomes |
|---|---|
| `AutoLootTree` | `SelectionTree` |
| `AutoLootFrame` | `SelectionTreeFrame` |
| `AutoLootFrameContentTransformer` | `SelectionTreeFrameContentTransformer` |
| `Tree` | unchanged -- already generic and honest |

Types: `AutoLootFrameConfig` -> `SelectionTreeFrameConfig`; `AutoLootFrameData` ->
`SelectionTreeFrameData`; `AutoLootFrameButtonWithCallback` ->
`SelectionTreeFrameButton`; `AutoLootFrameTreeNode` -> `SelectionTreeRow`, because
it is a row (`depth`, `expandable`, `checked`) and not a `TreeNode`.

**Extension-specific things core should stop holding:**

- `button_definitions` hardcodes a `"Queues"` entry -- AutoRobin's button, with a
  comment saying so -- and `AutoLootFrameButtonType` is a closed alias listing it.
  Delete both; the caller passes `label` and `width` with its callback.
- `AutoLootTree.init` and the `M.dungeons` singleton. `init` calls
  `AutoLootDb.ensure_seeded` and parks the roots in a module global; the file's
  own comment already admits a singleton can only belong to one of the two
  windows. Both go to the extension in Phase 4. `SelectionTree` keeps `build`,
  `build_flat`, `all_checked`, `set_checked`, `visible_rows`.

**`ctx` and the API version.** Add `selection_tree` and `selection_tree_frame` to
`ExtensionContext`, alongside the existing `frame_builder` and `gui_elements`,
with `---@field` entries. Bump `Extensions.M.API_VERSION` to 5. One bump covers
this and the `softres_source.get_import_string` that Phase 5 needs.

AutoRobin reaches these as `RollFor.*` globals today, which `Extensions.lua` says
are refactorable and uncommitted. Moving them onto `ctx` makes the break
versioned: an extension declaring `api_version = 3` or `4` stays registered but
disabled with a clear message, instead of erroring somewhere less obvious.

**Update `RollForAutoRobin`**: `api_version = 5`, read the components off `ctx`,
pass its Queues button as label/width.

## Phase 4 -- Extract `RollForAutoLoot`

New addon at `$ROLLFOR_ADDONS/RollForAutoLoot/`, modelled file-for-file on
`RollForAutoRobin`.

**TOC**

```
## Interface: 20506
## Title: RollFor - Auto Loot
## Author: Obszczymucha
## Version: 1.0
## Notes: Automatically master-loots the items you tick.
## Dependencies: RollFor
## Group: RollFor
## IconTexture: Interface\AddOns\RollFor\assets\icon-white
## X-RollFor-Extension: auto_loot

src\AutoLootDb.lua
src\AutoLoot.lua
src\OptionsPage.lua

RollForAutoLoot.lua
```

**Registration** -- `name = "auto_loot"`, `api_version = 5`,
`default_enabled = true`.

`on_enable`:

- Four `ctx.config.register_toggle` calls. Copy `cmd`/`display`/`help` verbatim
  from `Config.lua` so `/rf config auto-loot` and friends are unchanged.
  Defaults, matching today: `auto_loot` true, `auto_loot_announce` true,
  `superwow_auto_loot_coins` true, `auto_loot_messages` **false** (core sets no
  default for it, so it is falsy today -- do not "fix" this here).
- `ctx.on_loot( "LootOpened", { name = "auto_loot", after = "dropped_loot_announce", ... } )`
  -- the same name, which Phase 1 made a declared position.
- `ctx.on_dropped_item( ... )` -- the announcement rule lifted out of
  `DroppedLootAnnounce`: withhold when the item is auto-looted **and** not on the
  predefined list **and** `auto_loot_announce` is off. Guard on the component
  existing, since it is built in `on_ready`; core reads the predicate table at
  call time, so registering here is correct.

`on_ready`:

- `local db = ctx.db( "db" )`, then `AutoLootDb.ensure_seeded( db )` and build the
  roots with `ctx.selection_tree.build( db, m.DropTable.non_bosses )`. This is
  where `init`/`dungeons` from Phase 3 land, as locals.
- Build `AutoLoot` from `ctx.get( "loot_list" )`, `ctx.api`, `db`, `ctx.config`,
  `ctx.player_info`, `ctx.chat`.
- Build the window with `ctx.selection_tree_frame.new{ ... }`.
- `ctx.on_rf_command( "autoloot", function() frame.toggle() end )`.
- Publish the surface AutoRobin reads:

```lua
RollForAutoLoot = RollForAutoLoot or {}
RollForAutoLoot.claims = function( item ) return auto_loot.is_auto_looted( item ) end
```

  A committed name, deliberately a separate global from the addon's module table,
  the same reasoning AutoRobin documents for `RollForApi`. Say so in a comment.

**`on_enable` also drops the dead button.** `AutoLoot.lua` has
`local button_visible = false` which is never assigned, so the LootFrame "Auto
Loot" button and `create_frame` are unreachable. Delete them on the way out.

**Core removals**

- `src/AutoLoot.lua` and `src/AutoLootDb.lua` -- from `RollFor.toc` and from disk.
- `Config.lua`: the four toggle rows and their defaults.
- `OptionsFrame.lua`: the four `add_toggle` calls.
- `main.lua`: `autoloot_db` and its migration; `M.auto_loot`; the `auto_loot`
  entry passed to `register_core`; `autoloot_frame`, its content transformer and
  the `AutoLootTree.init` call; the `^autoloot` branch in the slash handler;
  `autoloot` from `RF_COMMANDS`; the commented-out `autolootdb` block. Keep the
  `on_item_info_received` call, repointed at `DropTable`.
- `DroppedLootAnnounce`: drop `auto_loot` from `M.new` and
  `process_dropped_items`. The filter line becomes
  `if item.id == 29434 then return false end` -- Badge of Justice is core's own
  rule, unrelated to auto-loot (`DroppedLoot.lua` carries the same one).
- `LootFacadeListener.register_core`: remove the `auto_loot` handler. The
  position stays declared.

**AutoRobin change.** Replace `ctx.get( "auto_loot" )` and the
`auto_loot.is_auto_looted( item )` call in `AutoRoundRobin.is_awardable` with the
guarded global. Keep the "conflicts resolve in auto-loot's favour" comment -- it
is now the only place that rule is written down -- and keep it an up-front
question rather than an observation of the loot list, for the asynchrony reason
in decision 2.

```lua
local function claimed_by_auto_loot( item )
  return RollForAutoLoot and RollForAutoLoot.claims and RollForAutoLoot.claims( item ) or false
end
```

**Tests.** This is the bulk of the phase.

- Move `test/AutoLootSpec_test.lua` and the auto-loot-specific cases of
  `test/AutoLootTree_test.lua` into the new addon.
- Vendor `test/utils.lua`, `test/mocking.lua`, `test/gui_helpers.lua`,
  `test/luaunit.lua` and `test/IntegrationTestBuilder.lua` from
  `RollForAutoRobin`'s copies -- those already carry the `EXTENSION:` markers and
  the `../../RollFor/?.lua` package path.
- Delete `test/mocks/AutoLoot.lua` from core **and from the four extensions that
  vendor it** (`RollForAutoRobin`, `RollForNetherVortex`, `RollForPendingLoot`,
  `RollForBtSrLimitCheck`), along with the `r( "src/AutoLoot" )` and
  `r( "src/AutoLootDb" )` lines in each `test/utils.lua`. Add
  `r( "src/DropTable" )` where `find_boss` is needed -- `RollForBtSrLimitCheck`
  at least.
- `RollForAutoRobin/test/AutoRoundRobinSpec_test.lua` has two cases asserting
  auto-loot wins over the rotation
  (`should_leave_an_item_auto_loot_claims_alone...`,
  `should_leave_a_quality_auto_loot_sweeps_alone...`). Stub
  `RollForAutoLoot.claims` in those specs rather than loading the real addon.
  Keeping that stub one function wide is the point of the narrow surface.
- New addon needs `.luarc.json` with `"Lua.workspace.library": [ "../RollFor" ]`,
  copied from `RollForAutoRobin`'s, and its own `test.sh` (byte-identical to the
  others).

## Phase 5 -- Extract `GargulBridge`

Independent of everything above; can be done before or after.

193 lines of core speaking a third-party addon's comm protocol -- `GargulComm2`,
hardcoded `GARGUL_VERSION` and `GARGUL_MIN_VERSION`. Nothing in core depends on
it; `main.lua` already guards its one call site with `if M.gargul_bridge then`.

New `RollForGargul` extension. It needs `player_info`, `config`,
`ctx.get( "roll_controller" )`, `ctx.get( "softres" )`, `ctx.event_bus` for
`softres_imported`, and `get_import_string` -- which `ctx.softres_source` does not
expose today. Add it there as part of the API 5 bump.

Remove from core: `src/GargulBridge.lua` and its TOC line, the
`M.gargul_bridge` construction, and the `broadcast_softres` call plus its
Gargul-specific comment inside the `softres_imported` subscriber.

## Phase 6 -- Comment sweep

**Rule**: core may name an extension to explain *why an API has its shape*; it
may not name one to explain *what core does*.

Fix (all fail the rule): `SelectionTree` (ex-`AutoLootTree`) around lines 50,
114-119, 176-178, 223, 242; `SelectionTreeFrame` (ex-`AutoLootFrame`) 22, 145,
261; `Config.lua` ~519; `ListPopup.lua` ~77; `GuiElements.lua` ~1128 and ~1270.

Keep: `Chain.lua:22` and `Extensions.lua:134`. Both are API rationale and get
worse if the example is stripped.

Keep: the `RollForSoftResIt` name in `main.lua`'s "no soft-res source installed"
message. It is a pointer for a user who has nothing installed, and the
alternative helps nobody.

`build_flat` stays. "Category -> items" is a legitimate generic shape; only its
comments need de-AutoRobin-ing.

## Verification

After **every** phase, both of:

```
./test.sh
./check.sh
```

They catch disjoint things (see `CLAUDE.md`); neither substitutes for the other.
`check.sh` is especially load-bearing here -- this work is rename-heavy, and
`CLAUDE.md` records that renames shadow silently and that a moved function
inherits the doc block left above it. Run `./sync-bcc.sh` so the addons tree has
core's changes before the extension suites run against it. `check.sh` picks up
`RollFor*` directories automatically, so the new addon is covered once its
`.luarc.json` exists.

## One thing not to port

**`AutoLoot.loot_item` is dead and buggy -- delete it, do not move it.** It calls
`find_my_candidate_index()` with no argument although the function takes a `slot`
and uses it in `GetMasterLootCandidate( slot, i )`, so it would always have looked
up candidate names for a nil slot. Verified: no caller in core, in the tests, or
in any extension. Drop it from the returned table, from `M.interface` and from the
`---@class AutoLoot` fields.
