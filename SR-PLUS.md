# SR-PLUS: the removed soft-res roll bonus

What SR+ was, how it worked, what it was tested against, and what is in the way of
bringing it back. Documented in isolation -- this file is about the feature, not about the
extension split; the feasibility of hosting it as a provider-side modification is assessed
at the end and belongs with [SR-DIFF.md](SR-DIFF.md).

---

## 1. What SR+ did

A soft-res entry could carry a **numeric bonus that was added to that player's `/roll`**
for that item. A player with `sr_plus = 30` who rolled 89 was recorded as having rolled
119, and the boosted number is what won, what the popup showed and what the raid was told.

It is a *roll value* bonus. It is **not** an extra roll -- that is the separate
`bonus_rolls` mechanism from the resistance feature, ripped out later (§9.3).

The bonus was **per player, per item**, applied to **every** roll that player cast for
that item, and was carried on the soft-res data itself: no config toggle, no command, no
saved state of its own. Turning it off meant importing data without the field.

---

## 2. History

| | Commit | Date | Author | Version |
|---|---|---|---|---|
| Added | `13f9384` "Add SR+ from import on SR rolls" | 2025-02-21 | Sica \<sica@cook.as\> | 4.4.0 |
| Removed | `7d169a5` "Clean up interfaces and remove SR plus." | 2026-06-03 | Obszczymucha | 4.6.23 → 4.6.24 |

Both are on `master`; 37 commits separate them. SR+ shipped for roughly 15 months.

`sr_plus` appears in **exactly those two commits** and nowhere else in the history
(`git log --all -S"sr_plus"`), so what follows is the whole of it. It has been absent from
core since 4.6.24; core is now at 4.91 and no file in either repo mentions it.

The removal commit is **not** a pure revert -- it also renamed `SoftRes.get_item_ids` to
`get_items` and changed `is_player_softressing` to take an `ItemData` instead of an
`ItemId`. Those are unrelated interface cleanups riding along, and they are why the diff
touches `SoftRes.lua`, `SoftResCheck.lua`, both decorators, `LootList_test.lua` and
`SoftRes_test.lua`, none of which had anything to do with SR+.

---

## 3. How it worked, end to end

```
import JSON
  softreserves[].items[].sr_plus
        |
        v
SoftResDataTransformer.transform      roller.sr_plus = tonumber( item.sr_plus )
        |                             (set once, when the roller is first created)
        v
SoftRes store  -> softres_data[ item_id ].rollers[]
        |
        v
soft-res chain (matched_name -> awarded_loot -> present_players)
        |   decorators mutate/copy the roller tables; sr_plus rides along untouched
        v
RollingStrategyFactory.softres_roll   softres.get( sid( item.id ) ) -> RollingPlayer[]
        |
        +--> SoftResRollingLogic.on_roll        roll = roll + player.sr_plus   <-- the whole feature
        |    SoftResRollingLogic.format_name_with_rolls   " (+30)" in the roll call
        |
        +--> DroppedLootAnnounce.stringify      " (+30)" in the drop announcement
        |
        +--> RollResultAnnouncer.announce_winner   re-derives "89+30=119"
```

Five source files carried it, plus `Types.lua` for the annotation. Everything below is
quoted from `7d169a5^` -- the last commit that had it.

### 3.1 Import: `SoftResDataTransformer.lua`

```lua
---@class RaidResSoftRessedItem
---@field id number
---@field quality ItemQuality
---@field sr_plus number
...
        if not roller then
          roller = make_roller( roller_name, 1 )
          roller.sr_plus = tonumber( item.sr_plus )
          table.insert( sr_result[ item_id ].rollers, roller )
        else
          roller.rolls = roller.rolls + 1
        end
```

Read from the **item**, not the reserve entry: `softreserves[].items[].sr_plus`.
`tonumber` coerces, so `"40"` and `40` both work. Note the `else` branch: on a duplicate
entry (which is how extra rolls are granted) only `rolls` is bumped, so **the bonus is
whatever the first entry for that player carried** -- see §6.2.

