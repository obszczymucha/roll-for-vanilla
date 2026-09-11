# The loot pipeline: phases, claims, and policy order

Goal: core stops naming other people's features. Today `LootFacadeListener`
declares a position called `auto_loot` -- an extension's name, in core, held open
so three unrelated handlers can anchor to it. That is the symptom. The cause is
that handler *identity* is being used as the schedule *coordinate*: `name`
answers "who am I" and everyone else's `after` uses it to answer "when do I run".
When a handler's owner moves out of core, the coordinate leaves with it, which is
why the placeholder machinery exists at all.

This document replaces that with three separate mechanisms, each answering one
question:

- **Phases** -- when does a handler run. Core's, because core owns the pipeline.
- **Claims** -- who got this item. Synchronous, so "ran first" means something.
- **Policy order** -- which automatic claimant outranks which. The user's.

Written to be implemented in order. Each phase leaves the tree green, so stopping
after any of them is a valid outcome.

## Decisions already taken

Do not re-litigate these.

1. **Four phases, not six positions.** `Loot`, `PostLoot`, `Award`, `PostAward`.
   The old `POSITIONS` list was component names one for one (`main.lua:597-601`
   passes exactly those five as the components table), which is why `auto_loot`
   looked like a category error in it -- it was the one whose component left.
2. **`sweep` and `assign` are not different phases.** `AutoLoot.lua:90`,
   `AutoRoundRobin.lua` and `MasterLoot.lua:79` all call `GiveMasterLoot( slot,
   index )`. Same operation; only the recipient and the rule choosing them
   differ. They are competing *policies* inside one `Award` phase, and ranking
   them is exactly what phases cannot do.
3. **Core performs the award.** A policy's `decide` returns a player name; core
   resolves the candidate index, calls `GiveMasterLoot`, and records the claim.
4. **The award loop re-runs on `LOOT_SLOT_CLEARED`.** `AutoRoundRobin.lua:446`
   records that the client silently refuses every award after the first in one
   pass; `AutoLoot.lua:82-98` loops and assumes they all land. Running the loop
   over every slot *and* again on each `LOOT_SLOT_CLEARED` produces the same
   outcome -- one loot open, everything assigned -- whichever is true, so the
   disagreement does not have to be settled first.
5. **Priority is the user's, not core's.** Core holds an ordered list of the
   policies that *registered*. It never declares one. That is the whole
   difference from `POSITIONS`: core learns the set instead of naming it.
6. **The priority list is a new settings line type**, alongside
   `boolean`/`number`/`choice` in `OptionsFrameContentTransformer`.
7. **Clean break at `Extensions.API_VERSION` 6.** Only three extensions touch the
   pipeline -- `RollForAutoLoot`, `RollForAutoRobin`, `RollForPendingLoot`. The
   other five register no `on_loot` and are unaffected.
8. **`Ordering` is not changed.** It still places siblings within a phase, and it
   still places the soft-res chain.
9. **Core ships a default policy order** naming the policies it distributes with
   itself, seeding the first run only. Absent names are ignored and nothing
   anchors to it, which is what separates a seed from the load-bearing
   `POSITIONS` it replaces. Saved order, per-character, wins thereafter.
10. **`RollForAutoLoot.claims` is deleted outright**, with no deprecation shim.

## The phases

```lua
local PHASES = {
  LootOpened      = { "Loot", "PostLoot", "Award", "PostAward" },
  LootSlotCleared = { "Loot", "Award", "PostAward" },
  LootClosed      = { "PostAward" },
  ChatMsgLoot     = { "Loot" }
}
```

- `Loot` -- react to the event, change nothing in the corpse. `dropped_loot`,
  `pending_loot`.
- `PostLoot` -- the loot event has settled, nothing has been handed out yet.
  `dropped_loot_announce`.
- `Award` -- hand items out. The policy list runs here; whatever no policy claims
  falls through to core's `master_loot` and `roll_controller`.
- `PostAward` -- housekeeping once awards have landed or been abandoned.
  `auto_group_loot`, which is not an award at all (`AutoGroupLoot.lua:46` calls
  `set_loot_method( "group" )` when the item count reaches zero);
  `master_loot.on_loot_slot_cleared`, which confirms an award landed and fires
  `on_loot_awarded` (`MasterLoot.lua:41-53`); and `roll_controller.loot_closed`,
  which aborts an in-flight confirmation (`RollController.lua:1471`).

