# Bringing master's work onto this branch

Status: **task 1 done.** This document is the plan. Read it before touching a file.

## What this is

`master` is 21 commits ahead of this branch with work that predates and ignores the
soft-res extraction (`SR-EXTENSION.md`). This branch is the one that keeps its history.
Master's features come across as **new commits written here**, not as a merge and not as
cherry-picks: the two sides disagree about what `main.lua` is, and a merge would produce a
resolution nobody reviewed. After this is done, master gets cleaned up and force-pushed to
match.

So: read master's version of a feature, understand it, and write it here in the shape this
branch has. Where the two agree, the diff should be a straight copy. Where they disagree,
this branch wins, because it is the one that knows soft-res is an extension.

## Rules

1. **One feature per commit.** They land independently and each has to leave all three
   suites green -- core, RollForSoftResIt, RollForNetherVortex.
2. **Task 1 first, and on its own.** Everything after it is smaller once resistances are
   out, and porting anything on top of code you are about to delete is wasted work.
3. **Don't port a test into core that needs soft-res filtering.** §9.1 of
   `SR-EXTENSION.md` still decides where a test lives. Core's suite runs against the dumb
   double now; if a ported spec needs real filtering it belongs in RollForSoftResIt.
4. **`./test.sh` in all three repos after each task**, not at the end. The two extension
   suites run against the sibling `../RollFor` in the addons tree, so core changes have to
   be synced there before their results mean anything (`SR-EXTENSION.md` trap 12).
   `sync-bcc.sh` needs `rsync`; without it, copy the changed files by hand and confirm
   with `diff -rq`.
5. Master's commit hashes are quoted for reading, not for cherry-picking. Nothing in this
   plan runs `git cherry-pick` or `git merge`.
6. **A task that spans repos lands in both at once.** Task 1 and Task 7 both do. Leaving
   one side for later means a red suite in a repo nobody is looking at.
7. **Line numbers in this document are from the branch as of writing** and drift as tasks
   land. They locate things; the names next to them are what to trust.

---

## Task 1 -- Rip out resistances *(done)*

**Decision: gone completely.** Not just master's new resistance work -- everything already
on this branch goes too. This is the largest deletion in the plan and it unblocks the rest.

### Delete

`RollFor/src/resistances/` entirely (14 files: `Inspector`, `BuffScanner`,
`ResistanceRegistry`, `ResistanceParser`, `GearScanner`, `ResistanceCheck`,
`ResistanceBonusRollEligibility`, `ResistanceBonusRollRegistry`, the three
`...ContentTransformer`s, `ResistanceBonusRollFrame`,
`ResistanceBonusRollEligibilityFrame`, `ResistanceFrame`), and
`RollFor/src/SoftResBonusRollDecorator.lua` with them.

`RollFor.toc` lines 93-106 plus the `SoftResBonusRollDecorator` entry.

`test/resistances/` (11 suites), `test/BonusRowContract_test.lua`,
`test/BonusRollSpec_test.lua`.

### Unpick from `main.lua`

- `describe_lockout_loss()` (~line 142): drop the `bonus roll` and `eligible player`
  entries, keep the boss kills one and the extension hook loop.
- The construction block ~322-357: `inspector` (~323), `gear_scanner` (~326),
  `buff_scanner` (~329), `resistance_registry` (~332), `resistance_parser` (~335),
  `resistance_check` (~338), `resistance_bonus_roll_eligibility` (~342),
  `resistance_bonus_roll_registry` (~356). The three scanners have no other consumer --
  `gear_scanner` and `buff_scanner` feed `resistance_check` alone, and `inspector` feeds
  `gear_scanner` alone.
- **`tooltip_reader` (~320) stays.** `LootList` takes it (~415) to read slot bind types.
  Its only other callers were the two scanners. Delete it and loot listing breaks, which
  no resistance spec would catch. `src/TooltipReader.lua` and its TOC entry stay too.
- `src/EventFrame.lua` **stays**: `LootFacade` (~404) and `RaidLockout` (~421) build one
  each, so it outlives `Inspector` (~323). It is the clearest example of the rule for this
  task -- delete what resistances own, not what they merely used.
- The `bonus_roll` chain link (~374-381) **and its `softres_chain.has( "present_players" )`
  guard**. That guard exists only to place this link; with it gone, core contributes
  nothing to the soft-res chain at all, which is worth noticing -- the chain becomes
  entirely the source extension's.
- The frames ~632-654 and their `on_group_changed` calls ~1067-1069.
- `/rfreset`'s `resistance_bonus_roll_registry.reset()` and
  `resistance_bonus_roll_eligibility.reset()` (~696).

