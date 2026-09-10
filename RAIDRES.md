# RollForRaidRes

A second soft-res source extension for RollFor, importing lists from **raidres.top**.

Functionally identical to `RollForSoftResIt` — same window, same commands, same minimap
contribution, same name matching, same options page. The two are **mutually exclusive**:
core's `SoftResSource` accepts exactly one registration and refuses the second with an
error, so whichever addon loads first wins and the other goes quiet.

This document is the change summary. No code has been written yet.

---

## 1. Decisions taken

Decided by the addon author. Do not relitigate them in code.

| Question | Decision |
|---|---|
| What it is | A full, standalone copy of `RollForSoftResIt` with the raidres deltas applied |
| Duplication | **Deliberate.** Nothing is extracted, shared or refactored across the two addons. No "SR core" module, no shared library, no common base |
| Where it lives | `RollForRaidRes/` in `~/.projects/lua/wow-2.5.x-addons.git/master`, alongside `RollFor` and `RollForSoftResIt`. Its own release |
| Folder / global / id / title | `RollForRaidRes` / `RollForRaidRes` / `raidres` / `SoftRes (raidres)` |
| Wire format | Base64 → JSON. **No zlib.** |
| Site shown in the import window | `raidres.top` |
| Item quality from the payload | **Dropped.** See §3.3 |
| Existing saved data | **Starts empty.** No migration from core, none from RollForSoftResIt |
| Slash commands | The same `/sr`, `/sro`, `/src`, `/srs`. Duplicates are refused harmlessly — see §5.2 |
| Tests | Full copy of the vendored suite, adapted |
| Changes to RollFor core | **None.** |

---

## 2. Provenance — where "the RaidRes implementation" actually is

There has never been a `RollForRaidRes` addon. A search of both repositories — every
branch, tag, the reflog and all dangling objects — turns up no source file named for
raidres in either `roll-for-vanilla` or `wow-2.5.x-addons.git`. The only files ever
committed under that name are `docs/raidres-export.jpg` and
`docs/raidres-copy-to-clipboard.jpg`.

What *was* removed is the **vanilla (1.12) client's soft-res path**, in commit
`4a4d0be` — *"Remove 1.12 client support. RIP."* RollFor supported two sites, one per
client: raidres on 1.12, softres.it on BCC. Deleting the 1.12 build deleted raidres with
it. That commit's own README diff says so:

> `-1. Create a Soft Res list at https://raidres.fly.dev (1.12.1) or https://softres.it (2.5.2).`
> `-3. When ready, lock the raid and click on RollFor export (raidres.fly.dev) or Gargul Export (softres.it) button.`
> `-The SR data from *Raidres* is a **Base64** encoded **JSON**. Decode it to see what's inside.`

The raidres-specific code in that commit is exactly three things:

1. **`SoftRes.lua:81`** — `if m.bcc then data = LibStub("LibDeflate"):DecompressZlib(data) ... end`.
   Raidres never went through zlib.
2. **`SoftResGui.lua:208`** — `local sr_website = m.vanilla and "raidres.fly.dev" or "    softres.it"`.
3. **`SoftRes.lua:185`** — `get_item_quality`, reading `quality` off the raidres payload.

`m.vanilla` / `m.bcc` appear nowhere else in any `SoftRes*` file at `4a4d0be^`, so that is
the complete raidres surface. Everything else was already shared between the two sites and
is what `RollForSoftResIt` is today.

### 2.1 The format, confirmed against a live export

`raidres.txt` at the repo root is a current export from raidres.top. It decodes with
`base64 -d` alone — no decompression step:

```json
{
  "metadata": { "id": "GQZDMQ", "instance": 209, "instances": [ "Black Temple" ], "origin": "raidres" },
  "softreserves": [
    { "name": "Boulderdash", "role": "WarriorProtection",
      "items": [ { "id": 32241, "quality": 4 }, { "id": 32232, "quality": 4 }, { "id": 32236, "quality": 4 } ] }
  ],
  "hardreserves": []
}
```