A handler's phase is per event, not per component. `roll_controller` is `Award` on
`LootOpened` -- the fallback that starts a roll for what nobody claimed -- and
`PostAward` on `LootClosed`, where it is tearing an abandoned award down. Reading
a component's phase off one event and assuming it holds on the others is the
mistake this table is easiest to get wrong in.

Two sibling constraints survive into phases and must be kept:
`pending_loot` before `master_loot` on `LootSlotCleared` (`RollForPendingLoot.lua:72`
explains why: a master looter's assignment clears the slot *and* is an award, so
running after it would add an item nothing ever removes) -- satisfied by `Loot`
preceding `PostAward`. And `pending_loot` after `roll_controller` on `LootClosed`,
which is now a sibling anchor inside `PostAward`.

The names say *when*, not *what*. That is deliberate and it is the same lesson as
`auto_loot` one level up: `observe`/`announce`/`cleanup` were considered and
rejected, because a handler that does not announce has no home in a phase called
`announce`, and the next stage anyone needs would be a freshly invented noun whose
position you cannot derive from its name. `PreLoot` sorts itself.

**`PreAward` is deliberately absent.** It and `PostLoot` are the same slot -- "after
the loot event settled, before anything is handed out" -- and shipping both leaves
nothing to tell a handler which to pick, which is the semantic judgement this
scheme exists to remove. `PostLoot` already is `PreAward`.

Room costs nothing now: a declared-but-empty phase is harmless, because nothing
anchors to a phase's *occupant* -- that was the whole fix. So `PreLoot` is added as
a one-line change to `PHASES` on the day something needs it, not shipped
speculatively.

A phase is not a handler, so it cannot be vacant and nothing can fall out of the
chain because a coordinate went missing. `before`/`after` survive as **sibling
ordering within a phase**, with one change that makes the placeholders
unnecessary: **an unsatisfied sibling constraint is vacuously true, not fatal.**
`before = "master_loot"` with no `master_loot` registered means "no constraint",
because the phase already pins the coarse position.

Phase names are PascalCase like the events they subdivide (`LootOpened`,
`LootSlotCleared`), and unlike handler names, which stay snake_case
(`dropped_loot`, `master_loot`). A phase is core's structure; a handler name is
whoever registered it.

---

## Phase 1 -- Core's handlers leave the dispatcher

**Why.** `LootFacadeListener` currently holds four jobs: the mechanism, core's
client list (`register_core`, :176-225), actual business logic (the `ChatMsgLoot`
handler at :203-224 parses loot messages with `gmatch` and builds item links),
and a schedule that restates the anchors (`POSITIONS` at :52 duplicates the
`after =` chain in `register_core`; edit one and the other silently disagrees).
Nothing below is legible until they are separated.

**Change.**

- Move the `ChatMsgLoot` parsing into `MasterLoot` as `on_chat_msg_loot(
  message )`, leaving a one-line callback like every other handler.
- Move `register_core` out of `LootFacadeListener` into `main.lua` (or a
  `CoreLootHandlers.lua`), registering through the same `on_loot` extensions use.
  `main.lua:596` stops calling a method that knows five component names.
- `LootFacadeListener` now knows no clients.

**No contract change.** Anchors still work, `POSITIONS` still stands.

**Tests.** `LootFacadeListenerOrder_test.lua` must produce identical orders
before and after. A new `MasterLoot` case for the two `gmatch` branches -- "%s
receives loot:" and "You receive loot:" -- which currently have no direct test
because they live inside the dispatcher.

---

## Phase 2 -- Phases alongside anchors

**Why.** Transitional, so the tree stays green while extensions still anchor.

**Change.**

- Add `PHASES`; `on_loot` accepts `phase`.
- Resolution: group handlers by phase in declared phase order, then `Ordering.place`
  within each group.
- Sibling constraints naming something absent are dropped rather than fatal.
- A handler with neither `phase` nor an anchor is a hard error, as now.
- Keep `POSITIONS` and `with_vacant_positions` working for handlers that still
  anchor.
- `---@class LootHandler` gains `---@field phase string?`, and `ExtensionContext`'s
  `on_loot` doc comment (`Extensions.lua:72`) stops saying "by name". `order( event )`
  stays on the `LootFacadeListener` class and keeps returning handler names in
  resolved order -- the ordering tests call it, and it is the only way to ask what
  the pipeline resolved to without firing it. Annotations are load-bearing here:
  this repo has had a doc block silently transfer its `---@param`/`---@return` to
  the wrong function three times, so `./check.sh` runs after every move in Phases
  1, 3 and 5, not just at the end.

