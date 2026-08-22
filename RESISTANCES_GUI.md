# Resistances GUI — plan of action

`/rfres` opens a movable frame listing the group's resistance data instead of
printing to chat. Same construction as `/rf autoloot`: a `PopupBuilder` popup,
a content transformer, and a widget in `GuiElements`.

## Layout

```
                    RollFor Resistances
   Player            Resistance   Personal   Total
 x Psikutas          Shadow             60     130
 x Obszczymucha      Fire              302     327 
 x Tachikoma         -                   -       -
              [ Scan ]  [ Clear ]  [ Close ]
```

- **x** — per row, clears that player's cached data. Row falls back to `-`.
- **Player** — class-colored name (`m.colorize_player_by_class`).
- **Resistance** — the school being reported: the one passed to the command, or
  `default_reported_type` (shadow unless fire gear is over the threshold).
- **Personal** — resistance from gear only.
- **Total** — personal plus the raid buff (`ResistanceRegistry.resolve`).
- `-` in Resistance/Personal/Total whenever there's no scan data for the player.

### Personal vs Total

The request described Personal as "the resistance value minus the raid buff".
The numbers are the same but the derivation is inverted in our data: the gear
scan reads item tooltips, so it is *already* buff-free. Therefore:

    Personal = gear scan result
    Total    = Personal + buff value

Nothing subtracts anything. Worth keeping this comment in the code so it doesn't
get "corrected" later into a subtraction that double-counts.

## What changes in existing code

`ResistanceCheck` currently formats and prints to chat. It becomes data-only:
it holds the cache, runs scans, and notifies listeners. The frame does all
rendering. Chat output goes away with `/rfres` becoming a GUI command.

Nothing else in `src/resistances/` changes — `GearScanner`, `BuffScanner`,
`Inspector`, `ResistanceParser` and `ResistanceRegistry` stay as they are.

## Files

| File | Status | Role |
|---|---|---|
| `src/resistances/ResistanceCheck.lua` | modify | cache + scan orchestration + listeners, no printing |
| `src/resistances/ResistanceFrame.lua` | new | popup construction, refresh, button wiring |
| `src/resistances/ResistanceFrameContentTransformer.lua` | new | data → line descriptors |
| `src/GuiElements.lua` | modify | new `resistance_row` widget |
| `main.lua` | modify | wire the frame, `/rfres` toggles it |
| `RollFor.toc`, `RollFor-BCC.toc` | modify | register the two new files |
| `test/utils.lua` | modify | register the two new files |

## Module APIs

### ResistanceCheck (modified)

```lua
---@class ResistanceRow
---@field player_name string
---@field class string?
---@field resistance_type ResistanceType?  -- nil when there's no data
---@field personal number?                 -- nil when there's no data
---@field total number?                    -- nil when there's no data
---@field scanning boolean

get_rows( resistance_type? )  -- one row per group member, roster order
scan( resistance_type? )      -- scans everyone without cached data
clear( player_name )
clear_all()
subscribe( listener )         -- called after every row change
```

`get_rows` merges the live group roster with the cache, so opening the frame
before any scan lists everyone with `-`. Buffs are read live inside `get_rows`,
not cached — same reason as today: they're free to read and change between
pulls.

### ResistanceFrame (new)

```lua
M.new( popup_builder, content_transformer, resistance_check, db )
  show() / hide() / toggle() / get_frame()
```

Mirrors `AutoLootFrame` exactly: `db.point` for position, `on_drag_stop` with
`m.is_frame_out_of_bounds`, `M.center_point` fallback, `popup:clear()` then
`popup.add_line(...)` per row in `refresh()`. Subscribes to `resistance_check`
and calls `refresh()` on notification, so scan results appear as they arrive.

### ResistanceFrameContentTransformer (new)

Same shape as `AutoLootFrameContentTransformer`: a `button_definitions` table
(`Scan`, `Clear`, `Close`) and a `transform( data )` returning a flat list of
line descriptors — title, header row, one `resistance_row` per player, buttons.
Pure data in, pure data out, no frames. This is the part that gets unit tested.

### GuiElements.resistance_row (new)

One container with a fixed width (the popup sizes itself from the widest line,
so this must be explicit), holding:

- a small `x` button on the left, `frame.on_clear` callback
- four `FontString` columns at fixed x offsets, `SetJustifyH` left for Player
  and Resistance, right for Personal and Total

Setters: `frame:SetRow( { name, resistance, personal, total } )` and
`frame:SetHeader( bool )` for the column-title row, which uses the same widget
so the columns line up.

## Behaviour

- **Open** — lists the group (or just you when solo), everything `-` until scanned.
  Cached players show their values immediately.
- **Scan** — scans every player without cached data. Rows show `...` while their
  inspect is in flight; the queue is serial with a 1.5s throttle, so a full raid
  fills in gradually rather than at once.
- **Clear** — `clear_all()`, all rows back to `-`. Does not scan.
- **x** — `clear( player_name )` for that row only. Does not scan.
- **Close** — hides the frame. Scanning in flight keeps running.
- **Failed inspect** (out of range, timeout) — row shows `-` and is not cached,
  so the next Scan retries it.

## Decisions taken

1. Scan respects the cache. Re-scanning a player means clearing them first,
   which is what the `x` and Clear buttons are for.
2. Rows follow roster order (class, then name), matching the rest of the addon.
3. Buffs stay uncached, gear stays cached.
4. `/rfres <school>` still works and pins the Resistance column to that school.

## Testing

Following the existing convention — transformers are unit tested, frames are
not (`AutoLootFrame` has no test, `OptionsFrameSpec_test` covers its transformer).

- `test/resistances/ResistanceCheck_test.lua` — rewrite the 11 existing tests
  against `get_rows` instead of chat output; add listener notification, the
  `scanning` flag, and `-`/nil for unscanned players.
- `test/resistances/ResistanceFrameContentTransformer_test.lua` — new: title,
  header, one line per row, `-` rendering, button definitions, callbacks wired.

## Implementation order

1. `ResistanceCheck`: strip printing, add `get_rows` / `subscribe` / `scanning`.
   Rewrite its tests. Everything still works headless at this point.
2. `ResistanceFrameContentTransformer` + tests. Still no frames involved.
3. `GuiElements.resistance_row`.
4. `ResistanceFrame`, copied from `AutoLootFrame` and adapted.
5. Wire in `main.lua`, both TOCs, `test/utils.lua`. `/rfres` toggles the frame.

## Risks

- **Column alignment** — the popup centers most line types and left-anchors tree
  rows via a second anchor point (`AutoLootFrame.lua`, the `SetPoint( "LEFT" )`
  branch). Rows here need the same treatment or the columns will drift per row.
- **Frame reuse** — `FrameBuilder` caches line frames per `line_type` and reuses
  them across refreshes, so `SetRow` must overwrite every field, including
  clearing state from a previous row. A partially-set row shows stale data.
- **Refresh churn** — every scan completion refreshes the whole list. Fine for
  40 rows; if it flickers, switch to updating the single changed row.