### Unpick elsewhere

- `Config.lua`: `resistance_bonus_rolls_enabled`, `resistance_check_throttle` and its
  getter/setter/printer, the `bonus-rolls` command entry, the help line, and the two
  fields on the returned table.
- `Types.lua`: `RollType.BonusRoll` and its `---|` alias line.
- `SoftResRollingLogic.lua` (~175) and `TieRollingLogic.lua` (~145-147): the
  `roll_type_used == RT.BonusRoll` branches and `spend_bonus_roll`.
- `GuiElements.lua` (~50, ~58, ~73): the gold colouring and the bonus-roll cell handling.
- `RollingLogicUtils.lua`: the `{ field = "bonus_rolls", roll_type = RT.BonusRoll }` entry
  in the roll-type table (~23), the `bonus_rolls` argument threaded through
  `make_rolling_player` (~64), and `spend_bonus_roll` (~328). This is the deepest of the
  edits -- `bonus_rolls` rides along on every rolling player.
- `RollingStrategyFactory.lua`: `bonus_roll_registry` threaded into two rolling-logic
  constructions (~49, ~154) and the comment at ~109 about `SoftResBonusRollDecorator`
  having already annotated each player's allowance.
- `OptionsFrame.lua` (~218): the `add_toggle( settings, "resistance_bonus_rolls_enabled" )`
  line.
- `ListPopup.lua`: **comments only** -- the header calls it "the shell the resistance-style
  list windows are all built out of" (~9) and the `row_type` annotation gives
  `"resistance_row"` as its example (~46). No code to remove. Reword both; do not delete
  anything in this file.
- `test/utils.lua`, `test/gui_helpers.lua`, `test/IntegrationTestBuilder.lua`: the
  `bonus_rolls` builder method, the bonus row helpers, the inert registry collaborators
  (~26), the `resistance_bonus_rolls_enabled` config stub (~100) and the bonus-roll
  decorator that sits outermost in the ITB's chain (~107). `HowToRoll_test`, `generic_test`, `OptionsFrameSpec_test`,
  `mainspec_rolls_test`, `tie_rolls_test`, `both_spec_rolls_test`, `RaidRoll_test`,
  `InstaRaidRoll_test` and `SoftResSourcePrecedence_test` all mention one or the other --
  most are a line or two.

### Both extension repos, in the same landing

This is the part that will be missed. Bonus rolls are core's, but the extraction left
their traces on the other side:

- `RollForSoftResIt/test/SoftResBonusRollDecorator_test.lua` -- a migrated suite testing a
  core module that no longer exists. **Delete it.**
- `RollForSoftResIt/test/IntegrationTestBuilder.lua` and
  `RollForNetherVortex/test/IntegrationTestBuilder.lua` -- both build
  `SoftResBonusRollDecorator` and a `ResistanceBonusRollRegistry` into their chains. Both
  vendored harnesses need the link and the require removed.
- `RollForSoftResIt/src/Simulation.lua` -- §6.6's known wart re-wraps the simulation
  stand-in in `RollFor.SoftResBonusRollDecorator` behind an `if`. The guard now never
  fires; delete the branch and the comment pointing at `EXTENSIONS_POC.md` §6.
- `test/mocks/ResistanceFrame.lua` and `test/mocks/ResistanceBonusRollFrame.lua` in **both**
  vendored harnesses, plus their entries in each `utils.lua` load list.
- `gui_helpers.lua` in both: the bonus-roll row helpers.
- `RollForSoftResIt/test/FullLoad_test.lua` -- `ChainSpec` is named
  `should_own_the_backbone_with_cores_bonus_roll_on_top` (~50) and asserts exactly that
  shape. With the link gone the backbone is the whole chain: rename the spec and drop
  `bonus_roll` from the expected order. `ExtensionRegistration_test.lua` does **not**
  mention bonus rolls -- leave it alone.
- `RollForNetherVortex/test/SoftResNetherVortexDecorator_test.lua` -- eight expected roller
  tables carry `bonus_rolls = 0` (~30, 31, 47, 77, 107, 123, 140, 148). That field was put
  there by core's decorator; with it gone the field is absent, so remove it from all eight.

### Acceptance

All three suites green. In game: rolling, ties, the rolling popup, `/rf` options and
`/rfreset` all work with no bonus-roll row, no resistance window, and no
`resistance-check-throttle` command.

---

## Task 2 -- `warn()`

Master `7ea3e16`. Four lines in `src/modules.lua`, one TOC version bump. Port as-is; later
tasks use it.

---

## Task 3 -- Auto-loot table changes

