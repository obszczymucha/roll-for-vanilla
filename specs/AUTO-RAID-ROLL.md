# Auto Round Robin (`/rf autorobin`)

Status: **implemented.** Written 2026-09-01, built the same day.

Two things came out differently from what is written below, both noted again in place:

- The shared seeding/query helper section 10 asks for is `src/ItemCatalogue.lua`, a fifth new
  file. `AutoLootDb` and `AutoRoundRobinDb` both delegate to it and keep their own public names,
  so nothing that already called `AutoLootDb.is_enabled` had to change.
- `AutoLootFrame`'s config table takes an `extra_buttons` field in addition to the fields listed
  in section 8.1 -- section 8.2 wants a `Queue` button on the round-robin window, and there was
  no field in that list to put one in. Auto-loot passes none, so its window is unchanged.

## 1. What it is

A master looter opt-in that hands selected items to group members in a rotation instead of
rolling for them or looting them to self. When a loot window opens and an item on the
round-robin list is in it, the addon picks a player who has not received an item in the
current cycle, awards it via `GiveMasterLoot`, announces it, and records the award. Once
everybody eligible has received one, the cycle resets and it starts over.

The intended use is consumable-ish bulk drops that nobody wants to burn a roll on -- the
initial catalogue is exactly the epic gems from Mount Hyjal and Black Temple.

### Naming

