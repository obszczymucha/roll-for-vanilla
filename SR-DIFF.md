# SR-DIFF: RollForSoftResIt vs RollForRaidRes

Analysis of the two soft-res source extensions, with an assessment of whether a common
soft-res implementation can be extracted so that only the *data provider* stays per-addon.

Compared trees:

- `$HOME/.projects/lua/wow-2.5.x-addons.git/master/RollForSoftResIt`
- `$HOME/.projects/lua/wow-2.5.x-addons.git/master/RollForRaidRes`

against core at `$HOME/.projects/lua/roll-for-vanilla/extensions/RollFor`
(addons repo at `5ebb105a Add RollForRaidRes.`, 2026-09-10).

---

## 1. Verdict at a glance

The two addons are the same program twice. Of **1892 lines of `src/`**, **38 lines**
differ once the two-line namespace header of each file is discounted -- and **22 of those
38 are in `Decoder.lua`**, which is the only file with a behavioural difference. The
remaining 16 are display strings, global frame names and an event payload literal.

| Layer | Lines | Divergent (excl. namespace header) | Nature of the divergence |
|---|---:|---:|---|
| `src/Decoder.lua` | 59 | 22 | **Real**: zlib layer present/absent |
| `src/OptionsPage.lua` | 142 | 6 | Summary prose, popup frame name |
| `src/SoftResGui.lua` | 373 | 6 | Window title label, global frame name (x2) |
| `src/SoftResCheck.lua` | 270 | 2 | `source = "..."` in one event payload |
| `src/SoftResStore.lua` | 150 | 2 | One comment |
| Other 10 `src/` files | 898 | 0 | Identical |
| **`src/` total** | **1892** | **38** | |
| Main file (`RollForX.lua`) | 294 / 235 | 75 | Identity strings + the SoftResIt-only migration block |
| `test/` (23 + 22 files) | ~11.7k | ~50 | Identity strings; one unique suite each |

Ten of the fifteen `src/` files -- including everything that implements the actual
soft-res rules (`SoftResDataTransformer`, the four decorators, `NameAutoMatcher`,
`NameManualMatcher`, `NameMatchReport`, `Simulation`, `Minimap`) -- are **byte-identical
apart from `RollForSoftResIt` vs `RollForRaidRes` on lines 1-2**.

---

## 2. File inventory

### Identical (modulo the 2-line namespace header)

```
src/Minimap.lua                       src/SoftResAbsentPlayersDecorator.lua
src/NameAutoMatcher.lua               src/SoftResAwardedLootDecorator.lua
src/NameManualMatcher.lua             src/SoftResMatchedNameDecorator.lua
src/NameMatchReport.lua               src/SoftResPresentPlayersDecorator.lua
src/Simulation.lua                    src/SoftResDataTransformer.lua
```

### Identical byte-for-byte (no namespace header at all)

```
.editorconfig  .luarc.json  test.sh
test/luaunit.lua  test/mocking.lua  test/gui_helpers.lua
test/mocks/*  (19 files)
test/DroppedLootAnnounce_test.lua        test/DroppedLootAnnounce_integration_test.lua
test/NameAutoMatcher_test.lua            test/PreviewAwardedLootSpec_test.lua
test/RollSimulator_test.lua              test/SoftResAwardedLootDecorator_test.lua
test/SoftResCheckTimestampSpec_test.lua  test/SoftResDataTransformer_test.lua
test/SoftResRollSpec_test.lua            test/SoftResStore_test.lua
test/softres_rolls_test.lua
```

### Differing

```
src/Decoder.lua        src/OptionsPage.lua   src/SoftResGui.lua
src/SoftResCheck.lua   src/SoftResStore.lua  README.md
RollForSoftResIt.lua / RollForRaidRes.lua    (+ the matching .toc)
test/AwardedLootFactoryTiming_test.lua  test/ExtensionRegistration_test.lua
test/FullLoad_test.lua                  test/IntegrationTestBuilder.lua
test/OptionsPage_test.lua               test/SoftResCheckedEvent_test.lua
test/utils.lua
```

### Present in only one addon