### 3.2 The type: `Types.lua`

```lua
---@class RollingPlayer
---@field name string
---@field class string
---@field online boolean
---@field rolls number
---@field sr_plus number     <-- added
---@field type "RollingPlayer"
```

Annotation only. `make_roller` and `make_rolling_player` were **not** changed to carry it,
which is why the transformer sets it as a loose field afterwards -- and why anything that
rebuilds a player through those constructors drops it (§6.1).

### 3.3 The roll: `SoftResRollingLogic.on_roll`

```lua
    if player.sr_plus then
      roll = roll + player.sr_plus
    end

    player.rolls = player.rolls - 1
    table.insert( rolls, make_roll( player, roll_type, roll ) )
    controller.roll_was_accepted( player.name, player.class, roll_type, roll )
```

Applied **after** validation (did they soft-res, was it a `/roll 1-100`, do they have rolls
left) and **before** the roll is recorded. So:

- The boosted value is what lands in `rolls`, what sorting and winner selection compare,
  and what the popup shows -- there is no separate "base roll" anywhere.
- A boosted roll can exceed the `/roll` maximum. Nothing clamps it.
- The bonus is applied on **every** roll, so a player with two rolls gets +30 twice.
- `Roll` is `{ player, roll_type, roll }` -- one number. This is the single design decision
  that everything in §6 follows from.

### 3.4 The roll call: `SoftResRollingLogic.format_name_with_rolls`

```lua
    local roll_count = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    local sr_plus = player.sr_plus and string.format( " (+%d)", player.sr_plus ) or ""
    return string.format( "%s%s%s", player.name, roll_count, sr_plus )
```

Produces `Roll for [Bag]: SR by Obszczymucha and Psikutas (+30)`.

### 3.5 The drop announcement: `DroppedLootAnnounce.stringify`

```lua
      local rolls = show_rolls and player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
      local sr_plus = player.sr_plus and string.format( " (+%s)", player.sr_plus ) or ""
      return string.format( "%s%s%s", player.name, rolls, sr_plus )
```

Produces `1. [Bag] (SR by Obszczymucha and Psikutas (+30))`.

### 3.6 The winner: `RollResultAnnouncer.announce_winner`

```lua
    local function sr_plus( value )
      local sr_item = sid( item.id )
      local sr_players = softres.get( sr_item )
      local sr_player = m.find( winners[ 1 ].name, sr_players, 'name' )

      if sr_player and sr_player.sr_plus then
        local plus_value = sr_player.sr_plus
        value = value - plus_value
        return string.format( "%s+%s=%s", value, plus_value, value + plus_value )
      end

      return value
    end
```

Produces `Psikutas rolled the highest (89+30=119) for [Bag] (SR).`

This is the fragile part. The announcer receives only the **final** number, so it looks the
winner up in the soft-res store *again* and **subtracts** to reconstruct the base roll. It
is a guess about where the number came from, and §6.1 shows it guessing wrong. It is also
the only reason `RollResultAnnouncer.new` needed a `softres` argument at all -- adding and
removing that argument is the `main.lua` and `IntegrationTestBuilder.lua` change in both
commits.

---

## 4. Where it showed up

| Surface | With SR+ | Source |
|---|---|---|
| Drop announcement | `1. [Bag] (SR by Obszczymucha and Psikutas (+30))` | `DroppedLootAnnounce` |
| Roll call (raid warning) | `Roll for [Bag]: SR by Obszczymucha and Psikutas (+30)` | `SoftResRollingLogic` |
| Rolling popup roll cell | `119` (the boosted number, unlabelled) | via `roll_was_accepted` |
| Winner announcement | `Psikutas rolled the highest (89+30=119) for [Bag] (SR).` | `RollResultAnnouncer` |

Where it did **not** show up:

- The loot-frame tooltip's "Soft-ressed by" list -- plain names, asserted in the test.
- `/srs` (the reserved-items list) and `/src` (the check). `SoftResCheck` was never touched.
- The Gargul broadcast (`GargulBridge`), which reads `softres.get` but only for names.

