# Chat messages: transitions, renderers, and the extension seam

Goal: an extension can change what RollFor says, not just add to it. Today it can
do neither -- `ctx.chat` lets it speak alongside core, and `ctx.on_dropped_item`
lets it silence exactly one message. There is nothing in between, because core has
no message layer to reach into: 62 call sites across 13 files each `string.format`
their own text and hand `Chat` a finished string.

The motivating case is small and the gap is not. `AutoRoundRobin` hands an item
out and the master looter's console reads `Obszczymucha received [Crimson
Spinel].` -- byte for byte what a human master-loot award prints. The rotation
cannot mark its own award, because by the time the text exists it is a string
core built from an event that does not record who caused it.

This document turns every core message into the rendering of a **transition**, and
then lets an extension render one.

## Where it stands

`Chat.lua` is transport, not a message layer: `announce` (:36) picks RAID /
PARTY / RAID_WARNING and chunks at 255 bytes, `info` (:44) writes to the player's
own console. Neither knows what it is carrying.

Of the 22 raid-facing `chat.announce` sites, **8 are already renderings of
events** -- `RollResultAnnouncer` subscribes to six `RollController` events
(:265-270) and builds text from their payloads. That is the target architecture,
already shipped, covering about a third of the surface.

The other 14 are built and sent in place, in the five rolling logics and
`DroppedLootAnnounce`. They have no event, so there is no data for anyone to
capture:

| Message | Site | Surface |
|---|---|---|
| `N items dropped:` + per-item lines + `and N more items...` | `DroppedLootAnnounce.lua:337,344,353` | raid |
| `Roll for 2x[item]:` + `. 2 top rolls win.` | `NonSoftResRollingLogic.lua:232` | raid warning |
| `Roll for [item] (SR)` + `SR by <names>` | `SoftResRollingLogic.lua:223,231,234` | raid warning |
| `SR rolls remaining: <names>` | `RollingLogic.lua:51` | raid |
| `Raid rolling [item]...` + the candidate roster | `RaidRollRollingLogic.lua:53,60,72` | raid |
| `Rolling for [item] was canceled.` (x3, one per logic) | `NonSoftRes:271`, `SoftRes:272`, `Tie:167` | raid |

The 40 `chat.info` sites split the same way. Some are lifecycle (the award line,
the ignored-roll notices, the roll listings); others are command feedback
(`UsagePrinter`, `TradeTracker`, `compat`, `LootController`) and are out of scope
here -- they answer a keypress, they do not report a transition.

Two half-built pieces already exist and should be finished rather than replaced:

- **`m.msg`** (`modules.lua:144`) -- six console templates (`rolls_exhausted`,
  `invalid_sr_roll`, `did_not_tie`...) that the rolling logics call instead of
  formatting inline. The right idea, stopped at six.
- **`RollController`'s event union** (`RollController.lua:107-133`) -- about
  twenty typed events through one `notify_subscribers` (:136). Most of the
  transitions this document needs are already declared there.

## Decisions already taken

Do not re-litigate these.

1. **Transitions, not a three-stage line.** `Loot -> Announce -> Award` describes
   one message. The drop announcement runs before the award (`PostLoot`), the
   award announcement after it, and an auto-awarded item never rolls at all --
   a policy's `on_awarded` announces inside `Award`, before the client has
   confirmed anything. Announcing is not a stage; it is what a transition looks
   like from outside.
2. **Events carry data, never a formatted string.** The counter-example is
   already in the tree: `rolling_started` takes a `message` parameter
   (`RollController.lua:1178`) that is a pre-built announcement passed through
   the controller. Nothing downstream can do anything with it but print it. Every
   transition added here carries fields.
3. **One renderer per surface, and the logics stop announcing.**
   `RollResultAnnouncer` is that module for roll results and keeps the job. A
   rolling logic decides what happened; it does not decide how it reads.
4. **Three values, not two.** An override returns `nil` for "no opinion, core
   renders it", `false` for "say nothing", or a string. `nil` cannot mean both of
   the first two, and `false`-suppresses is already the convention the withhold
   predicates use (`DroppedLootAnnounce.lua:225`).
5. **Overrides decorate, they do not replace.** Each renderer receives the
   previous rendering, exactly as `Chain.lua` links receive `inner`. Last-wins is
   silent when two extensions want the same message.
6. **The seam names the surface.** Tagging your own console line and rewording a
   raid warning the whole raid reads are different acts, and a renderer must not
   be able to do the second while meaning the first. `announce` and `info` stay
   distinguishable at the seam, and an override may not move a message from one
   to the other.
7. **Clean break at `Extensions.API_VERSION` 7**, when (and only when) the seam
   in Phase 4 lands. Phases 1-3 change no extension-facing contract.

## The model

An item moves through states. Each transition is an event; each event may have a
rendering; a rendering may be overridden. What exists today, and what has to be
added:

| Transition | Event | Status | Rendered where today |
|---|---|---|---|
| item dropped | `loot_dropped` | **new** | `DroppedLootAnnounce` builds and sends |
| rolling started | `rolling_started` | exists (`:1161`), **notified only for NormalRoll/SoftResRoll** (`:1191`) | header in the two logics |
| SR rolls outstanding | `waiting_for_rolls` | exists (`:1300`), carries nothing | `RollingLogic.lua:51` |
| raid roll started | -- | **new** (`rolling_started` returns early for RaidRoll) | `RaidRollRollingLogic.lua:72` |
| a roll came in | `roll` | exists, full payload (`:1001`) | nothing renders it |
| a roll was ignored | `ignored_roll` | exists, full payload incl. `reason` (`:1054`) | the logics call `m.msg` directly |
| countdown | `tick` | exists | `RollResultAnnouncer.lua:239` |
| rolling finished | `rolling_finished` | exists | `RollResultAnnouncer.lua:253` |
| winners found | `winners_found` | exists | `RollResultAnnouncer`, three shapes |
| tie | `there_was_a_tie` | exists | `RollResultAnnouncer.lua:180` |
| tie re-roll started | `tie_start` | exists | `RollResultAnnouncer.lua:229` |
| rolling canceled | `cancel_rolling` | exists but is a **command** carrying nothing (`:251`) | each logic prints its own |
| loot awarded | `loot_awarded` | exists | `RollResultAnnouncer.lua:262` |

Note the pattern in rows 6 and 7: the data is already there, in a typed event,
and the message is still built somewhere else from the same values. That is the
whole of the work -- not inventing a model, but pointing the existing text at the
events that already describe it.

---

## Phase 1 -- The award tag

**Why.** The motivating case, and it needs no seam at all: the extension already
causes this message.

**Change.** An optional `tag` on `LootAwardedEvent`, threaded from
`LootAwardCallback.on_loot_awarded` through `RollController.loot_awarded`.
`RollResultAnnouncer` renders it in parentheses, the way `(SR)` is already
rendered at `SoftResRollingLogic.lua:228` and `(MS)`/`(OS)` by
`roll_type_abbrev_chat`. `AutoRoundRobin.on_awarded` passes `"RR"`.

Whoever sent the award supplies the text, because what it says is theirs to say.
Core awards items it has no name for, and an award policy naming itself is the
one thing core would have to invent a vocabulary for.

**No API bump.** `loot_award_callback` reaches an extension through
`ctx.get`, and an optional trailing parameter is invisible to anyone not passing
it.

**Tests.** `AutoRoundRobinSpec_test.lua` asserts the exact console line in 13
places; they become `... received [X] (RR).` Core's own suites cover the
untagged path and must not move.

*(A spike of exactly this is sitting uncommitted in the working tree.)*

---

## Phase 2 -- The rolling logics stop announcing

**Why.** The bulk of the work, and the part that makes everything after it cheap.
While 14 messages are built at the point of sending, half the surface has no data
to hand anybody.

**Change.**

- Extend `rolling_started` past the `NormalRoll`/`SoftResRoll` gate
  (`RollController.lua:1191`) so raid rolls emit it too, and delete its `message`
  parameter (decision 2).
- Add a real `rolling_canceled` transition carrying the item, distinct from the
  `cancel_rolling` command that requests it. Three identical strings in three
  files collapse to one rendering.
- Give `waiting_for_rolls` the outstanding rollers, and move
  `RollingLogic.lua:51` into the announcer.
- Render `ignored_roll` from the event rather than each logic calling `m.msg`
  itself. `m.msg` stays as where the templates live.

**No contract change and no new seam.** This is a refactor whose only visible
effect should be that nothing changed. Every addon suite asserts exact chat lines
(`AutoRoundRobinSpec`, `SoftResRollSpec`, `NetherVortexSpec`, `PreviewSpec`,
`NormalRollSpec`...), which is what makes a no-op refactor of 14 messages
verifiable rather than hopeful.

Run `./check.sh` after each move: this repo has had a doc block silently transfer
its `---@param` to the wrong function three times, and this phase moves
functions between files.

---

## Phase 3 -- One registry, core-internal

**Why.** Prove the shape before committing to it as API.

**Change.** The announcer stops being a list of `subscribe` calls with a function
each, and becomes a table of renderers keyed by event type, each
`fun( data ): string|string[]`. Registration is core's; nothing extension-facing
changes. The 255-byte question (open question 2) gets settled here, where it is
cheap.

**Tests.** Unchanged, all of them. Same reasoning as Phase 2.

---

## Phase 4 -- The seam

**Change.** `Extensions.API_VERSION` 6 -> 7. `ExtensionContext` gains:

```lua
---@field on_message fun( event_type: string, renderer: MessageRenderer ): boolean
```

```lua
---@class MessageRenderer
---@field name string          -- who it is, for ordering and errors
---@field after string?        -- sibling ordering, Chain/Ordering semantics
---@field before string?
---@field render fun( data: table, previous: string|string[], surface: "announce"|"info" ): string|string[]|false|nil
```

`nil` means no opinion and `previous` stands. `false` suppresses. Anything else
replaces, and the next renderer in the chain receives it as its `previous`.

The committed surface is not `on_message` -- it is **the payload of every event
an extension may render**, which becomes as unrefactorable as `ExtensionContext`
itself. Publish the list deliberately and keep it short; a transition nobody
renders can stay unpublished.

**Tests.** A new `MessageRenderer_test.lua` in core: no renderer leaves text
untouched; `false` suppresses; two renderers chain in `Ordering` order; a
renderer that errors does not take the message with it.

---

## Phase 5 -- The drop announcement joins

**Why.** Last, because it is the awkward one, and nothing else waits on it.

**Change.** `DroppedLootAnnounce` renders from `loot_dropped` like everything
else. `ctx.on_dropped_item` becomes the special case it always was -- a renderer
returning `false` for one item -- and either stays as a thin alias or is
deprecated at 7.

**The hard part**, to be settled before this phase and not during it: the
predicate is **per item** while the announcement is **per window**, with a header
counting the items and an `and N more...` tail that depends on how many survived
the withholding. A renderer handed the whole window can silence one item only by
rebuilding the other two messages. Either `loot_dropped` carries the surviving
list and core still composes the three parts, or the per-item veto stays a
separate mechanism from rendering. The second is honest and smaller.

---

## Open questions

1. **Granularity for the drop announcement** -- see Phase 5.
2. **Who splits.** Messages built from player lists are split on element
   boundaries by `m.split_message` (`modules.lua:495`); a renderer returning one
   long string degrades to `chunk_text`'s dumber split mid-name. Either renderers
   return `string[]` and core never re-splits, or the payload carries the list and
   the renderer formats one element. Settle in Phase 3.
3. **Where the default renderers live.** `m.msg` is the obvious home and is
   currently console-only.
4. **Whether a renderer may change surface.** Recommend no (decision 6), but the
   raid-warning flag (`announce`'s second argument) is a third state that needs a
   home either way.
5. **Localisation** is out of scope and this is the layer that would carry it.
   Do not design for it; do not make it impossible.

## What this does not solve

- **An extension adding its own messages.** `ctx.chat` already does that, and
  `AutoRoundRobin`'s raid line stays the extension's own.
- **Making two extensions' opinions visible to the user.** Award policies got a
  reorderable settings row when the same problem came up (`AwardPolicies.lua:72`).
  Renderers would need one too, on the day two extensions actually collide --
  not before.