The two formats are distinguishable by their first decoded byte and are mutually
unreadable:

| | first bytes after base64 | meaning |
| --- | --- | --- |
| raidres.top | `7b 22` | `{"` — JSON, ready to parse |
| softres.it | `78 9c` | zlib header — must be inflated first |

This is the same shape the removed 1.12 code read, and the same shape the three sample
strings still sitting in `RollForSoftResIt/src/Decoder.lua` carry. The `RaidResData`
typedefs already in `SoftResDataTransformer.lua` — `instance` a number, `instances` an
array of names, `origin` the literal `"raidres"` — describe this payload exactly.

**New since the 1.12 era:** softreserve entries now carry a `role`
(`"WarriorProtection"` — class and spec in one string). The old format had `name` and
`items` and nothing else.

Nothing reads it. The transformer takes only `softreserves[].name`,
`softreserves[].items[].id` and `hardreserves[].id`, and ignores everything else on both
sides — raidres' `role` and per-item `quality`, softres.it's `class`, `note`, `rollBonus`,
`plusOnes` and per-item `note`/`order`. So **no transformer change is needed**, and `role`
is not a reason to grow the normalized model.

---

## 3. What differs from RollForSoftResIt

The entire behavioural delta is four items. Everything else is a rename.

### 3.1 The decoder — the only real logic change

`src/Decoder.lua` loses the decompression step:

```lua
local data = m.decode_base64( encoded_softres_data )
if not data then
  m.pretty_print( "Couldn't decode softres data!", m.colors.red )
  return nil
end

-- (RollForSoftResIt does base64 -> zlib -> JSON here. Raidres exports plain base64 JSON,
--  so there is nothing to decompress.)

local json = lib_stub( "Json-0.1.2" )
local success, result = pcall( function() return json.decode( data ) end )
if not success then return nil end
return result
```

Consequence, and it is intended: a **softres.it string pasted into the raidres window
fails to load**. It is valid base64, so `decode_base64` succeeds and hands back zlib
bytes; `json.decode` then fails inside the `pcall` and `decode` returns nil. The message
the user sees is **"Could not load soft-res data!"** from `RollForRaidRes.lua`, not
`Decoder`'s own "Couldn't decode softres data!" — that one is reachable only when the
paste is not valid base64 at all.

This also drops the `LibStub("LibDeflate")` dependency from the file. The `lib_stub` local
at the top of `Decoder.lua` goes with it — nothing else in the file uses it.

The three raidres sample strings currently in `RollForSoftResIt/src/Decoder.lua` are
carried over as-is. They belong here: they are raidres exports, and in the new addon they
actually decode.

### 3.2 The site label

`src/SoftResGui.lua` — the bottom-left line of the import window:

```lua
local sr_website = "raidres.top"
```

against RollForSoftResIt's `"    softres.it"`. The leading spaces there are hand-kerning
for that particular string and are not carried over.

### 3.3 Item quality — dropped, not restored

The removed vanilla code exposed `softres.get_item_quality( item_id )` off the raidres
payload's `quality` field. It is **not** being restored, because on BCC it is dead code.
The trace closes completely:

- `softres_data[id].quality` had exactly one reader: `get_item_quality` (`SoftRes.lua:186`).
- `get_item_quality` had exactly two callers — `SoftResCheck.lua:102` and `:156` — both
  passing it straight into `m.fetch_item_link( item_id, quality )`.
- `fetch_item_link` touched `quality` only inside `if M.vanilla then`, where it built the
  hyperlink by hand: `ITEM_QUALITY_COLORS[quality].hex .. "|H" .. details .. "|h[" .. name .. "]|h|r"`.
- `hardres_data[id].quality` was written by the transformer and read by **nothing at all**.

The wrapping existed because 1.12's `GetItemInfo` returned the bare `item:12345:0:0:0`
string as its second value. On BCC that second value is already a complete coloured
hyperlink — confirmed against the reference client, where `local _, link =
C_Item.GetItemInfo(id)` is used directly as a link. Reapplying the vanilla formatting
would double-wrap and produce a broken link.

