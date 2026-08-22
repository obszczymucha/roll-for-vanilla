# SR rolling popup redesign — one row per player

## Goal

Today the rolling popup renders **one row per roll slot**. A player who soft-ressed an
item three times occupies three identical rows, and before anyone rolls those three rows
are indistinguishable placeholders.

A bonus-roll feature is coming: on top of N soft-res rolls a player may also receive N
bonus rolls. With 25 soft-ressers × (3 SR + 3 bonus) that is 150 rows. It does not fit on
a screen.

**This change makes the popup render one row per _player_, with each of that player's
rolls shown as a cell in that row.** 150 rows becomes 25.

Bonus rolls themselves are **out of scope**. Only the SR placeholder/roll presentation
changes. The design below reserves the mechanism bonus rolls will plug into (a roll type
per cell), so that landing them later is "add a colour and a texture", not a re-layout.

### Before / after

Setup: `2x[Bag]` drops. Drutree SR'd twice, Mendunia once, Mufasapowel twice, Pinp once.

```
BEFORE (6 rows)                          AFTER (4 rows)
╔═══════════════════════════╗            ╔═══════════════════════════╗
║   ●      Drutree      SR  ║            ║  ●  ●   Drutree           ║
║   ●      Drutree      SR  ║            ║  ●      Mendunia          ║
║   ●     Mendunia      SR  ║            ║  ●  ●   Mufasapowel       ║
║   ●    Mufasapowel    SR  ║            ║  ●      Pinp              ║
║   ●    Mufasapowel    SR  ║            ╚═══════════════════════════╝
║   ●        Pinp       SR  ║
╚═══════════════════════════╝
```

Part-way through — Mufasapowel rolled 91 then 50, Drutree rolled 75 and still owes one:

```
╔═══════════════════════════╗
║ 91 50   Mufasapowel       ║
║ 75  ●   Drutree           ║
║  ●      Mendunia          ║
║  ●      Pinp              ║
╚═══════════════════════════╝
```

`75  ●  Drutree` is the state that is unreadable today: it currently renders as two
identical `Drutree` rows and you must read both to work out which one is still pending.

## The two ordering rules

These are separate axes and it is easy to conflate them.

1. **Rows** are ordered by each player's **best** roll, descending. Un-rolled players
   sort last, alphabetically. Ties on best roll break alphabetically.
2. **Cells within a row** are ordered by **cast order** (chronological), *not* by value.

   In the emitted content, pending cells trail after cast ones and `best_index` indexes
   that array. On screen the widget flips it: cast rolls sit against the name and pending
   pips fill in to their left, so the numbers form one block that right-aligns on the
   name. Cast cells keep their chronological order among themselves. *(Revised during
   implementation, after in-game review.)*

So if player A casts 69 then 96, and player B casts 87 then 91:

```
 69 96   Player A       <- above B, because 96 > 91
 87 91   Player B
```

The left column reads `69, 87` — ascending, which looks like a sorting bug unless the
best roll is visually marked. **The best cell in each row must carry visual weight**
(full alpha; spent cells dimmed). The bright column is the ranking; dim numbers are
history. Without this, row order looks arbitrary.

## Current architecture (verified)

`SoftResRollGuiData.lua` and `TieRollGuiData.lua` **are dead code** — absent from every
`.toc`, never `require`d, and referenced nowhere but themselves. Do not edit them. They
are a decoy: they contain a near-miss version of the logic described here.

The live pipeline:

| Step | File | What it does |
|---|---|---|
| 1 | `RollTracker.lua` `preview()` / `start()` | Emits one `RollData` **per roll slot**: `{ player_name, player_class, roll_type, roll = nil }`. A 2-roll player yields 2 entries. |
| 2 | `RollTracker.lua` `add()` | On an incoming roll, `RollingLogicUtils.update_roll` fills that player's first empty slot, then `sort_roll_data` re-sorts the whole list. |
| 3 | `RollController.lua` `roll_content()` / `tie_content()` | Passes `current_iteration.rolls` into the popup as `RollingPopupRollData.rolls`. |
| 4 | `RollingPopupContentTransformer.lua` `add_rolls()` | Maps each `RollData` 1:1 to a `{ type = "roll" }` content line. |
| 5 | `RollingPopup.lua` (~line 167) | Renders each line into a `GuiElements.roll` frame. |
| 6 | `GuiElements.lua` `M.roll()` (line 231) | The 170px-wide row widget. |