| Only in `RollForSoftResIt` | Only in `RollForRaidRes` |
|---|---|
| `test/Migration_test.lua` (128 lines) | `test/Decoder_test.lua` (78 lines) |
| 10 softres.it fixtures (`sr-*.json`, `sr-*.zlib.base64`, `softres-*.txt`, `princess-kenny.txt`) | `test/fixtures/raidres.json`, `raidres.txt`, `softres-it.zlib.base64` |

Note the asymmetry: **SoftResIt has no `Decoder_test`** -- there is no suite anywhere
asserting that a real softres.it string decodes. RaidRes has one, including a negative
case proving a softres.it string does *not* decode there.

---

## 3. The differences, in full

### 3.1 The namespace (all 15 `src/` files + main)

```lua
-RollForSoftResIt = RollForSoftResIt or {}
-local sr = RollForSoftResIt
+RollForRaidRes = RollForRaidRes or {}
+local sr = RollForRaidRes
```

That is the entire difference in 10 of 15 `src/` files. `sr` is a per-addon module table
(the `if sr.X then return end` load guard, plus `sr.X = M` at the bottom); `m = RollFor`
is core and is shared already.

### 3.2 `src/Decoder.lua` -- the only behavioural difference

**SoftResIt:** `base64 -> LibDeflate:DecompressZlib -> Json.decode`

```lua
data = lib_stub( "LibDeflate" ):DecompressZlib( data )

if not data then
  m.pretty_print( "Couldn't decompress softres data!", m.colors.red )
  return nil
end
```

**RaidRes:** `base64 -> Json.decode`. The seven lines above are absent; everything else in
the function is identical. RaidRes's file comment states the consequence is intended: a
softres.it string decodes as base64, fails to parse as JSON, and is reported as unloadable.

Both files carry the same three example base64 comment blocks (all three are, in fact,
`"origin":"raidres"` payloads -- leftovers in the SoftResIt copy).

`LibDeflate` lives in **core's** `RollFor/libs`, not in the extension, so the extension
reaches it through `LibStub` rather than shipping it.

### 3.3 Identity strings

Same value in six places per addon; `softres_it` / `SoftRes (softres.it)` vs
`raidres` / `SoftRes (raidres)`:

| Where | SoftResIt | RaidRes |
|---|---|---|
| `Extensions.register{ name = }` | `softres_it` | `raidres` |
| `Extensions.register{ title = }` / `softres_source.register{ title = }` | `SoftRes (softres.it)` | `SoftRes (raidres)` |
| `softres_source.register{ id = }` | `softres_it` | `raidres` |
| `event_bus.notify( "softres_cleared", { source = } )` | `softres_it` | `raidres` |
| `event_bus.notify( "softres_imported", { source = } )` | `softres_it` | `raidres` |
| `SoftResCheck` → `notify( "softres_checked", { source = } )` | `softres_it` | `raidres` |
| `.toc` `X-RollFor-Extension` | `softres_it` | `raidres` |
| derived db keys | `extension_softres_it_*` | `extension_raidres_*` |

Of these, the three `source` payload fields are **written but never read** -- core's two
handlers (`RollFor/main.lua:734,746`) and `RollForBtSrLimitCheck`'s three subscriptions
ignore the field entirely. Only `event.interactive` and `event.raw` are consumed.

### 3.4 Global frame names and UI text

| Where | SoftResIt | RaidRes |
|---|---|---|
| `SoftResGui` main frame (also `UISpecialFrames`) | `RollForSoftResLootFrame` | `RollForRaidResLootFrame` |
| `SoftResGui` corner label | `"    softres.it"` (note leading spaces) | `"raidres.top"` |
| `OptionsPage` popup name | `RollForSoftResItOptionsPage` | `RollForRaidResOptionsPage` |
| `OptionsPage` SUMMARY line 1 | "…from softres.it and raidres.fyi…" | "…from raidres.top…" |

These are `_G` names: two copies of the addon loaded at once would each create their own
frame, so the names must stay distinct per provider (or be derived from the provider id).

### 3.5 The migration block (SoftResIt only)

`RollForSoftResIt.lua:26-85` -- ~60 lines with no counterpart in RaidRes:

- `MIGRATION` table: `softres` → `extension_softres_it_softres`,
  `name_matcher` → `extension_softres_it_name_matcher`
- `deep_copy`, `is_empty`, `migrate_from_core( ctx )`, called first in `on_enable`
- Copies (does not move) out of `RollForCharDb` on first run, guarded by
  `ctx.db( "migration" ).migrated_from_core`

This is a one-off: the soft-res import used to live in core, so SoftResIt has to adopt the
existing user's data. RaidRes has nothing to adopt (a softres.it list is unreadable to it)
and its README says so explicitly.

### 3.6 `.toc`

Identical structure, identical file list in identical order. Differences: `Title`,
`Notes`, `X-RollFor-Extension`, and the final main-file line. Both are
`## Interface: 20506`, `## Dependencies: RollFor`, `## Version: 1.0`, and both borrow
core's icon (`Interface\AddOns\RollFor\assets\icon-white`).

### 3.7 Tests

The divergence in the shared suites is mechanical: `RollForSoftResIt` → `RollForRaidRes`,
`softres_it` → `raidres`, `extension_softres_it_%s` → `extension_raidres_%s`,
`RollForSoftResLootFrame` → `RollForRaidResLootFrame`, and
`builder.without_softres_it` → `builder.without_raidres`.

`test/utils.lua` (1531 lines) and `test/IntegrationTestBuilder.lua` (486) are wholesale
copies of core's harness with `-- EXTENSION:` marked patches, duplicated a third time here.

---

## 4. Where the data shapes actually differ

This is the crux for the "provider" question. The two sites' JSON is **near-identical**,
and the parts that differ are parts nothing reads.

softres.it export:

```json
{ "metadata": { "id": "t5uf54", "instance": "kara", "createdAt": 1694249012,
                "updatedAt": …, "raidStartsAt": null, "hidden": false,
                "discordUrl": "", "note": "" },
  "softreserves": [ { "name": "Ohhaimark", "class": "warrior", "note": "",
                      "plusOnes": 0, "rollBonus": 0,
                      "items": [ { "id": 28749, "note": "", "order": 0 } ] } ],
  "hardreserves": [ { "id": 40632, "for": "Rur", "note": "" } ] }
```

raidres export:

```json
{ "metadata": { "id": "GQZDMQ", "instance": 209,
                "instances": [ "Black Temple" ], "origin": "raidres" },
  "softreserves": [ { "name": "Boulderdash", "role": "WarriorProtection",
                      "items": [ { "id": 32241, "quality": 4 } ] } ],
  "hardreserves": [] }
```

| Field | softres.it | raidres | Read by the addon? |
|---|---|---|---|
| `softreserves[].name` | yes | yes | **yes** -- the roller name |
| `softreserves[].items[].id` | yes | yes | **yes** -- the item id |
| duplicate item entries = extra rolls | yes | yes | **yes** -- counted in the transformer |
| `hardreserves[].id` | yes | yes | **yes** |
| `softreserves[].items[].quality` | absent | yes | written into the store, **never read** |
| `hardreserves[].quality` | absent | yes | written into the store, **never read** |
| `metadata.*` | different shapes | different shapes | **no** |
| `class` / `role` / `note` / `order` / `plusOnes` / `rollBonus` / `for` | partly | partly | **no** |

`SoftResDataTransformer.lua` is identical in both addons, is annotated entirely in
`RaidRes*` types, and works unchanged on softres.it data because it only touches `name`,
`items[].id` and `hardreserves[].id`. The `quality` it copies is dead weight: grep shows
it is written by the transformer and read nowhere in either addon or in core.

`Simulation.lua` (identical in both) fabricates a **raidres-shaped** document
(`metadata = { id = "SIM", …, origin = "raidres" }`) and feeds it to `store.import` in
both addons -- the simulator has already been provider-neutral by accident.

`test/utils.lua`'s `create_softres_data` also builds raidres-shaped documents, and the
entire shared rolling corpus runs against them in both addons.

**Conclusion: the wire format differs by exactly one transform -- the zlib layer.** The
decoded document shape is, for everything the addon consumes, the same.