So `SoftResCheck` keeps `m.fetch_item_link( item_id )` exactly as it stands, the store
exposes the same six read methods, and **`RollFor/src/modules.lua` is not touched**. The
transformer still *writes* `quality` into its output — it does so today in
RollForSoftResIt too, harmlessly — so this is a decision not to add a reader, not a
removal.

### 3.4 No migration

`RollForSoftResIt.lua` carries a `MIGRATION` table and `migrate_from_core()` that copy
`RollForCharDb.softres` and `.name_matcher` into its own keys on first run. **All of that
is deleted**, along with the `deep_copy` / `is_empty` helpers that exist only to serve it
and the `char_db` local. `on_enable` starts with `store = ...`.

Rationale: core's `softres` key holds a softres.it list, which this addon cannot read.
There is nothing to inherit. A raidres user pastes their string once.

`ctx.db( "migration" )` is no longer used. `Migration_test.lua` is dropped (§4.2).

---

## 4. File manifest

### 4.1 Addon files

`RollForRaidRes/` — 16 Lua files, ~2200 lines, all copied from `RollForSoftResIt`.

Every file's first two lines change from

```lua
RollForSoftResIt = RollForSoftResIt or {}
local sr = RollForSoftResIt
```

to the `RollForRaidRes` equivalent. Beyond that:

| File | Lines | Change beyond the namespace rename |
| --- | --- | --- |
| `RollForRaidRes.lua` | 294 | id/title → `raidres` / `SoftRes (raidres)`; `source = "raidres"` on the `softres_cleared` and `softres_imported` events; `m.warn(..., "RollForRaidRes")`; **migration block deleted** (§3.4) |
| `src/Decoder.lua` | 59 | **No zlib** (§3.1); `lib_stub` local removed; header comment rewritten for raidres |
| `src/SoftResGui.lua` | 373 | `sr_website = "raidres.top"`; frame name `RollForSoftResLootFrame` → `RollForRaidResLootFrame`, in both `create_backdrop_frame` (line 39) and the `UISpecialFrames` insert (line 216) |
| `src/SoftResCheck.lua` | 270 | `event_bus.notify( "softres_checked", { source = "raidres" } )` |
| `src/OptionsPage.lua` | 142 | `SUMMARY` prose rewritten for raidres; popup name → `RollForRaidResOptionsPage` |
| `src/SoftResDataTransformer.lua` | 103 | none (the `RaidResData` typedefs it already carries are, finally, accurate) |
| `src/SoftResStore.lua` | 150 | none |
| `src/Simulation.lua` | 86 | none — its fake payload is already `origin = "raidres"` |
| `src/Minimap.lua` | 68 | none |
| `src/NameAutoMatcher.lua` | 266 | none |
| `src/NameManualMatcher.lua` | 166 | none |
| `src/NameMatchReport.lua` | 36 | none |
| `src/SoftResAbsentPlayersDecorator.lua` | 37 | none |
| `src/SoftResAwardedLootDecorator.lua` | 44 | none |
| `src/SoftResMatchedNameDecorator.lua` | 45 | none |
| `src/SoftResPresentPlayersDecorator.lua` | 47 | none |

Plus `README.md` (rewritten for raidres), `.editorconfig`, `.luarc.json`, `test.sh` —
copied.

The **chain link names stay `matched_name`, `awarded_loot`, `present_players`** and the
tap stays `unfiltered`. These are the anchors `RollForNetherVortex` positions itself
against; renaming one would break that addon. Only one source is ever live, so there is no
collision.

### 4.2 TOC

`RollForRaidRes.toc`, same shape as RollForSoftResIt's, file order unchanged:

```
## Interface: 20506
## Title: RollFor - SoftRes (raidres)
## Author: Obszczymucha
## Version: 1.0
## Notes: raidres soft-res import for RollFor.
## Dependencies: RollFor
## IconTexture: Interface\AddOns\RollFor\assets\icon-white
## X-RollFor-Extension: raidres
```