`RollingLogicUtils.sort_roll_data` (line 119) sorts by `roll_type` ascending, then roll
value descending, `nil` rolls last, then player name.

**Grouping happens at step 4.** `RollTracker` keeps emitting one entry per roll slot —
do not change its data model beyond the ordinal added below. The transformer is the only
place that knows about rows.

## Change 1 — record cast order (`RollTracker.lua`, `RollingLogicUtils.lua`)

Nothing currently records when a roll arrived, so rule 2 above is unimplementable as-is.

Add a per-iteration monotonic counter. In `RollTracker.add()`, when `roll` is non-nil,
stamp `data.ordinal = <next counter value>` before dispatching. Reset the counter
whenever a new iteration is pushed (`preview()`, `start()`, `tie()`).

`RollingLogicUtils.update_roll` (line 109) writes `line.roll = data.roll` onto an
existing placeholder — extend it to copy `data.ordinal` too, or the ordinal is lost on
exactly the path SR rolls take. The `table.insert` branch in `add()` carries it for free.

Placeholders (no roll yet) get **no ordinal**. Do not default it to 0.

`ordinal` is an internal sort key. The transformer sorts cells by it and **does not emit
it** — a rendered cell is `{ roll_type, roll }`. The renderer has no use for it, and
keeping it out of the emitted content means the contract tests pin cell *order* rather
than a particular numbering scheme.

## Change 2 — group in the transformer (`RollingPopupContentTransformer.lua`)

Rewrite `add_rolls( result, rolls )` (line ~100).

**Which rolls group.** Define a groupable set, currently `{ SoftRes }`:

```lua
local groupable_roll_types = { [ RT.SoftRes ] = true }
```

Entries whose `roll_type` is groupable get collapsed by `player_name`. Everything else
(`MainSpec`, `OffSpec`, `Transmog`) passes through **completely unchanged**, emitting
today's single-roll line shape. This is required, not cosmetic: `NormalRollSpec_test.lua`
(e.g. lines 861-862) has MS and OS rows for different players in one popup, so the
per-row roll-type label is load-bearing there. When bonus rolls land, add the new type to
this set and it joins the same rows.

**Row order comes free.** The input is already sorted by `sort_roll_data` (best first,
`nil` last, alphabetical within ties). So: iterate the sorted input in order; the first
time you see a player_name, emit a row; on subsequent sightings, append a cell to that
existing row. First-sighting order *is* rule 1. Do not re-sort.

**Cell order.** Within each row, sort cells by `ordinal` ascending, with ordinal-less
(pending) cells last.

**Emitted line shape** for a grouped row:

```lua
{
  type        = "roll",
  player_name = "Drutree",
  player_class = "Warrior",
  rolls       = {                                     -- cast order, pending last
    { roll_type = "SoftRes", roll = 75 },
    { roll_type = "SoftRes", roll = nil }
  },
  best_index  = 1,      -- index into `rolls` of the highest cast roll; nil if none cast
                        -- on an internal tie (player rolled 75 twice) take the first
  cell_count  = 2,      -- uniform across every grouped row in this popup
  padding     = 11      -- first row only, as today
}
```

`best_index` marks the player's *own* best roll for emphasis. It is **not** a winner
flag — winners are separate content lines emitted by `add_winners`, with their own Award
buttons, and are unaffected by this change. A row can hold the popup's highest roll and
still lose (ties go to a tie roll).

Non-grouped rows keep today's exact shape (`roll_type`, `roll`, no `rolls` array). This
keeps `NormalRollSpec_test.lua`'s 159 assertions untouched.

**`cell_count` must be uniform across the whole popup**, not per section, or the name
column shifts between the main roll list and the tie list. Give `add_rolls` an optional
precomputed `cell_count` parameter:

- `roll_content` / `preview_content`: compute the max over their single list.
- `tie_content`: pre-pass over `data.roll_data.rolls` **and** every `iteration.rolls`,
  take the overall max, pass it to all `add_rolls` calls.

Tie iterations use `RollType.SoftRes` and are one roll per player, so they become 1-cell
grouped rows. That is intended — the whole SR popup stays visually consistent.

## Change 3 — the row widget (`GuiElements.lua` `M.roll`, line 231)