Master `7e20e92` (MH patterns) and `bba0311` (Mark of the Illidari removed because it
clashes with auto robin).

`src/AutoLootDb.lua`, `src/AutoLootTree.lua`, `src/DropSimulator.lua`, and `bba0311`'s
14 lines in `main.lua`. Catalogue data plus a small tree change -- no soft-res contact.
Port as-is.

**Note:** `bba0311` exists because of auto robin. It is harmless without it, so port it
here rather than making Task 7 depend on it.

---

## Task 4 -- FrameBuilder viewport and scrolling

Master `67a7a1c`. `src/FrameBuilder.lua` (+209), `src/PopupBuilder.lua`,
`src/AutoLootFrame.lua`, `test/FrameBuilderScroll_test.lua` (new, 149 lines), and the
`FrameBuilder`/`PopupBuilder` mocks.

Port as-is. **Both vendored harnesses have their own copies of those two mocks** -- update
them in the same landing or the extension suites break on the new methods.

---

## Task 5 -- Db events and migrations

Master `758c198` (Db restructure for events) and `97fbade` (DB migrations).

Both commits touch `src/Db.lua`. `758c198` adds the watch/notify support -- a reserved
`watch` field on every proxy, handing back an accessor whose `update` mutates and notifies
in one go. `97fbade` adds migrations on top: a `version` field in each module's store, a
`base_version` of 1 that is never written down, and an ordered `DbMigration[]` list passed
as `db()`'s second argument, each entry moving a store up exactly one version.
`test/Db_test.lua` is new (177 lines).

Task 7 depends on both -- `AutoRoundRobin` is built on `db.watch( "queues" )` and ships a
`queues = nil` migration.

**The thing to check:** `RollForSoftResIt` does its own one-time SavedVariables copy in
`on_enable` (`§5.7`), which assumes `RollForCharDb` is fully populated by then --
`setup_storage()` runs before `create_components()`, which is what makes it safe today. If
migrations change when or how tables materialise, re-check that ordering and
`Migration_test` with it.

`97fbade` also touches `AutoLootDb`, `AutoLootTree` and the auto robin files. Take here:
`Db.lua` in full, `test/Db_test.lua`, and `main.lua`'s
`make_link = m.AutoLootDb.make_link` -> `m.ItemUtils.make_link` fix (~616). Leave for Task
7: the `autorobin_db` migration list (~442), the `new_group_event` transient sweep (~677),
and every `AutoRoundRobin*` file. `AutoLootDb`/`AutoLootTree` changes in that commit are
auto-loot's -- port them in Task 3 if they are not already covered by `7e20e92`.

---

## Task 6 -- SoftRes limit check

Master `6462f95` and `daa743e`.

Black Temple's soft-res budget: 3 for the raid, a 4th only if it lands on Mother Shahraz,
the Illidari Council or Illidan. Everything else spends from the 3.

**`SoftResLimitCheck.lua` stays in core.** `find_violations( softres )` calls `get_items()`
and `get( item_data )` and nothing else -- two of the six read methods, so it is an
ordinary consumer like `DroppedLootAnnounce`. It reads `m.AutoLootDb.find_boss`, which is
core's.

Split the rest by owner:

- **Core:** the module, `test/SoftResLimitCheck_test.lua` (133 lines), the purple icon
  asset, `MinimapButton`'s new `ColorType`, and `modules.lua`'s colour entry.
- **Core, but re-sited:** `daa743e` registers the minimap contribution inside the built-in
  soft-res block, which no longer exists. Register it unconditionally in
  `create_components()`, reading `M.softres`. With no source installed that is the null
  object, so it finds no items and contributes nothing -- correct, and it must be verified
  rather than assumed.
- **RollForSoftResIt:** `6462f95` and `daa743e` both patch `src/SoftResCheck.lua`, which is
  the extension's file now. The limit check has to be reachable from there. Simplest seam
  that doesn't put soft-res knowledge back in core: the extension calls
  `RollFor.SoftResLimitCheck.find_violations( unfiltered )` itself, the same way it already
  reaches for `RollFor.Chain` and `RollFor.SoftRes`.

**Who prints, decided:** `find_violations` returns data and prints nothing. Every message
-- the `/src` lines and the minimap tooltip -- is written by the caller. `/src` is the
extension's command, so the extension formats and prints those; the minimap contribution is
core's, so core formats its own tooltip lines from the same return value. Neither side
prints on the other's behalf.

---

## Task 7 -- Auto Round Robin, as its own extension

**Decision: it never lands in core.** Master's version is wired straight into
`create_components()` and `LootFacadeListener`; here it becomes `RollForAutoRobin` in the
addons repo, alongside `RollFor`, `RollForSoftResIt` and `RollForNetherVortex`.