**Tests.** New `LootPhases_test.lua`: handlers land in phase order regardless of
registration order; a sibling constraint on an unregistered name is ignored, not
fatal; a contradiction within a phase is still reported.

---

## Phase 3 -- The three extensions move to phases

**Change.** `Extensions.API_VERSION` 5 -> 6.

| Extension | Was | Becomes |
|---|---|---|
| `RollForPendingLoot.lua:51` | `after = "dropped_loot", before = "auto_loot"` | `phase = "Loot", after = "dropped_loot"` |
| `RollForPendingLoot.lua:72` | `before = "master_loot"` | `phase = "Loot"` |
| `RollForPendingLoot.lua:87,102` | anchors | `phase = "Loot"` |
| `RollForAutoLoot.lua:42` | `after = "dropped_loot_announce"` | `phase = "Award"` |
| `RollForAutoRobin.lua:50` | `after = "auto_loot"` | `phase = "Award"` |
| `RollForAutoRobin.lua:56` | `after = "auto_group_loot"` | `phase = "Award"` |

Bump `api_version` in all three specs (`:119`, `:192`, `:192`). The gate at
`Extensions.lua:194` gives anyone still on the old shape a clear message.

Note `RollForAutoRobin.lua:50` and `:56` become placeholders that Phase 5
deletes -- once auto-robin is a policy it registers no `on_loot` handler at all.

**Tests.** Each addon's `ExtensionRegistration_test.lua`. `Extensions_test.lua`
for the version gate at 6.

---

## Phase 4 -- Delete the position machinery

**Why.** Nothing anchors to a vacant name any more.

**Change.** Delete `POSITIONS`, `with_vacant_positions` (:116-152) and its
placeholder-insertion arithmetic, and the `index_of` helper it needs. Reject
`after`/`before` that name a handler in a *different* phase -- that is a phase
mistake wearing a sibling constraint.

**The string `auto_loot` no longer appears anywhere in core.**

**Tests.** Delete the vacancy cases in `LootFacadeListenerOrder_test.lua`; they
describe machinery that is gone.

---

## Phase 5 -- Claims, and core performing the award

**Why.** Phase order still does not decide who gets an item. `GiveMasterLoot` is
asynchronous, so the slot a policy has taken is still in the corpse when the next
one looks -- and everything downstream reads the same stale list
(`DroppedLootAnnounce.lua:217`, `LootController.lua:212`, `LootAutoProcess.lua:31`,
and `AutoGroupLoot.lua:28` takes an item *count* at `LootOpened` that a sweep
invalidates). That staleness is why `AutoRoundRobin.lua:235` reaches through a
global for `RollForAutoLoot.claims`.

**Change.** New `AwardPolicies.lua`:

```lua
ctx.award_policy( {
  name   = "auto_loot",
  title  = "Auto-loot",
  decide = function( slot, item ) ... end   -- player name, or nil for "not mine"
} )

ctx.loot_claim( slot )   -- nil, or the name of the policy holding it
```

The ledger is slot-keyed (slots are stable within a loot session, and duplicates
of one item id must stay distinguishable -- `AutoLoot.lua:79-81`), and cleared at
the start of `LootOpened`, not on `LootClosed`. `LootFacadeListener.lua:200`
records that `LOOT_CLOSED` can fire without `LOOT_SLOT_CLEARED`; clearing on open
is robust to that.

The `Award` phase runs:

```
for each slot with an item:
  if claimed( slot ) then skip
  for each policy in order:
    recipient = policy.decide( slot, item )
    if recipient then
      index = master_loot_candidates.get_index( slot, recipient )
      if index then
        GiveMasterLoot( slot, index ); claim( slot, policy.name ); break
      end
    end
```

and again on every `LOOT_SLOT_CLEARED` (decision 4).

**Guards core checks once, so no policy repeats them.**

- `player_info.is_master_looter()` -- `GiveMasterLoot` requires it, and core is the
  one calling it now. Was `AutoLoot.lua:75` and `AutoRoundRobin.lua:458`.
- `m.is_shift_key_down()` -- the standard "don't do the automatic thing" modifier.
  `AutoLoot.lua:102` calls itself "the only place that reads it" and AutoRobin
  describes its own copy as "the same manual-override escape auto-loot has"; with
  core running the loop that becomes true again, once, for every policy.