`Config.lua` already has a toggle keyed `auto_raid_roll` (`/rf config auto-rr`, "Auto
raid-roll") which does something else entirely: it auto-starts a raid roll when a normal
roll produces no winner (see `RollingLogic.lua:192`). This document lives at the requested
`specs/AUTO-RAID-ROLL.md`, but every identifier introduced below uses **round robin** /
`auto_round_robin` / `autorobin` so nothing collides with that existing feature.

## 2. Terminology

- **Pool** -- the persisted set of players this character has ever seen in a group, each
  with the cycle number in which they were last served. Never pruned.
- **Cycle** -- a monotonically increasing counter. One cycle is one pass in which everybody
  eligible gets one item.
- **Eligible candidate** -- a name returned by `GetMasterLootCandidate( slot, i )` for the
  slot being awarded. This, and not the group roster, decides who can actually receive.
  Players outside the instance, offline, or out of range are simply not returned, and the
  rotation must not stall on them.

Membership in the pool and eligibility to receive are independent. Conflating them is the
central bug this design exists to avoid.

## 3. Selection algorithm

State: `cycle` (number) and `pool` (`name -> served_cycle`).

On every roster update (`GROUP_ROSTER_UPDATE` / `PARTY_MEMBERS_CHANGED`):

> For each player in the group with no pool entry, insert them with
> `served_cycle = cycle`.

That single rule covers both seeding and joining, and is why a joiner lands at the bottom:
being marked as already served for the current cycle, they cannot receive until the cycle
turns over. Players already in the pool are never touched, so leaving and rejoining keeps
your place exactly.

On each award, for the slot in question:

1. Build `candidates` from `GetMasterLootCandidate` for that slot, intersected with the
   group roster (the same way `MasterLootCandidates.get` already does it). Insert any
   candidate missing from the pool at `served_cycle = cycle` first.
2. Let `min_served` be the lowest `served_cycle` among `candidates`.
3. If `min_served == cycle`, every eligible candidate has already been served this cycle:
   set `cycle = cycle + 1` and go back to step 2. (One increment always suffices -- after
   it, `min_served < cycle` holds for every candidate.)
4. Pick uniformly at random among the candidates whose `served_cycle == min_served`.
5. Award. Set the winner's `served_cycle = cycle`.

Step 3 must be judged against **eligible candidates only**, never against the whole pool.
The pool accumulates every player this character has ever raided with, so a cycle judged
against the pool would never complete.

Absent players need no special case at all: their `served_cycle` simply stops advancing
while everybody else's climbs, so the moment they become an eligible candidate they hold
the lowest number and win step 4 outright. Missing three cycles keeps them three cycles
ahead of the queue.

### Worked example

Fresh character, `cycle = 1`, empty pool. Group is A B C D; **D is outside the instance**,
so `GetMasterLootCandidate` never lists D. First roster update seeds all four at
`served_cycle = 1`.

| Event | Eligible | `served_cycle` before | Step 3 | Winner |
|---|---|---|---|---|
| Drop 1 | A B C | A1 B1 C1 (D1) | all == cycle 1 -> **cycle = 2** | random of A B C -> **B** (B=2) |
| Drop 2 | A B C | A1 B2 C1 | min 1 < 2 | random of A C -> **C** (C=2) |
| Drop 3 | A B C | A1 B2 C2 | min 1 < 2 | **A**, only one at min, no roll (A=2) |
| Drop 4, D still out | A B C | A2 B2 C2 (D1) | all == cycle 2 -> **cycle = 3** | random of A B C; D still owed at 1 |
| Drop 4', D walks in | A B C **D** | A2 B2 C2 **D1** | min 1 < 2, no reset needed | **D** (D=2) |
| E joins during cycle 2 | -- | E seeded at 2 | -- | E waits for cycle 3 |

## 4. Data model

Per character. `main.lua` already builds its `db()` helper over `RollForCharDb`
(`main.lua:180`), so the round-robin db is per-character for free, the same as
`autoloot_db`.

```lua
-- db( "autorobin_db" )
{
  cycle = 2,
  pool = {
    [ "Psikutas" ] = 2,
    [ "Obszczymucha" ] = 1,   -- owed: never served in cycle 2
  },
  ids = { ... },              -- selection tree, identical shape to autoloot_db.ids
  point = { ... },            -- window position, written by the frame
}
```

`ids` is seeded and reconciled by `AutoRoundRobinDb.ensure_seeded` exactly as
`AutoLootDb.ensure_seeded` does for auto-loot: catalogue additions appear disabled, existing
`enabled` flags are never touched, entries dropped from the catalogue are left alone.

Names are stored bare, as `GetMasterLootCandidate` and `GetRaidRosterInfo` return them.
No realm qualification -- consistent with the rest of the addon.

## 5. Catalogue -- `AutoRoundRobinDb`

Same three-level `Dungeon -> Boss -> items` shape as `AutoLootDb.ids`, so the tree, the
seeding logic and the GUI transfer unchanged. Initial contents: two raids, one node each.

```lua
local ids = {
  [ "Mount Hyjal" ] = {
    order = 1,
    bosses = {
      [ "Gems" ] = {
        order = 1,
        items = {
          [ 32227 ] = { quality = 4, icon = 133238, name = "Crimson Spinel" },
          [ 32228 ] = { quality = 4, icon = 133244, name = "Empyrean Sapphire" },
          [ 32229 ] = { quality = 4, icon = 133248, name = "Lionseye" },
          [ 32230 ] = { quality = 4, icon = 133265, name = "Shadowsong Amethyst" },
          [ 32231 ] = { quality = 4, icon = 133260, name = "Pyrestone" },
          [ 32249 ] = { quality = 4, icon = 133263, name = "Seaspray Emerald" },
        }
      },
    }
  },
  [ "Black Temple" ] = {
    order = 2,
    bosses = {
      [ "Gems" ] = { order = 1, items = { ...the same six... } }
    }
  },
}
```

The ids/icons are lifted from the entries already verified in `AutoLootDb.lua` (Black Temple
Trash, `AutoLootDb.lua:952-957`), not re-derived, so they need no live `GetItemInfo` fetch.
The same six ids appear under both raids; that is fine and already normal for this data --
`AutoLootDb.is_enabled` matches on item id and counts an item as soon as any one occurrence
of it is enabled.

`"Gems"` is not a boss. It joins `"Trash"` and `"Patterns"` in the non-boss set so the tree
greys the row out the way it already does for those. Rather than extending
`AutoLootDb.non_bosses` (which `find_boss` and `BossKilled` read, and which should keep
answering questions about the auto-loot catalogue only), each catalogue exposes its own
`non_bosses` and the generalized tree takes it as a parameter.

## 6. Award flow

Hooked into the same loot-opened path as auto-loot. `LootFacadeListener` already calls
`auto_loot.on_loot_opened`; the round-robin pass runs immediately after it, in a new
`AutoRoundRobin` module, and bails unless **all** of:

- `player_info.is_master_looter()`
- `config.auto_round_robin()`
- shift is not held (`m.is_shift_key_down()`), matching auto-loot's manual-override escape

For each slot in `loot_list.get_items_by_slot()` with an item id enabled in the round-robin
selection:

1. **Skip it if auto-loot already claims it.** Conflicts resolve in auto-loot's favour: if
   the item is enabled in both trees, or auto-loot would take it under its own quality/bind
   rules, round robin does not touch it. Concretely, skip when
   `auto_loot.is_auto_looted( item )` returns true. This keeps the two features from both
   firing on one slot and makes the precedence rule a single call rather than a duplicated
   copy of auto-loot's conditions.
2. Run the selection algorithm (section 3) against that slot's candidates.
3. `GiveMasterLoot( slot, index )` where `index` is the winner's candidate index from that
   same enumeration -- reuse `master_loot_candidates.get_index( slot, name )`.
4. Commit `pool[ winner ] = cycle` **only after** the `GiveMasterLoot` call.
5. Announce and record (section 7).

Iterating by slot rather than by item id is deliberate and matches auto-loot's comment:
two of the same gem in one window are two separate awards to two different players, and
`loot_list.get_slot()` would collapse them.

### 7. Announce and record

- Group announcement via `chat.announce`: `"<Name> receives <link> (round robin)."`
- Recorded through the existing `LootAwardCallback.on_loot_awarded( item_id, item_link,
  player_name, player_class, 1 )`, which writes `AwardedLoot`, notifies `RollController`
  and untracks the winner in `WinnerTracker` -- the same path master-loot awards take, so
  round-robin items show up in loot history like everything else.

Both are gated on the feature being on; there is no separate "messages" toggle in the first
version (auto-loot's three toggles exist for historical reasons and are not worth cloning).

## 8. GUI

### 8.1 The item tree -- generalize, do not copy

`AutoLootTree`'s useful surface is already almost all pure functions over nodes --
`is_leaf_enabled`, `all_checked`, `set_checked`, `visible_rows` take a node or a node list
and touch no module state. Only `M.dungeons` (a module-level singleton) and `M.init( db )`
are instance state, and `AutoLootFrame` hardcodes four things: `m.AutoLootTree.dungeons`,
the frame name `"RollForAutoLootFrame"`, the title, and `m.AutoLootDb.make_link`.

Changes:

- `AutoLootTree.build( db, non_bosses )` returns a roots array instead of assigning
  `M.dungeons`. `M.init( db )` stays as a thin wrapper (`M.dungeons = M.build( db,
  m.AutoLootDb.non_bosses )`) so `main.lua:538` and the existing tests keep working
  unchanged. The pure functions are untouched, so `test/AutoLootTree_test.lua` needs no
  edits.
- `AutoLootFrame.new` gains a config table: `{ popup_builder, content_transformer, db,
  name, title, roots, make_link }`. Both features instantiate it. The auto-loot call site
  passes exactly what is hardcoded today, so its behaviour is byte-for-byte identical.
- `AutoLootFrameContentTransformer` is already generic and is reused as-is.

If the two windows are ever meant to diverge visually, that is the moment to split them --
not now.

The round-robin window is titled `"RollFor Auto Round Robin"`, named
`"RollForAutoRoundRobinFrame"`, and remembers its own position in `db( "autorobin_frame" )`.
Everything else -- tri-state check cascade, desaturation, scrolling, item tooltips -- comes
along for free.

### 8.2 The queue window

A second button, `Queue`, sits next to `Close` on the round-robin window and toggles a
separate list window (`"RollForAutoRoundRobinQueueFrame"`, position in
`db( "autorobin_queue_frame" )`). It is built on `ListPopup`, the shell the resistance
windows already share, plus a new `GuiElements.round_robin_row` modelled on
`eligibility_row`.

Rows, ordered by `served_cycle` ascending then name, showing only players currently in the
group -- the pool keeps everyone forever, but the window is a display, not the record. This
is exactly the split `ResistanceBonusRollFrame` already documents against its registry.

| Column | Content |
|---|---|
| Player | name, class-coloured |
| Status | `Waiting` (`served_cycle < cycle`), `Received` (`== cycle`), or `Owed (n cycles)` when more than one behind |
| Eligible | dimmed marker when the player is in the group but not a master-loot candidate right now |

Buttons: `Reset` (with a `ConfirmationDialog`, since it throws away the rotation) and
`Close`. Reset clears `pool` and sets `cycle = 1`; the next roster update reseeds everyone
present.

The queue window refreshes on `GROUP_ROSTER_UPDATE` (`refresh_if_visible`, as the
resistance windows do) and after every award.

## 9. Commands and config

| Command | Effect |
|---|---|
| `/rf autorobin` | toggles the selection window |
| `/rf autorobin queue` | toggles the queue window |
| `/rf autorobin reset` | clears the pool and resets the cycle, same as the GUI button |
| `/rf config auto-round-robin` | toggles the feature |

Dispatch goes next to the existing `^autoloot` branch in `main.lua` (~line 634). `autorobin`
and `autoloot` do not prefix-collide so their relative order is free, but `^autorobin queue`
and `^autorobin reset` must both be matched before the bare `^autorobin`. All three are
usable outside a group -- they are window and state commands, so they must sit **above** the
`IsInGroup()` guard at line ~665.

Config: `[ "auto_round_robin" ] = { cmd = "auto-round-robin", display = "Auto round-robin",
help = "toggle auto round-robin" }`, defaulting to **false** in `Config.init` (this awards
loot on its own; it must be opted into deliberately), plus `add_toggle( settings,
"auto_round_robin" )` in `OptionsFrame.lua` next to `auto_raid_roll`.

## 10. Files

New:

- `src/AutoRoundRobinDb.lua` -- catalogue + `ensure_seeded` / `is_enabled` /
  `has_enabled_items` / `non_bosses` / `make_link`. Mostly a narrower `AutoLootDb`; the
  seeding and query functions are close enough that they should be lifted into a shared
  helper rather than pasted, with `AutoLootDb` keeping the fetch tooling and `find_boss`
  that only it needs.
- `src/AutoRoundRobin.lua` -- the pool, the cycle, the selection algorithm, the award pass.
- `src/AutoRoundRobinFrame.lua` -- thin: builds the tree roots and delegates to the
  generalized `AutoLootFrame`, plus the `Queue` button wiring.
- `src/AutoRoundRobinQueueFrame.lua` + `src/AutoRoundRobinQueueFrameContentTransformer.lua`
  -- the `ListPopup` window from 8.2.
- `src/AutoRoundRobinSimulator.lua` -- not in this spec; added afterwards. A `/rfrotate` dev
  harness in the `/rfdrop` mould: it runs the shipped `seed` / `select` / `commit` over an
  invented roster and traces each drop, so the rotation, a turnover and what an absence costs
  can be watched solo. It never touches the live rotation -- `/rfrotate raid` with no arguments
  copies the live cycle and pool in, and even that is a copy. `/rfrotate example` replays the
  worked example in section 3, which keeps that table honest.

Modified:

- `RollFor.toc` -- register the new files (`AutoRoundRobinDb` before `AutoLootTree`, the
  frames after `ListPopup`).
- `src/AutoLootTree.lua` -- add `build`, keep `init`.
- `src/AutoLootFrame.lua` -- take name/title/roots/make_link as parameters.
- `src/GuiElements.lua` -- add `round_robin_row`.
- `src/Config.lua`, `src/OptionsFrame.lua` -- the new toggle.
- `src/LootFacadeListener.lua` -- run the round-robin pass after auto-loot.
- `main.lua` -- construct everything, wire `on_group_changed` to the pool sync, add the
  slash commands.

## 11. Edge cases

- **Nobody eligible.** `GetMasterLootCandidate` returns nothing for the slot (can happen
  transiently). Skip the slot silently and leave the state alone; the next loot window
  retries.
- **Item below the master loot threshold** is not master-lootable at all -- `GiveMasterLoot`
  will not work. All six gems are epic so this cannot bite the shipping catalogue, but the
  pass should skip anything under `GetLootThreshold()` rather than fail silently.
- **Not master looter / group loot.** Feature is inert. No warning spam; the window still
  opens so the list can be edited out of raid.
- **Two copies of one item in a window.** Two awards, two different winners, cycle
  advancing between them. Falls out of the per-slot loop.
- **Same name, different player** (server transfers, name reuse) -- accepted. The pool is
  keyed by bare name like the rest of the addon; `Reset` is the answer.
- **Pool growth.** One number per name; a heavy raider might accumulate a few hundred
  entries over a year. Irrelevant for both memory and the linear scans, which only ever run
  over the candidate list, not the pool.
- **`RollFor` reload mid-cycle.** State is in SavedVariables, so the cycle survives. The
  roster sync on the next update re-adds anybody missing at the current cycle.

## 12. Tests

Follow the existing `test/AutoLootTree_test.lua` and `test/AutoLootSpec_test.lua` patterns.

Pure selection logic (no WoW API needed, the valuable half):

- seeding puts unknown players at the current cycle
- a known player rejoining is not reseeded and keeps their number
- the winner is always drawn from the lowest `served_cycle` among candidates
- a sole player at the minimum wins without a random draw
- all candidates at the current cycle advances the cycle exactly once
- an absent player is skipped while absent, then wins outright on return, across more than
  one cycle
- cycle completion ignores pool members who are not candidates
- reset empties the pool and returns the cycle to 1

Integration (via `IntegrationTestBuilder`, which already knows how to express an enabled
auto-loot selection -- see its comment at line 138):

- an enabled gem in a loot window is awarded, announced, and recorded
- an item enabled in both trees goes to auto-loot, and the round-robin cycle does not move
- the feature toggled off awards nothing

## 13. Deferred

- No per-item or per-category rotations: one pool, one cycle, all items share it. If
  separate rotations per item type are wanted later, `pool` becomes a table of pools keyed
  by category and nothing else in this design changes.
- No manual override of the next recipient from the queue window.
- No sharing of the rotation between raid members over the addon channel; each master
  looter's copy is its own.