---

## 5. Constraints any extraction has to respect

1. **`SoftResSource` accepts exactly one registration** (`RollFor/src/SoftResSource.lua:54`).
   A second is refused with an error. Today that makes the two addons mutually exclusive,
   which RaidRes's README documents ("addons load alphabetically and this one wins").
2. **Addons load alphabetically; TOC `## Dependencies:` is the only ordering lever.**
   Extension registration happens at file scope, which is safe *only* because
   `## Dependencies: RollFor` forces core first. A shared-library addon would need
   `## Dependencies: RollFor, RollForSoftRes` in each provider.
3. **The extension registry keys everything by extension `name`**, including db scoping:
   `ctx.db( key )` resolves to `RollForCharDb.extension_<name>_<key>`
   (`RollFor/main.lua:303`). Change the extension name and the user's saved list moves.
   `Db` migrations (`RollFor/src/Db.lua:52`) run *inside* a store; they cannot rename the
   store's key, so a name change needs the same copy-out-of-the-old-key dance
   `RollForSoftResIt.lua` already performs.
4. **The extension's own version is read from its TOC** via `X-RollFor-Extension`
   (`RollFor/src/Extensions.lua:M.version`), matching on extension name.
5. **Global frame names** (`RollForSoftResLootFrame`, the options popup) must stay unique
   per loaded addon.
6. **Chain anchor names are public API**: `matched_name`, `awarded_loot`,
   `present_players` and the `unfiltered` tap are what *other* extensions attach to.
   `RollForNetherVortex` declares `after = "awarded_loot", before = "present_players"`;
   `RollForBtSrLimitCheck` reads `ctx.softres_tap( "unfiltered" )` and subscribes to all
   three `softres_*` events. Whoever declares those anchors must keep the names.
7. **Both declare `api_version = 2`** while core is at `API_VERSION = 3`.
8. **`LibDeflate` is core's**, reached through `LibStub` -- a zlib provider does not have
   to ship it.

---

## 6. Assessment: can a common SoftRes be extracted?

**Yes, and the split is unusually clean.** Everything except `Decoder.lua` and a handful
of identity strings is already common code that happens to be stored twice. The provider's
entire job is:

```lua
---@class SoftResProvider
---@field id string             -- "softres_it" | "raidres"; db scope, event source, extension name
---@field title string          -- "SoftRes (softres.it)"
---@field website string        -- label in the import window: "softres.it"
---@field summary string        -- OptionsPage prose
---@field decode fun( encoded: string? ): table?  -- the wire format, and nothing else
---@field migrations DbMigration[]?               -- optional, provider-owned
```

Everything else -- store, transformer, four decorators, name matching, the import window,
`/sr` `/src` `/srs` `/sro`, the minimap contribution, the simulation bridge, the options
page, the chain links and the tap -- is identical today and becomes shared.

Frame names derive from `id` (`"RollFor" .. id .. "LootFrame"`), which also fixes the
current inconsistency where SoftResIt's frame is called `RollForSoftResLootFrame` (no
"It").

### Option A -- shared code moves into a `RollForSoftRes` library addon

Providers become ~60-line addons: a TOC, a `decode` function, four strings.

- `+` One copy of 1892 lines and one copy of the ~11.7k-line test harness.
- `+` Providers are genuinely trivial; a third site is an afternoon.
- `+` The library can own the "only one source may be active" arbitration properly:
  register providers with *it*, let the user pick one on the options page, and register
  exactly one with core's `SoftResSource`. That turns today's alphabetical accident into a
  setting.
- `−` A third addon in the install instructions, plus `## Dependencies: RollFor, RollForSoftRes`.
- `−` The shared addon needs its own extension identity for the options page and db
  scoping; the *provider's* data must key off the provider id, not the library's, or
  switching providers loses lists. Practically: the library holds a store per provider id.
- `−` The extension registry currently gives one options page per registered extension. A
  library that owns the UI either registers itself as the extension (and the providers
  register only with it, not with core) or the page has to host a provider picker.
  The former is cleaner and is what the "arbitration" bullet above assumes.