`X-RollFor-Extension` must equal the registered name — `Extensions.lua:291` matches on it
to find the addon's own metadata.

`api_version = 2` is declared, matching RollForSoftResIt. Core is at `API_VERSION = 3`;
claiming 2 is honest (this addon uses only the v2 context surface) and safe (core rejects
`> API_VERSION`, never `<`).

### 4.3 Tests

Full copy of the vendored suite into `RollForRaidRes/test/` — 18 suites, `test/mocks/`
(19 files), `gui_helpers.lua`, `luaunit.lua`, `mocking.lua`, `utils.lua`, `test.sh`.
Roughly 10,500 lines.

`test/utils.lua` resolves core as a sibling via
`../../RollFor/?.lua`, so the harness works unchanged from `RollForRaidRes/test/`.

Adaptations:

- `test/utils.lua` — `require( "RollForRaidRes" )` in `load_real_stuff`; the
  `source.id == "softres_it"` branch in `import_soft_res` becomes `"raidres"`.
- Eleven suites assert on the `softres_it` id or the addon global and get the same
  mechanical rename: `AwardedLootFactoryTiming`, `DroppedLootAnnounce`,
  `ExtensionRegistration`, `FullLoad`, `IntegrationTestBuilder`, `OptionsPage`,
  `SoftResAwardedLootDecorator`, `SoftResCheckedEvent`, `SoftResStore`, `softres_rolls`.
- **`Migration_test.lua` is dropped** (128 lines). There is no migration to test.
- A new decoder suite asserts the raidres contract directly, built on the real export in
  `raidres.txt`: that string decodes to the expected item ids, and a zlib-compressed
  softres.it string does **not** decode. Nothing covers this today — no existing test
  touches `Decoder` or the `test/fixtures/` files at all.
- `test/fixtures/` — the seven files there are inert (no suite reads them). Replaced with
  raidres-shaped equivalents, `raidres.txt` among them, so the fixtures document this
  addon's format rather than the other one's.

---

## 5. Consequences worth stating

### 5.1 Other extensions keep working

`RollForBtSrLimitCheck` subscribes to `softres_checked`, `softres_imported` and
`softres_cleared`, and `RollFor/main.lua` subscribes to the latter two. **None of them
reads `event.source`** — they branch on `event.interactive` only. So changing the source
string to `"raidres"` breaks nothing, and the BT limit check works against RaidRes exactly
as it does against SoftResIt.

`RollForNetherVortex` anchors to chain link names, which are unchanged (§4.1).

### 5.2 Both addons installed at once

Not prevented, and not made to fail loudly. Addons load alphabetically, so `RollForRaidRes`
registers its source first and `RollForSoftResIt`'s registration is refused with
`Soft-res source raidres is already registered, ignoring softres_it.` — core's existing
error, no new code.

The loser still tries to register `/sr`, `/sro`, `/src`, `/srs`. `m.slash_cmd`
(`modules.lua:230`) already refuses a duplicate with a `dbg` line and returns, so nothing
throws — the commands simply stay bound to the winner. Both addons appear in the options
window, each with its own Enabled checkbox, which is how a user turns the unwanted one off.

### 5.3 Not in scope

- Any change to `RollFor` core. §3.3 is the reason the one candidate change went away.
- Any change to `RollForSoftResIt`, `RollForNetherVortex`, or `RollForBtSrLimitCheck`.
- Extracting anything shared between the two soft-res addons.
- Reading `class`, `note`, `rollBonus` or `plusOnes` from either payload.
- Merging data from two sources.

---

## 6. Open items

None. Both questions this document opened with are closed by `raidres.txt`: the export is
plain base64 JSON, and it comes from raidres.top.

The one thing worth a second look at review time is `role` (§2.1) — it is ignored by
design, but it is the only field raidres has gained since the code was removed, and it is
the only place this addon could later diverge from RollForSoftResIt on data rather than on
wire format.