Master commits, in order: `2bc480f`, `c246ca5`, `31f6086`, `5d5c9ed`, `cbc60b2`,
`a56f560`, `350b1ed`, `7c60dea`, `18ef711`, `e702007`. Roughly 2,500 lines plus suites.
Read all of them before starting; the later ones substantially rewrite the earlier ones,
so port the *end state*, not the sequence.

### The blocker: no extension can hook the loot pipeline

Master inserts `auto_round_robin` into `LootFacadeListener.new`'s positional arguments and
calls it at two exact points:

```
LootOpened:       dropped_loot -> dropped_loot_announce -> auto_loot ->
                  auto_round_robin -> master_loot -> auto_group_loot -> roll_controller
LootSlotCleared:  master_loot -> auto_group_loot -> auto_round_robin
```

Both positions are load-bearing. It runs *after* `auto_loot` because it reads
`is_auto_looted` so an item ticked in both trees doesn't move the rotation, and *last* on
`LootSlotCleared` because that is its cue to hand out the next item.

So the first piece of work is a **core seam for ordered loot hooks**, and it has to express
"after auto_loot" rather than "sometime during LootOpened".

**Decided: reuse the vocabulary, not the machinery.** `Chain` is the wrong shape -- it
composes decorators, `factory( inner )` returning a wrapper, while the loot pipeline is an
ordered list of callbacks. But the *ordering* half of `Chain` is exactly right, and it is
already isolated in `position_for`, `unplaceable` and `resolve`. So:

**7a. Pin the current order.** A spec asserting the six `LootOpened` handlers fire in
today's order, and the two on `LootSlotCleared`. `LootFacadeListener` is 79 lines and every
loot event goes through it; nothing moves until that spec exists.

**7b. Extract placement from `Chain.lua` into `src/Ordering.lua`.** `place( entries )`,
where an entry has `name`, `after` and `before`, returning the ordered list plus the
unplaceable ones with their diagnostics. `Chain` keeps its composition and calls this.
Mechanical, and `Chain`'s 31 specs are the guard. `Chain.build`'s `{ report = false }`
option belongs to the caller, not to placement -- keep it in `Chain`.

**7c. `LootFacadeListener` becomes a named registry.** Core's handlers register themselves
rather than being positional arguments. The names and anchors, which must reproduce today's
order exactly:

```lua
-- LootOpened
{ name = "dropped_loot" }                                              -- dropped_loot.on_loot_opened()
{ name = "dropped_loot_announce", after = "dropped_loot" }             -- dropped_loot_announce.on_loot_opened()
{ name = "auto_loot",            after = "dropped_loot_announce" }     -- auto_loot.on_loot_opened()
{ name = "master_loot",          after = "auto_loot" }                 -- master_loot.on_loot_opened()
{ name = "auto_group_loot",      after = "master_loot" }               -- auto_group_loot.on_loot_opened()
{ name = "roll_controller",      after = "auto_group_loot" }           -- roll_controller.loot_opened()

-- LootSlotCleared
{ name = "master_loot" }                                               -- master_loot.on_loot_slot_cleared( slot )
{ name = "auto_group_loot",      after = "master_loot" }               -- auto_group_loot.on_loot_slot_cleared()
```

`LootClosed` (`roll_controller.loot_closed()`) and `ChatMsgLoot` (`on_chat_msg_loot`) have
one handler each. Give them the same treatment for consistency, or leave them as plain
subscriptions -- either is fine, but do not leave `LootOpened` half-converted.

Handlers are resolved once at construction, same as the soft-res chain. The `slot` argument
on `LootSlotCleared` and the message on `ChatMsgLoot` are passed through to every callback.

**7d. `ctx.on_loot( event, spec )`, and `API_VERSION = 3`.** Auto Robin then says what
master's argument position said implicitly:

```lua
ctx.on_loot( "LootOpened",      { name = "auto_robin", after = "auto_loot",       callback = ... } )
ctx.on_loot( "LootSlotCleared", { name = "auto_robin", after = "auto_group_loot", callback = ... } )
```

The alternative -- a narrower `ctx.on_loot_opened( cb, { after = "auto_loot" } )` -- costs
the same once the resolver is written, and leaves two `after`/`before` implementations to
keep in step. One vocabulary, one set of ordering bugs, one error message users have
already seen from the soft-res chain.

7a and 7b are independent of the port and leave the branch green on their own; they can
land before anything else here. Record the decision in `EXTENSIONS_POC.md` §6 when 7d
lands.

### What the extension needs from the context