**Guards that stay in the policy.** Its own config toggle -- `config.auto_loot()`,
`config.auto_round_robin()` -- because that is the policy's own on/off switch and
nothing to do with the loop. A policy whose toggle is off returns nil from
`decide`.

**Coins.** Core skips any slot whose item has no `id`. That is AutoLoot's existing
rule (`AutoLoot.lua:83-84`: coins carry no id, and looting one is behind a secure
button the API cannot press) and it subsumes AutoRobin's separate
`item.type ~= "Coin"` test, so the two stop disagreeing about how to say the same
thing.

**Extension changes.**

- `AutoLoot`: `decide` returns the player's own name when `is_auto_looted( item )`.
  `find_my_candidate_index` (`AutoLoot.lua:34`) is deleted -- it reimplements
  `MasterLootCandidates.get_index`. `on_auto_loot`'s loop is deleted; core loops.
- `AutoRoundRobin`: `decide` returns the next player in the rotation.
  `claimed_by_auto_loot` (:235) and `is_awardable`'s call to it (:422) are
  deleted. `award_next`'s chaining (:457) is deleted; core chains.
- **Keep** `is_auto_looted` and `is_round_robined`. They still back the
  `on_dropped_item` predicates (`RollForAutoLoot.lua:59`,
  `RollForAutoRobin.lua:63`), which this phase explicitly does not touch. Deleting
  the award loop is not a reason to delete the predicate it called.
- `RollForAutoLoot.claims` (`RollForAutoLoot.lua:107`) is deleted outright, no
  deprecation shim. It is documented there as committed public API, so this is the
  one deliberate break a third party could notice; the API 6 gate at
  `Extensions.lua:194` is what tells them.

**Two things this fixes.** A policy that claims an item it then cannot take --
`is_auto_looted` true but no candidate index -- currently blocks auto-robin from
taking it, and nobody gets it. Claiming at the point of action rather than from a
predicate means the next policy gets its turn. And announcement suppression
(`on_dropped_item`, used at `RollForAutoLoot.lua:59` and `RollForAutoRobin.lua:63`)
becomes derivable from the ledger instead of a parallel hook each policy
implements separately -- worth doing, but as its own follow-up, not here.

**Tests.** The existing `GiveMasterLoot` mock (`test/utils.lua:459-467`) models
the async delay but never refuses a second award in one pass. Add a mock that
does refuse, so the chaining is actually exercised -- this is the one place the
suite currently cannot tell the two implementations apart. Plus: a policy
claiming blocks a later one; a policy whose recipient is not a candidate does not
block; the ledger clears on `LootOpened`.

---

## Phase 6 -- Policy order

**Change.** Core keeps the registered policies and an array of names in
`db( "award_order" )` -- per-character, matching the extension enabled flags
(`main.lua:225`, `db` is `RollForCharDb`). Reconciled at load:

1. Take the saved order, keep only names that registered this session.
2. Append registered policies not in the saved list, in registration order, **at
   the bottom** -- a newly installed addon must not silently outrank an
   established one.
3. Saved names that did not register stay in the list, skipped. Uninstalling and
   reinstalling gets a policy's position back; absent is not removed.

**Persisted only when the user reorders.** The effective order is computed fresh
at load from saved-plus-registered; core never writes on startup. A session where
an addon failed to load, or an alt without it, therefore cannot quietly rewrite
the order -- which is what makes rule 3 hold in practice rather than just on
paper.

**No db migration.** An absent `award_order` reads as "no saved order", which is
the fresh-install path reconciliation already handles. `Db.lua`'s versioning does
not need to know this field exists.

### Where the initial order comes from

Core ships a default order naming the policies RollFor distributes with itself
(`release.sh` packages them), in `AwardPolicies.lua`:

```lua
local DEFAULT_ORDER = { "auto_loot", "auto_robin" }
```

- A name in `DEFAULT_ORDER` that nobody registered is **ignored**. No placeholder,
  no error, no gap.
- A registered policy not in `DEFAULT_ORDER` -- anything third-party -- goes below
  the known ones, in registration order.
- `DEFAULT_ORDER` seeds only. Once a saved order exists it wins completely, and a
  policy installed later still appends at the bottom (rule 2) even if
  `DEFAULT_ORDER` would have ranked it higher. The user's arrangement is not
  re-sorted behind their back.