Today: a 35px right-aligned roll container at `LEFT`, a 16x16 icon at `LEFT, 22`, a
centered name, and a 37px roll-type container at `RIGHT`.

Add a grouped mode alongside it. **Keep the existing single-cell path byte-identical** —
non-grouped rows must render exactly as they do now.

*(Two revisions during implementation. The roll-type label is now centred in a box sized
to it rather than left-aligned in a 37px one — same side-bearing problem as the roll
cells — with its anchor offset so it stays in place; and `set_single_cell` restores the
name, label anchor and width, because the frame cache is per-popup and outlives a single
item, so a grouped row can come back as an MS/OS one.)*

Grouped mode:

- `frame.cells[ i ]` — lazily created, each holding a fontstring (right-aligned in its
  cell) and a 16x16 icon, positioned left-to-right from the frame's left edge.
- Expose `frame.set_cells( cells, cell_count, best_index )`.
- Cell width **fixed at 3 digits** (start at 24px and tune). A ragged grid across 25 rows
  is unscannable; the wasted pixels on single-digit rolls are the better trade.
- Player name **centred on the row**, which — since lines are anchored by their TOP
  centre — puts it on the popup's centre line, in the same column as the buttons. This
  works because the row is symmetric by construction: `side_zone = max( cell_count *
  cell_width, roll_type_zone )` is reserved on *both* sides of the name, so the name's
  centre is the row's centre regardless of cell count. See decision 3.
- Cells **right-align within the zone**: a row with fewer cells than `cell_count` gets its
  blanks on the left, so its cells still abut the name.
- Cell contents are **centred within each cell**. Right-aligning them lines up the advance
  edges, which puts the font's uneven side bearings on show — in `GameFontNormalSmall`,
  "75" is a 14px ink block where "50" is 17px, so right-aligned they start 3px apart.
- **Per-row roll-type label retained**, mirroring the cell zone on the far side of the
  name. See decision 2 — this reverses the original plan.
- `frame:SetWidth( cell_zone + name_zone )` instead of the hardcoded `SetWidth( 170 )`.
  `PopupBuilder.resize` (line 96) takes `max_width` over all line frames and calls
  `popup:SetWidth`, and `FrameBuilder`'s `add_line` calls `frame:resize( lines )` *after*
  `modify_fn`, so setting the width inside the render callback makes the popup grow
  correctly. No `PopupBuilder` change needed.

### ⚠ Frame pooling — the one real trap

`FrameBuilder.get_from_cache` (line 307) pools line frames **by `line_type`** and reuses
them across refreshes. A recycled `roll` frame still holds the cells it was given last
time. `set_cells` **must explicitly `Hide()` surplus cells** when the new row needs fewer
than the frame already has, or stale numbers from a previous roll bleed into the new one.
`frame.clear` only hides the line frame itself, not its children.

### Cell rendering

| cell state | render |
|---|---|
| pending, `SoftRes` | icon `Interface\AddOns\RollFor\assets\icon-white2.tga` |
| pending, bonus *(future)* | icon `Interface\AddOns\RollFor\assets\icon-gold.tga` |
| cast, `SoftRes` | roll value, existing blue (`m.colors.blue`) |
| cast, bonus *(future)* | roll value, gold |

`icon-gold.tga` already exists in `RollFor/assets/` at 32x32, same as `icon-white2.tga`,
so it drops into `GuiElements.icon` with no sizing work.

**Emphasis is on the alpha axis, never colour.** Colour encodes roll *type*, so it cannot
also encode best-vs-spent. The cell at `best_index` renders at full alpha; every other
cast cell at ~0.5. A spent bonus roll is dim gold; the winning bonus roll is bright gold;
nothing collides.

## Change 4 — tests

Baseline before starting: **508 tests across 44 files, all green** (`./test.sh`), plus the
5 pinned specs in `SrRowContract_test.lua`, which are red until this lands. After
implementation: **512 tests, all green**.

`SrRowContract_test.lua` calls `table.getn`, which Lua 5.4 removed, so it errored rather
than failed at baseline. The polyfill lives in `test/utils.lua`'s existing `if not lua50`
shim block; the pinned file itself is untouched.

### ⚠ The suite does not cover Change 3 at all

`test/mocks/PopupBuilder.lua` stubs the popup with `add_line = function() return {} end`.
`GuiElements` is loaded by `test/utils.lua` but its `M.roll` widget is **never invoked**
by any test. The mock in `test/mocks/RollingPopup.lua` captures
`transformer.transform( input )` and asserts against *that*.