`AutoRoundRobin.new` takes `loot_list, api, db, config, player_info, chat, group_roster,
master_loot_candidates, auto_loot, loot_award_callback`.

`ctx` already carries `api`, `db`, `config`, `chat`, `group_roster`, `player_info`,
`popup_builder`, `frame_builder`, `gui_elements`, and `ctx.get( name )` returns any built
component by name -- `loot_list`, `master_loot_candidates`, `auto_loot` and
`loot_award_callback` all come from `ctx.get` in `on_ready`. So the only genuinely missing
piece is the loot hook above. Bump `API_VERSION` to 3 when it lands.

### The rest of the port

- Files: `AutoRoundRobin`, `AutoRoundRobinDb`, `AutoRoundRobinFrame`,
  `AutoRoundRobinQueueFrame`, `AutoRoundRobinQueueFrameContentTransformer`,
  `AutoRoundRobinAddPlayerFrame`, `AutoRoundRobinSimulator`.
- Shares `AutoLootTree`, `AutoLootFrameContentTransformer` and `AutoLootDb` with core's
  auto-loot window. Those stay core's and the extension reads them off `RollFor`.
- The `config.auto_round_robin` setting and its options-window entry become the
  extension's, via `ctx.config` and its own options page.
- **`a56f560` needs a second seam, and it is not just config.** It adds two settings
  (`auto_round_robin_announce`, `auto_round_robin_announce_drops`, the second defaulting
  off) and gives `DroppedLootAnnounce.process_dropped_items` an `auto_round_robin`
  parameter so its filter can drop items the rotation is about to hand out. The settings
  are auto robin's and move to the extension. The filter cannot: core must ask "is this
  item the rotation's?" and with auto robin in another addon it has nothing to ask.

  So core needs a way for an extension to suppress an item from the drop announcement --
  a registered predicate, e.g. `ctx.on_dropped_item( fn )` where returning `false`
  withholds the item, with core calling every registered predicate from
  `process_dropped_items`. The extension registers one that answers from its own two
  settings. Design it with 7d; it is the same kind of seam and should read like it.

  `DroppedLootAnnounce`'s suites live in RollForSoftResIt now, so the specs for the
  predicate mechanism are core's and the specs for the rotation's answer are the
  extension's.
- **The published surface for display addons moves as-is, names unchanged.** Master has
  two pieces of it: `broadcast_round_robin_update` fires the WeakAuras event
  `ROLLFOR_ROUND_ROBIN_QUEUE_UPDATE` with the category, via
  `WeakAuras.ScanEvents`; and a global `RollForApi` table exposing
  `round_robin.categories/is_active/queue`. Both become the extension's. **Keep both names
  exactly** -- the event name is what other people's auras subscribe to, and `RollForApi`
  is deliberately a separate global from `RollFor` precisely so it can survive this kind
  of move. Renaming either breaks strangers' auras silently.
- Vendor a test harness the way the other two extensions do (`§5.8`), and move
  `AutoRoundRobinSimulator_test`, `AutoRoundRobinSpec_test`, `AutoRoundRobin_test`,
  `AutoRoundRobinQueueFrameSpec_test` into it.

### `cbc60b2`'s PreviewSpec addition stays in core

The Trash Ignore spec (78 lines) proves a soft-ressed recipe is left to the rollers instead
of being master-looted by the rotation. It needs soft-res *data*, not filtering, so it
passes against core's dumb double and belongs in core's `PreviewSpec_test.lua` -- but it
drives the extension's feature, so it only makes sense once Task 7 lands. Port it last,
with the extension installed in the test harness.

Its ITB additions (`qi`, `round_robin_list`, `auto_round_robin` deps) conflict textually
with this branch's rewritten `group_aware_softres`. Different regions of the same file;
resolve toward this branch's version of the chain.

---

## Dropped on purpose

- **`441355c` Announce resistances** and **`cc6ce37` `/rfres <player>`** -- resistances are
  being deleted, not ported. See Task 1.
- **`4a4d0be` Remove 1.12 client support** -- already in this branch's history, same
  commit.

---

## After all of it

- Bump `RollFor.toc`'s version, and the extensions' TOCs if they changed.
- `release.sh` still ships core only. `SR-EXTENSION.md` §12 records the decision not to
  bundle the source extension; a second extension makes that question louder, not
  different.
- Update `EXTENSIONS_POC.md` §6 with the loot-hook decision and the API version bump.

## Open questions

1. **Does anything else want `SoftResLimitCheck`?** It is Black Temple-specific and hard
   coded. If raidres or a second source wants different limits it becomes source data, not
   a core module -- worth knowing before it grows a second caller.