### Option B -- shared code moves back into core `RollFor`

Providers register `{ id, title, website, summary, decode }` with core.

- `+` No third addon; installation is core + one provider.
- `+` `SoftResSource` already exists as the seam; it grows from "give me a store" to
  "give me a decoder" and core builds the store.
- `−` Reverses the whole point of `SR-EXTENSION.md`: core deliberately shed the store, the
  GUI, the name matcher and the slash commands so that RollFor without a soft-res addon is
  a clean roller. Putting 1892 lines back makes "no soft-res source installed" a lie --
  the window, the commands and the db keys would all still be there.
- `−` Core cannot then be shipped without soft-res.

### Option C -- keep two addons, generate one from the other

A build step that renames `RollForSoftResIt` → `RollForRaidRes` and swaps `Decoder.lua`.

- `+` Zero runtime change, zero migration risk, zero new load-order concerns.
- `−` Does not reduce what ships; two addons still cannot coexist.
- `−` Diverging deliberately (a provider-specific quirk) becomes a fight with the generator.
- `−` The duplicated test harness is duplicated in the repo either way.

### Recommendation

**Option A**, with the provider interface above. It is the only option that removes the
duplication *and* answers the question the duplication created -- what happens when a user
installs both. Core's `SoftResSource` singleton stays exactly as it is; the library is the
one thing that registers with it.

If the appetite for a third addon is low, **Option C is a legitimate stopgap** -- but note
it leaves the mutual exclusivity unsolved and leaves SoftResIt without a decoder test.

---

## 7. Concrete work items implied by Option A

1. New addon `RollForSoftRes`: the 15 `src/` files minus `Decoder.lua`, namespaced once.
2. Provider registry inside it (`RollForSoftRes.Providers.register( spec )`), plus the
   picker on its options page when more than one is installed.
3. `RollForSoftResIt` / `RollForRaidRes` shrink to a TOC + `Decoder.lua` + a registration
   call. `## Dependencies: RollFor, RollForSoftRes`.
4. Frame names derived from provider id; keep `RollForSoftResLootFrame` as-is for the
   softres.it provider if any user macro or `UISpecialFrames` habit depends on it.
5. **Db keys**: the library's `ctx.db( "softres" )` resolves under *its* extension name.
   Existing users hold data under `extension_softres_it_softres` and
   `extension_softres_it_name_matcher`. A one-off copy (the same shape as
   `migrate_from_core`) is needed, and `RollForSoftResIt`'s existing core→extension
   migration has to keep working for anyone upgrading from a pre-extension RollFor.
6. Move `test/utils.lua` + `IntegrationTestBuilder.lua` + `mocks/` to the library; the
   provider addons need only a decoder test each.
7. Add the missing softres.it `Decoder_test` while the fixtures are being moved --
   `sr-ohhaimark.zlib.base64` and `sr-ohhaimark.json` are already a matched pair.
8. Decide whether `quality` stays in the transformer. Nothing reads it; if it is kept, the
   `RaidRes*` type annotations in `SoftResDataTransformer.lua` should be renamed to
   provider-neutral ones, since that file is the shared contract, not a raidres one.
9. Bump `api_version` to 3 (or confirm 2 is still what the code is written against).

---

## 8. Open questions

- Should both providers be installable and switchable at runtime, or is "one installed at
  a time" acceptable? Option A's value is much higher if the answer is switchable.
- Is `metadata.origin` worth reading? It would let a single decoder identify which site
  produced a document after decoding, which is a cheaper answer than a provider picker --
  though it does not help with the zlib layer, which must be decided *before* parsing.
  (A single decoder could sniff: zlib header → inflate, `{"` → parse directly. That
  collapses both providers into one addon entirely, at the cost of the deliberate
  "raidres cannot read softres.it strings" behaviour RaidRes documents.)
- ~~Does anything consume the `softres_imported` / `softres_cleared` / `softres_checked`
  `source` field?~~ **No** -- checked core and all four sibling extensions; the field is
  written and never read. It is free to become the provider id, the library name, or to be
  dropped. `event.interactive` and `event.raw` *are* consumed and must not change.