So the suite verifies Changes 1, 2 and 4 thoroughly, and verifies **nothing** about cell
layout, cell width, alpha, icon selection, name alignment, popup auto-sizing, or the
frame-pooling trap. A fully green suite is compatible with a completely broken row
widget.

Change 3 must be checked by loading the addon in-game. `Sandbox.lua` (`/rft`) is a
scenario harness for exactly this — it feeds the popup handcrafted roll data with no raid,
loot or master loot needed. `/rft ?` lists the scenarios. Minimum cases to eyeball:

1. Preview with a 2-roll and a 1-roll soft-resser — pips align, names align.
2. Part-way through rolling — a row showing one cast roll and one pending pip.
3. All rolled — best cell bright, spent cells dim.
4. **Refresh from a longer row to a shorter one** (roll a second item with fewer
   soft-ressers without closing the popup) — this is the pooling trap; stale cells from
   the previous item must not persist.
5. A tie, so the tie section renders under the main list with a matching name column.

- `test/gui_helpers.lua` — add a grouped-row helper, e.g.
  `sr_row( player, { 69, 96 }, pending_count, padding )`, producing the `rolls` array
  shape above. Keep `sr_roll_placeholder` / `softres_roll` for any non-grouped use.
- `test/SoftResRollSpec_test.lua` — 197 uses. The bulk of the work.
- `test/PreviewSpec_test.lua` — 15 uses (lines 684-940), preview-state SR placeholders.
- `test/NormalRollSpec_test.lua` — 159 uses, **must not need edits.** If they break, the
  groupable-type filter is wrong.

`test/mocks/RollingPopup.lua` compares transformed content by deep equality, so nested
`rolls` arrays compare fine. `strip_functions` only walks the top level of each line —
cells hold no callbacks, so this is fine, but do not put callbacks in cells.

Run one file:

```
cd test && lua SoftResRollSpec_test.lua -v -T Spec -m should -o text
```

Whole suite: `./test.sh`

## Codebase conventions (Lua 5.0 / vanilla)

The addon ships to vanilla (Lua 5.0) **and** BCC from one source tree, so the new code
must stay 5.0-clean:

- Use `m.getn( t )`, never `#t`. `src/vanilla/compat.lua` maps it to `table.getn`,
  `src/bcc/compat.lua` to `#`. There are 121 `getn` calls in `src/` — match them.
- Build tables with `table.insert`, iterate with `ipairs` / `pairs`.
- When clearing a table that vanilla holds a length on, follow the existing pattern:
  `clear_table( t ); if m.vanilla then t.n = 0 end` (see `RollTracker.lua`
  `lua50_clear_table`).
- `table.sort` is fine in both.

Tests run under whichever Lua the host provides, so `#` will *pass the suite* and break
only on a real vanilla client. Grep your diff for it before finishing.

## Decisions already made

Do not re-litigate these; they were settled during design.

1. **Fixed cell width, not shrink-to-fit.** Column alignment across 25 rows beats
   compactness on single-digit rolls.
2. ~~**Grouped rows drop the per-row `SR` label.**~~ **Reversed during implementation.**
   The label is kept: with bonus rolls out of scope every cell is blue, so dropping the
   label left nothing on screen identifying the rolls as soft-res. The original objection
   still stands for later — one label cannot describe a row that mixes SR and bonus cells
   — and the per-cell colour mechanism is in place for when that lands.
3. ~~**Grouped rows left-align the name.**~~ **Reversed during implementation.** Grouped
   rows centre the name too, on the popup's centre line. The symmetric `side_zone` in
   change 3 is what makes this possible without the cell columns going ragged.
4. **Group in the transformer, not in `RollTracker`.** The tracker's one-entry-per-slot
   model is what the rolling logic consumes; changing it would ripple into
   `SoftResRollingLogic`.

## Out of scope

- Bonus rolls (data, chat, `/rf` syntax, roll acceptance). Only the *hooks* land here.
- Deleting the dead `SoftResRollGuiData.lua` / `TieRollGuiData.lua`. Flagged, not actioned.
- Same-player roll adjacency: Drutree's 75 and 74 remain in one row, but a *different*
  player tied at 75 still sorts between rows by best roll. That is inherent to rule 1.