**This is not the `POSITIONS` mistake returning.** `POSITIONS` was load-bearing: a
missing name meant handlers anchored to it fell out of the chain and items went to
the wrong person, which is why vacancies needed placeholders. `DEFAULT_ORDER` is a
seed value -- absent names are ignored, an empty list works fine, nothing anchors
to it. And these are addons shipped in the same package, so it is core knowing its
own distribution rather than core knowing a stranger's feature.

The soft failure to be aware of: if `RollForAutoLoot` renames its policy, the
default silently stops applying to it and it lands below the known names instead.
That costs a first-run ordering, not correctness, and the user can drag it back.

Rejected: `## OptionalDeps: RollForAutoLoot` in AutoRobin's `.toc` to pin the load
order. It works and it is a legitimate client mechanism, but it is AutoRobin naming
AutoLoot -- the coupling these phases exist to remove, relocated from Lua to a
manifest where it is harder to find. `DEFAULT_ORDER` puts the statement in core,
where it is one list rather than a relationship between two addons.

Also rejected: seeding from registration order, which is addon load order
(`Extensions.register` appends at `Extensions.lua:120`, `enable` walks it with
`ipairs` at `:296`). With every pipeline addon declaring only
`## Dependencies: RollFor`, that is alphabetical by folder name -- `RollForAutoLoot`
above `RollForAutoRobin` preserves today's behaviour purely because `L` sorts
before `R`, and an addon named `RollForAardvarkLoot` would outrank both with
nothing to explain why.

Core's own handlers are deliberately **not** in this list. `MasterLoot.on_loot_opened`
(`MasterLoot.lua:82`) only clears a slot cache -- the `GiveMasterLoot` at :79 runs
when a human or a roll outcome picks someone -- and `roll_controller` starts a
roll. Neither claims automatically, so both are the fallback for unclaimed items
rather than competitors. That is what makes "new policies go to the bottom" safe.

**"Auto-loot beats auto-robin" now lives in one place the user controls**, instead
of in `AutoRoundRobin.lua:419-421`, which currently describes itself as the only
place the rule is written down.

**Tests.** Reconciliation: unknown names skipped but retained; new policies
appended; saved order respected; an absent `award_order` yields registration
order. First-in-order claims. No write occurs on load.

---

## Phase 7 -- The priority list UI

**Change.** A `priority_list` line type in `OptionsFrameContentTransformer`
(types today are `header`, `paragraph`, `boolean`, `number`,
`constrained_number`, `choice` -- :166-209) rendering rows with up/down arrows.

The settings entry, shaped like the existing ones (a `type`, a `label`, a `value`,
a callback):

```lua
{
  type    = "priority_list",
  label   = "Loot priority",
  value   = { { name = "auto_loot", title = "Auto-loot" },
              { name = "auto_robin", title = "Round robin" } },
  on_move = function( position, offset ) ... end   -- offset is -1 or 1
}
```

`on_move` takes the same `( position, offset )` as `AutoRoundRobin.lua:218`, which
swaps with a neighbour and deliberately does not wrap -- an arrow on the last row
sending that policy to the top reads as a bug. `value` is rebuilt from the
reconciled order each time the page is shown, so it reflects what is actually
registered now; `title` is whatever the policy supplied to `ctx.award_policy`.
Reordering applies immediately and persists on the move -- no apply button, no
reload.
The reorder pattern exists in `AutoRoundRobin.lua:218` (`M.move`, swapping with a
neighbour and deliberately not wrapping) and `:566`; core's row widgets are in
`GuiElements`.

A core options page listing the registered policies by the `title` each supplied.
Hidden when fewer than two policies registered -- with one there is no question
to answer.

**Tests.** `OptionsFrameSpec_test.lua` for the new line type. The rendering
itself needs a human in the client; so does the whole page.

---

## Verification

`./test.sh` and `./check.sh` after every phase -- they catch disjoint things.
Phases 1, 3 and 5 move functions between files, and a doc block left above the
wrong function silently transfers its `---@param`/`---@return` to it; that has
happened three times in this repo. Sync to the addons tree (`sync-bcc.sh`) and
run the three affected addons' suites after any core change -- their `test/mocks/`
are duplicated per addon, so a fix in one copy is two copies short here.

## What is not in this document

- **Announcement suppression via the ledger.** Phase 5 notes it; it is a
  follow-up, not part of this work.
- **Whether the client refuses a batch of awards.** Decision 4 makes the pipeline
  correct either way. Worth knowing, but it does not gate anything here.
- **Anything visual.** Phase 7's page needs a human in the client.