---

## 5. Test coverage

Two tests, both added with the feature, both removed with it.

### 5.1 `SoftResDataTransformer_test.lua :: should_transform_soft_ressed_plus_values`

Unit. Asserts the field survives the transform, that `"40"` as a string becomes `40`, and
that a player with two entries for one item keeps `rolls = 2` alongside the bonus.

### 5.2 `SoftResRollSpec_test.lua :: SoftResPlusSpec:should_use_sr_plus_values`

Full integration, ~105 lines, loot-drop through to award. Two SR players on one item, one
with `+30`. Asserts every one of the four surfaces in §4 including the exact chat strings,
the popup contents at each step, and that the boosted player wins with 119 against a 99.

### 5.3 Both verified passing

The pre-removal tree was checked out and run rather than taken on trust:

```
$ lua SoftResDataTransformer_test.lua      -> Ran 4 tests, 4 successes
    SoftResDataTransformerSpec.should_transform_soft_ressed_plus_values ... Ok
$ lua SoftResRollSpec_test.lua             -> Ran 8 tests, 8 successes
    SoftResPlusSpec.should_use_sr_plus_values ... Ok
```

### 5.4 What was never covered

- **Ties.** No test put two SR+ players, or an SR+ player and a plain player, into a tie.
  §6.1 is what that missed.
- **More than one roll.** No test gave an SR+ player two rolls, so "+30 on both rolls" was
  never asserted either way.
- **Ordering.** No test put the bonus on anything but the first entry (§6.2).
- **Bounds.** No test for a bonus pushing a roll past 100, a negative bonus, a zero bonus
  (`0` is truthy in Lua, so `(+0)` would have been printed and `+0=` decomposed), or a
  non-numeric one (`tonumber` yields `nil`, which reads as "no bonus" -- silently).
- **Real data.** No fixture in the repo has ever contained an `sr_plus` field (§7).

---

## 6. Known defects

### 6.1 The winner announcement lies after a tie re-roll -- reproduced

`RollingStrategyFactory.tie_roll` rebuilds the tied players:

```lua
    local rollers = m.map( players, function( player )
        return make_rolling_player( player.name, player.class, player.online, 1 )
      end )
```

`make_rolling_player` does not carry `sr_plus`, so the tie round is **not** boosted -- which
is defensible. But `RollResultAnnouncer` does not know that: it still finds the winner in
the soft-res store, still sees a bonus, and still subtracts it from a roll that never had
one.

Probe run against the pre-removal tree
(`scratchpad/srplus/test/SrPlusTieProbe_test.lua`): p1 holds `+30`, rolls 39 (boosted to 69)
and ties p2's flat 69; in the tie round p1 rolls a flat 50 and wins.

```
Was:      "RollFor: Psikutas re-rolled the highest (20+30=50) for [Bag] (SR)."
Expected: "RollFor: Psikutas re-rolled the highest (50) for [Bag] (SR)."
```

Psikutas rolled 50. The addon told the raid they rolled 20.

The same reconstruction runs for **any** winner of an item the player soft-ressed,
whatever produced the roll, because the announcer's only input is the final number and the
store.

### 6.2 The bonus is read from the first entry only -- reproduced

The transformer sets `sr_plus` when it creates the roller and never revisits it. Probe
(`scratchpad/srplus/test/SrPlusOrderProbe_test.lua`):

```
plus on FIRST entry : rolls=2 sr_plus=40
plus on SECOND entry: rolls=2 sr_plus=nil     <-- silently dropped
two different values: rolls=2 sr_plus=40      <-- second value silently ignored
```

An export that puts the bonus on a later duplicate loses it with no warning.

### 6.3 The bonus is written onto the store's own roller tables

`SoftRes.get` returns `m.clone( rollers )`, and `m.clone` is **shallow** -- the list is new,
the roller tables in it are the stored ones. SR+ inherited that rather than caused it, but
it is the trap the later `SoftResBonusRollDecorator` was written to avoid, in a comment
that names the failure mode:

> Writing through them would leave a `bonus_rolls` behind on the soft-res data itself, and
> the first thing that would break is turning the feature off -- the stale number would
> keep producing bonus placeholders after the decorator had stopped annotating.

Any reintroduction that annotates rather than imports must copy first.

### 6.4 No bounds, no validation

Covered in §5.4. Worth restating that `0` is truthy in Lua, so a zero bonus is displayed
and decomposed rather than ignored. The `d ~= 0` guard in §10.2's fold disposes of that one;
the rest (a negative bonus, a bonus past 100, a non-numeric one) stay policy questions for
whoever supplies the number.

---

## 7. The data problem: nothing produces `sr_plus`

The transformer expects `softreserves[].items[].sr_plus`. **No export format known to this
repo has ever emitted that field**, and no fixture in any commit contains it
(`git grep sr_plus` over every fixture in every revision: no hits). The two tests fabricate
it through `u.soft_res_item( player, item_id, quality, sr_plus )`.

What the real formats carry:

| Site | Bonus-ish fields | Level | Read by RollFor? |
|---|---|---|---|
| softres.it | `rollBonus`, `plusOnes` | the reserve **entry** | never |
| raidres.top | none | -- | -- |

Note the mismatch even for softres.it: its bonus is per **player**, SR+ expected it per
**item**.

At the time SR+ was written the addon targeted `raidres.fly.dev` (the TOC's own Notes line
at `13f9384`, and the README credits "Itamedruids for *Raidres* and adding the export
function"). That instance is not the raidres.top of today, and neither the README's
"Soft-Res data format" section nor the commit message documents where an `sr_plus` was
supposed to come from. The most likely reading is that the contributor had a source that
emitted it, and the field's provenance was never written down.

**This is the first thing to settle before writing any code**: SR+ is finished as a
consumer and unstarted as a producer. Reintroducing §3 verbatim gives a feature no import
can trigger.

---

## 8. What removal took out

Reverting `7d169a5` is not the way back -- it would also revert the `get_items` /
`is_player_softressing` interface cleanup that shipped in the same commit and has been
built on ever since. The SR+ half is:

| File | Then | Now |
|---|---|---|
| `src/SoftResDataTransformer.lua` | 2 lines + 1 annotation | moved to the extensions, `RollForSoftResIt/src/` and `RollForRaidRes/src/` |
| `src/Types.lua` | 1 annotation line | unchanged location |
| `src/SoftResRollingLogic.lua` | 4 lines in `on_roll`, 2 in `format_name_with_rolls` | both functions rewritten (§9.1) |
| `src/RollResultAnnouncer.lua` | the `sr_plus` closure, the `softres` parameter, `local sid` | restructured (§9.2) |
| `src/DroppedLootAnnounce.lua` | 2 lines in `print_player` | unchanged |
| `main.lua`, `test/IntegrationTestBuilder.lua` | the `softres` argument | unchanged |

---

## 9. What has changed since

### 9.1 `SoftResRollingLogic` was rewritten

`on_roll` no longer decrements `player.rolls` inline. It calls
`RollingLogicUtils.consume_roll( player )`, which spends from a **pool table** and returns
which pool paid:

```lua
local roll_pools = {
  { field = "rolls", roll_type = RT.SoftRes }
}
```

The comment above it is explicit that this is the intended extension seam:

> This is the whole extension seam. A second pool -- a wipe-recovery roll, a penalty roll
> -- is one entry here plus whatever persistence it needs, and nothing that decides winners
> has to know it exists.

That seam is for extra **rolls**. SR+ modifies a roll's **value**, and there is no
equivalent seam for that -- the addition would still go in `on_roll` by hand.

`format_name_with_rolls` was also rewritten, and `start_rolling` now budgets the roll call
against the chat byte limit via `m.split_message`. A `(+30)` per name is more bytes in that
budget, so re-adding it changes where the roll call splits.

### 9.2 `RollResultAnnouncer` was restructured

The message is now built as `rollers .. suffix( f )` and announced through
`m.split_message`, but `roll_value` still enters in exactly one place, so the insertion
point is unchanged in substance.

### 9.3 Bonus rolls came and went in between

`a45ddf7` / `a65c898` (2026-08-24) added resistance **bonus rolls** -- extra rolls, a
different feature that this document is not about -- and `89aca10` / `1ac53f4`
(2026-09-07) ripped them out. Two things from that episode matter here:

- `SoftResBonusRollDecorator` (deleted at `89aca10^`) is the **best precedent** for what an
  SR+ decorator should look like: a chain link that copies each roller before annotating
  it, with `config` consulted inside `get` so the feature can be switched off without a
  reload.
- The rip-out left core contributing **nothing** to the soft-res chain -- it is now
  entirely the source extension's. So there is no longer a natural place in core for a
  soft-res annotation to be added from.

### 9.4 The import moved out of core

`SoftResDataTransformer` and the store now live in the source extension. The field's
producer and its consumers are therefore on **opposite sides of the addon boundary**:
`sr_plus` would be created in `RollForSoftResIt`/`RollForRaidRes` and consumed in core's
`SoftResRollingLogic`. Today that works by accident -- the roller tables are passed by
reference and core never validates their shape -- but nothing in `ExtensionContext`
declares it, so it is an undocumented contract rather than an API.

---

## 10. Bringing it back

### 10.1 Record the adjustment; do not teach the model what SR+ is

The defect behind §6.1 is not a missing field. It is that **something modified a roll and
did not record that it had**, leaving `RollResultAnnouncer` to re-derive the composition by
querying the store. Anything that fixes the re-derivation fixes the bug; the question is
what shape the record takes.

The obvious shape -- `base_roll` and `bonus` on `Roll` -- is the wrong one. `Roll` is
flattened at `MasterLootCandidates.transform_to_winner( player, item, roll_type, roll,
rerolling )`, so two named scalars mean two more arguments there and two more fields on
`make_winner`. The next modification means two more again, and core's roll model ends up
enumerating every modification anybody ever wrote. That is a closed model wearing an
extension's clothes.

**Carry provenance instead of components.** One optional field, open-ended content:

```lua
---@class RollAdjustment
---@field by string    -- the modifier that made it, e.g. "sr_plus"
---@field delta number -- signed, what it added or took away

---@class Roll
---@field player RollingPlayer
---@field roll_type RollType
---@field roll number             -- the total. Unchanged: still what sorting compares.
---@field adjustments RollAdjustment[]?  -- how it got there; absent means "as rolled"
```

The base roll is `roll` minus the sum of the deltas, so nothing needs storing twice. The
announcer renders whatever is in the list without knowing what produced it -- `89+30=119`
for one adjustment, `50+30+20=100` for two, the bare number when the list is absent. Every
existing reader of `roll` and `winning_roll` is untouched, which is what keeps this cheap:
`WinnerTracker` and `LootAwardPopup` keep showing the total, as they do today.

A delta is the right currency because it is the only one that composes. A multiplier, a
cap, a penalty -- each computes its own effect and reports the difference it made, and the
display stays generic for all of them.

### 10.2 The seam: `roll_modifiers`

`RollingLogicUtils.roll_pools` is core's declared extension point for *how many* rolls a
player gets. Roll *value* gets the sibling, in the same file, empty by default:

```lua
-- What may adjust a roll, after it is validated and before it is recorded. Core adds
-- nothing: an empty list is the current behaviour exactly.
local roll_modifiers = {}
```

#### The spec

```lua
---@class RollModifier
---@field name string    -- unique; this is what lands in RollAdjustment.by
---@field after string?  -- anchors, in the vocabulary Chain and the loot pipeline already use
---@field before string?
---@field rounds RollingStrategyType[]  -- which rounds it takes part in
---@field delta fun( player: RollingPlayer, item: Item ): number?
---@field adjust fun( player: RollingPlayer, item: Item, base: number, current: number ): number?
```

A modifier declares **either `delta` or `adjust`, never both** -- and that single choice is
what makes the rest of the design fall out:

- **`delta` is static.** It sees only the player and the item, so its answer is knowable
  before anybody rolls. That is what makes it previewable, and previewable is what the
  pre-roll display needs (§10.3).
- **`adjust` is dynamic.** It also sees the base roll and the running total, which is what a
  percentage or a cap needs -- and is exactly why it cannot be previewed.

Whether a modifier can be announced in advance is therefore a *consequence of which
function it wrote*, not a boolean it can set wrongly. Registration rejects a modifier that
declares both or neither, the way `Extensions.register` already rejects a spec with neither
`on_enable` nor `on_ready`.

#### Ordering

Do not invent a scheme. `Ordering.place( entries, { base = ..., noun = "modifier" } )` is
already the codebase's answer for a flat ordered list of named entries with `after`/`before`
anchors -- it was lifted out of `Chain` precisely so that "an extension anchoring a loot
handler should get the same vocabulary, the same failures and the same error messages it
already knows from the soft-res chain." A roll modifier is the third caller of the same
idea. Resolve once at build time, as `Chain` and `LootFacadeListener` do.

For two additive modifiers the order does not change the total (see §10.3), but it does
change the displayed order, and it becomes load-bearing the moment anybody writes an
`adjust`. Pin it before that happens, not after.

#### The fold

```lua
---@param strategy RollingStrategyType
---@return number, RollAdjustment[]?
function M.apply_modifiers( player, item, roll, strategy )
  local total, adjustments = roll, nil

  for _, mod in ipairs( placed_modifiers ) do
    if takes_part( mod, strategy ) then
      local d = mod.delta and mod.delta( player, item )
          or mod.adjust and mod.adjust( player, item, roll, total )

      if d and d ~= 0 then
        total = total + d
        adjustments = adjustments or {}
        table.insert( adjustments, { by = mod.name, delta = d } )
      end
    end
  end

  return total, adjustments
end
```

`on_roll` calls it where SR+ used to add inline, and passes `adjustments` into `make_roll`.
`d ~= 0` is deliberate: a zero adjustment is not an adjustment, which disposes of the
`(+0)` and `+0=` displays §6.4 flagged.

#### The call sites

There are three `on_roll` implementations, and they do not share one:

| File | Round | Spends rolls via |
|---|---|---|
| `SoftResRollingLogic.lua` | soft-res | `consume_roll` |
| `TieRollingLogic.lua` | tie re-roll | `consume_roll` |
| `NonSoftResRollingLogic.lua` | MS/OS | `player.rolls = player.rolls - 1`, inline |

Each folds the list for its own round. `rounds` on the spec is what keeps a modifier out of
the rounds it has no business in.

### 10.3 Worked example: a second modifier

Take a hypothetical `RollForRoleBonus`: **+20 for tanks, +10 for healers**. It is the test
that matters, because SR+ alone never proves the seam is a seam.

```lua
ctx.roll_modifier.register( {
  name = "role_bonus",
  rounds = { RS.SoftResRoll, RS.NormalRoll, RS.TieRoll },
  delta = function( player )
    local role = roles.get( player.name )
    if role == "tank" then return 20 end
    if role == "healer" then return 10 end
  end
} )
```

A protection warrior holding SR+30 rolls 50:

```
50  base
+30 sr_plus
+20 role_bonus
=100
```

The announcer renders `50+30+20=100` from the list. Neither extension knows the other
exists; core knows what neither of them does. **The accumulation is seamless, and the total
is order-independent**, because both are additive and addition commutes. Enable/disable is
already handled too: modifiers register in `on_enable`, and a disabled extension never gets
`on_enable`.

Four things the example exposes that SR+ alone did not.

#### The seam changes a roll; it does not source your input

SR+'s number rides on the soft-res data, so the chain delivers it. A role bonus needs a
**spec**, and `RollingPlayer` carries `name`, `class`, `online`, `rolls` -- nothing more.
Class is not role: a warrior may tank or DPS, a druid can be any of four. BCC has no API for
another player's spec.

There is exactly one real source already in the building, and it is being thrown away:
**raidres emits `role` per soft-reserve entry**, `{"name": "Boulderdash", "role":
"WarriorProtection", ...}`, and `SoftResDataTransformer` discards it (see SR-DIFF.md §4,
where `role` is listed among the fields nothing reads). So the extension is implementable
today -- through the provider, and only for players who soft-ressed. Everybody else needs a
manual assignment.

The general rule: **`roll_modifiers` answers "how do I change a roll". Every modification
still has to solve its own input problem, and the answers differ.** SR+ gets its input from
a chain link; a role bonus gets its from provider metadata or a command.

#### Pre-roll display needs the preview

SR+ showed `(+30)` in two places *before anybody rolls* -- the drop announcement and the
roll call -- by reading `player.sr_plus` off the roller. With two modifiers, what does the
roll call say? `Psikutas (+30) (+20)`? `Psikutas (+50)`?

`adjust` cannot answer; `delta` can, which is the whole point of the split. Both examples
here are static, so both can annotate, and the display sums them into one `(+50)` with the
breakdown left to the winner announcement where there is room for it. A dynamic modifier
contributes nothing to the pre-roll display and must not pretend otherwise.

There is a byte cost: `format_name_with_rolls` and `DroppedLootAnnounce.print_player` both
feed `m.split_message`, so a longer annotation per name means the roll call splits earlier
(§9.1).

#### `rounds` -- and the correction to §6.1

**This falsifies what an earlier draft of this section claimed.** It said ties come out
clean because "the tie round applies no modifiers, so `adjustments` is absent". That is true
of SR+ and false in general: a role bonus that applies everywhere *would* fire in the tie
round, and should.

The correct statement is stronger and does not depend on which modifiers exist: **the
announcer is right whenever modifiers record what they did, in whichever round they fired.**
SR+ declares `rounds = { RS.SoftResRoll }` and contributes nothing to a tie, so a tie
re-roll prints the bare number -- §6.1 fixed. `role_bonus` declares all three, contributes
to the tie, and the tie announcement correctly reads `40+20=60`. Neither needs a special
case anywhere, which is the property being bought.

#### Ordering is free here, but only here

Two additive modifiers, any order, same total. Add a cap -- "no roll above 100" -- and order
is load-bearing: cap-then-add is not add-then-cap. Without an explicit rule the default is
registration order, which is addon load order, which is alphabetical:
`RollForRoleBonus` before `RollForSrPlus` for no reason anybody chose. Hence `Ordering` in
§10.2.

### 10.4 Decide the source of the number

Per §7 this is a product question, not a code one. The options, in the order they cost:

1. **Per-entry, from softres.it's existing `rollBonus`.** Real data, available today, no
   new format. Costs a shape change: the bonus becomes per player, not per item.
2. **Per-item, from a format that emits it.** What the original code expected. Needs a
   source that actually produces it.
3. **Locally assigned** -- a `/sr+ <player> <n>` command with its own db. Independent of
   every provider, and the only option that works with raidres.top as it exists.

### 10.5 Decide where it lives

Three shapes, in the terms [SR-DIFF.md](SR-DIFF.md) sets out:

- **Provider-side field.** The transformer reads it, exactly as before. Cheapest, but ties
  the feature to whichever provider's format carries it, and duplicates into every provider
  that wants it.
- **A chain link plus a modifier, in its own extension** -- `RollForSrPlus`, modelled on
  `SoftResNetherVortexDecorator` and `SoftResBonusRollDecorator`. Both are live proof that
  an extension can annotate rollers on the read path, and it is where option 3 above would
  naturally hold its data. This is the shape that generalises: SR+ becomes one modification
  among several rather than a provider feature.
- **Back in core.** Only if the bonus is considered part of what a soft-res roll *is*.

The blocker for the middle option used to be that **annotating is not enough**: a chain link
can put a number on a roller, but the addition happens in core's
`SoftResRollingLogic.on_roll`, and no extension can reach it. `roll_modifiers` is the
missing half -- the chain link supplies the number on the read path, the modifier spends it
on the roll path. §10.3 is the demonstration that the pair generalises past SR+.

### 10.6 Checklist

**Core, once:**

1. `Roll.adjustments` + `RollAdjustment` in `Types.lua`; carry it through `make_roll`,
   `transform_to_winner` and `make_winner` (§10.1).
2. `RollResultAnnouncer` reads the list instead of querying the store; drop its `softres`
   argument, undoing both commits' `main.lua` and `IntegrationTestBuilder.lua` change (§3.6).
3. `roll_modifiers`, `apply_modifiers` and registration validation in `RollingLogicUtils`,
   ordered through `Ordering.place` (§10.2).
4. Fold it into all three `on_roll` implementations, honouring `rounds` (§10.2).
5. A preview path for `delta`-style modifiers, consumed by `format_name_with_rolls` and
   `DroppedLootAnnounce.print_player`; re-check the `split_message` budget (§10.3).
6. Expose `roll_modifier.register` on `ExtensionContext` and bump `Extensions.API_VERSION`.

**SR+, as a modification:**

7. Settle §7 -- where the number comes from. Nothing else about SR+ can be specified until
   this is.
8. Whatever supplies it, copy the roller before annotating (§6.3), and resolve the
   first-entry-wins behaviour §6.2 proves rather than reproducing it.
9. Register one modifier: `name = "sr_plus"`, `rounds = { RS.SoftResRoll }`, `delta`.

**Tests:**

10. Restore both original suites (§5.1, §5.2).
11. Add what §5.4 lists -- ties first, since §6.1 is proven and the probe already exists.
12. Add a two-modifier accumulation test built on §10.3: static + static, order-independent
    total, one combined pre-roll annotation, correct decomposition in the announcement.
13. Add a fixture that actually contains the field, whichever format wins.

---

## Appendix: reproduction

The pre-removal tree and both probes:

```
git archive 7d169a5^ | tar -x -C <dir>
cd <dir>/test
lua SoftResDataTransformer_test.lua -v -T Spec -m should -o text   # 4/4, incl. the SR+ unit test
lua SoftResRollSpec_test.lua        -v -T Spec -m should -o text   # 8/8, incl. SoftResPlusSpec
lua SrPlusTieProbe_test.lua         -v -T Spec -m should -o text   # fails: "(20+30=50)" for a flat 50
lua SrPlusOrderProbe_test.lua       -v -T Probe -m show  -o text   # prints the ordering behaviour
```

The two probe files are not in git; they were written for this analysis and live in the
session scratchpad at `srplus/test/`. The tie probe, in full, so it survives this session:

```lua
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local sr = u.soft_res_item

-- p1 holds +30, p2 holds nothing. p1 rolls 39 -> 69 (boosted) and ties p2's flat 69.
-- The tie round rebuilds players via make_rolling_player( name, class, online, 1 ), which
-- drops sr_plus, so the tie rolls are NOT boosted. p1 then re-rolls a flat 50 and wins.

SrPlusTieProbeSpec = {}

function SrPlusTieProbeSpec:should_not_decompose_the_tie_reroll()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69, nil, 30 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  loot_facade.notify( "LootOpened", item, item2 )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas (+30))" )
  chat.raid( "2. [Hearthstone]" )

  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  chat.raid_warning( "Roll for [Bag]: SR by Obszczymucha and Psikutas (+30)" )

  -- When: p1's 39 is boosted to 69, tying p2's flat 69.
  rf.roll( p1, 39, 1, 100 )
  rf.roll( p2, 69, 1, 100 )

  chat.console( "RollFor: Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
  chat.raid( "Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )

  -- When: the tie round. No boost is applied here.
  rf.ace_timer.tick()
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.roll( p1, 50, 1, 100 )
  rf.roll( p2, 40, 1, 100 )

  -- Then: p1 rolled a flat 50 and won. This is what it SHOULD say.
  chat.console( "RollFor: Psikutas re-rolled the highest (50) for [Bag] (SR)." )
  chat.raid( "Psikutas re-rolled the highest (50) for [Bag] (SR)." )
end

os.exit( lu.LuaUnit.run() )
```
