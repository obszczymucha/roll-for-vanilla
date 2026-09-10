# PLAN: shared SoftRes + providers, and the return of SR+

This file is the **driver**. It says what to do, in what order, and how to know each step
worked. It does not argue for the design -- two companion documents do that, and they are
the reference when a step is unclear:

- **[SR-DIFF.md](SR-DIFF.md)** -- why `RollForSoftResIt` and `RollForRaidRes` are the same
  program twice, what a provider is, and the decided design for the import window (§7).
- **[SR-PLUS.md](SR-PLUS.md)** -- what the removed SR+ feature was, how it worked, the two
  reproduced bugs in it, and the `roll_modifiers` seam that brings it back (§10).

Read those before starting. Do not re-derive their conclusions; they are settled.

---

## 0. Orientation

### The two pieces of work

| | What | Driver doc | Blocked on |
|---|---|---|---|
| **A** | Extract shared soft-res code into a `RollForSoftRes` addon; providers become decoders | SR-DIFF | nothing |
| **B** | Bring SR+ back on a general roll-modifier seam | SR-PLUS | a product decision (§2) |

**They are independent.** A touches the addons repo, B touches core. Do A first: it is
mechanical, well covered by existing tests, and fixes two live bugs. The only coupling is
`Extensions.API_VERSION`, handled in Phase 7.

### Repos and paths

| | Path | Branch |
|---|---|---|
| Core (`RollFor`) | `~/.projects/lua/roll-for-vanilla/extensions` | `extensions` |
| Addons (extensions live here) | `~/.projects/lua/wow-2.5.x-addons.git/master` | `master` |

Core is developed in the first, then **synced** into the second, which is the tree the
extension suites run against.

### Commands

```bash
# Core: 51 suites
cd ~/.projects/lua/roll-for-vanilla/extensions && ./test.sh

# Sync core into the addons tree. MUST run after any core change, before extension suites.
# Use rsync directly: sync-bcc.sh syncs and then blocks on inotifywait, which will hang you.
cd ~/.projects/lua/roll-for-vanilla/extensions && rsync -ah RollFor ~/.projects/lua/wow-2.5.x-addons.git/master

# Each extension: 17 suites today
cd ~/.projects/lua/wow-2.5.x-addons.git/master/<AddonName> && ./test.sh
```

`test.sh` with no argument runs everything and prints a per-suite `Ok`/`FAIL`. A single
suite: `cd test && lua <Name>_test.lua -v -T Spec -m should -o text`.

**Read the output; do not trust the exit code.** `run_all_tests` loops inside a `while read`
subshell, so a failure does not reliably propagate out of `test.sh`. Check for `FAIL`,
`ERROR` and the per-suite summary lines.

If `lua-language-server` is available, run `lua-language-server --check .` on the workspace
after each phase. IDE diagnostics only cover open buffers and will miss things.

### Working agreement

- **Scope:** all of Phases 0-9. Nothing is blocked.
- **Git:** commit to the branches already checked out -- core on `extensions`, addons on
  `master`. Commit as each phase lands, one commit per phase, message naming the phase.
  **Do not push.**
- **Docs:** `PLAN.md`, `SR-DIFF.md` and `SR-PLUS.md` are tracked. Update them when the build
  diverges from what they predict, in the same commit as the divergence.
- **What you cannot verify:** this is a WoW addon and none of it can be run in-game from
  here. Frame layout, dropdown appearance and anything visual are **unverifiable by test**.
  Build them from the existing widgets, keep them consistent with the surrounding code, and
  say plainly in the handover which parts need a human to look at them in the client.

### Target: BCC only

Interface 20506. Do not add vanilla fallbacks, do not check whether an API exists in 1.12,
do not reintroduce a `m.vanilla` / `m.bcc` split. See `CLAUDE.md`.

---

## 1. Decisions already made -- do not relitigate

| Decision | Where it is argued |
|---|---|
| One shared addon, `RollForSoftRes`; providers are separate addons that register with it | SR-DIFF §6 Option A |
| The shared addon owns the import window; providers do **not** have their own | SR-DIFF §7 |
| The window has a **Provider dropdown**; the user selects, then imports | SR-DIFF §7.1 |
| Zero providers → message + import disabled; do **not** wipe saved data | SR-DIFF §7.1, §7.3 |
| A provider is `{ id, title, decode }` and owns no data | SR-DIFF §6, §7.2 |
| The **library** is the RollFor extension; providers are not | SR-DIFF §6 Option A, §7.2 |
| No format sniffing -- selection is explicit | SR-DIFF §9 |
| SR+ returns as a **roll modifier**, not as fields on `Roll` | SR-PLUS §10.1, §10.2 |
| SR+'s number comes from raidres' per-item `sr_plus`; the field is real | SR-PLUS §7 |
| Duplicate entries on one item: **highest wins**, with a warning when they disagree | SR-PLUS §7.2 |
| **No data migration.** The library starts empty; users re-import | confirmed by the user |
| A modifier declares `delta` **xor** `adjust`; that choice decides previewability | SR-PLUS §10.2 |
| Modifier ordering uses the existing `Ordering.place`, not a new scheme | SR-PLUS §10.2 |
| SR+ ships as its own addon, `RollForSrPlus` | SR-PLUS §10.5; confirmed by the user |
| One agent takes Phases 0-9; nothing is blocked | confirmed by the user |
| Commit to the current branches (core `extensions`, addons `master`); do not push | confirmed by the user |
| PLAN.md, SR-DIFF.md and SR-PLUS.md are committed, not scratch | confirmed by the user |

---

## 2. The SR+ data model -- specified

Earlier revisions of this plan got this wrong twice: the first said `sr_plus` had no source
at all, the second required per-roll bonus lists. Both are superseded. What follows is
settled; SR-PLUS §7 carries the reasoning and the real payload.

- **raidres emits `sr_plus` per item entry.** `raidres-sr-plus.txt` in the repo root is a
  real export carrying it. The transformer line `13f9384` added and `7d169a5` removed goes
  back as it was.
- **Bonuses differ per (player, item)**, and the store's shape already handles that:
  `sr_result[ item_id ].rollers[]` is scoped per item, so a scalar `sr_plus` on a roller is
  the right granularity.
- **Duplicate entries of one item by one player: take the highest**, and apply it to all
  their rolls on that item. This aligns with raidres, which normalises duplicates to
  "previous highest + increase" for *both* items at its next recalculation. Divergence is
  usually stale points rather than intent (SR-PLUS §7.2 quotes the clause).
- **Warn when duplicates disagree.** Manual editing is raidres' supported escape hatch, so
  deliberate divergence is possible and indistinguishable from staleness. Nothing is
  discarded silently:
  `Boulderdash has 2 reservations on [Item] with different SR+ (20, 10). Using 20.`
- **softres.it lists produce no bonus** (SR-PLUS §7.3). SR+ is a raidres capability unless
  someone deliberately maps its per-player `rollBonus`.

Consequences for the seam: `delta` stays a **scalar**, `consume_roll` is **untouched**, and
no spend order is needed. Phases 6 and 8 are correspondingly smaller.

**Fixtures are in hand.** `raidres-sr-plus.txt` (uniform) and
`raidres-sr-plus-divergent.txt` (duplicates that disagree, in both directions) sit in the
repo root. SR-PLUS §7.4 gives the expected transform and the expected warnings for each.

---

## PART A -- shared SoftRes and providers

### Phase 0. Baseline

1. Run all three suites (core, `RollForSoftResIt`, `RollForRaidRes`). Record the pass counts.
2. Commit nothing. This is the number every later phase is measured against.

**Done when:** three green runs, counts written down.

---

### Phase 1. Create the `RollForSoftRes` addon

New addon at `~/.projects/lua/wow-2.5.x-addons.git/master/RollForSoftRes`.

1. Copy the **14 shared `src/` files** from `RollForSoftResIt/src/` -- everything except
   `Decoder.lua`. SR-DIFF §2 lists them. Namespace them once: `RollForSoftRes` in place of
   `RollForSoftResIt` on lines 1-2 of each file.
2. Write `RollForSoftRes.toc`: `## Interface: 20506`, `## Dependencies: RollFor`,
   `## X-RollFor-Extension: softres`, and the same file order the two existing TOCs use.
3. Write `RollForSoftRes.lua` from `RollForSoftResIt.lua`, **dropping** the migration block
   (`MIGRATION`, `deep_copy`, `is_empty`, `migrate_from_core`) and the identity strings.
   Per Phase 3 there is no migration of any kind. It registers **one** RollFor
   extension: `name = "softres"`, `title = "SoftRes"`.
4. Add the provider registry:

   ```lua
   ---@class SoftResProvider
   ---@field id string      -- persisted with the imported list
   ---@field title string   -- what the dropdown shows
   ---@field decode fun( encoded: string? ): table?

   function RollForSoftRes.register( spec )  -- validates, refuses duplicate ids
   function RollForSoftRes.providers()       -- registration order
   ```

   Validation mirrors `Extensions.register`: reject a non-table, a missing or non-string
   `id`/`title`, a non-function `decode`, and a duplicate `id`, each with `m.err`.
5. Derive the frame name from the addon, not a provider: **keep
   `RollForSoftResLootFrame`** -- it is already the softres.it name, it is in
   `UISpecialFrames`, and user macros may reference it. Options popup:
   `RollForSoftResOptionsPage`.

**Done when:** the addon loads in isolation and its copied suites pass. It is not wired to
any provider yet.

---

### Phase 2. The Provider dropdown

In `RollForSoftRes/src/SoftResGui.lua`. The spec is SR-DIFF §7.1 and §7.3; build every row
of the §7.3 table.

1. Add the dropdown above the editbox, populated from `RollForSoftRes.providers()`, showing
   `title`, always present even with one provider registered.
   **Use the existing widget**: `ctx.gui_elements.dropdown( parent )` -- `GuiElements.dropdown`
   (`RollFor/src/GuiElements.lua:823`) wraps `UIDropDownMenuTemplate`, handles the label, the
   selected-value anchoring and `SetDropdownWidth`. Do not hand-roll a dropdown; RollFor's
   own options frame and `RollForAutoRobin` both drive this one.
2. Selection is state: persist the chosen `id` in the library's db, and write it **into the
   store alongside `data` and `import_timestamp`** so login knows which decoder to use.
3. Empty state: label `No SoftRes data providers registered.`, editbox and Import disabled.
   **Disable without clearing** -- the simulation lock clears the editbox text and must not
   be reused as-is for this (SR-DIFF §7.3).
4. Import calls the selected provider's `decode`. On failure, the existing
   `Could not load soft-res data!` path, with the selected provider named.
5. Saved provider no longer installed: report it by name, leave the raw string on disk, do
   not wipe. The list is empty for the session.
6. **Event `source`.** `softres_imported`, `softres_cleared` and `softres_checked` carry
   `source = "softres_it"` today. It becomes the **selected provider's id**. Nothing reads
   the field (SR-DIFF §9), so this cannot break a consumer -- but it is the only value that
   stays meaningful once one addon imports from either site.
7. **`Simulation` does not go through the dropdown.** `sr.Simulation` fabricates already-
   decoded data and calls `store.import` directly, bypassing `decode` entirely. It must keep
   working with **no provider registered at all** -- `/rfsetup` is not an import.
8. **Options page prose.** The page is now the SoftRes addon's, not a provider's, so its
   summary can no longer name a website. It describes what the addon does, that a provider
   addon supplies the format, and lists `/sr`, `/src`, `/srs`, `/sro`.

**Done when:** new GUI suites cover all five states above and pass.

---

### Phase 3. No migration -- by decision

**Do not migrate any data. Do not write migration code.**

The library is the extension, so `ctx.db( "softres" )` resolves to
`extension_softres_softres`, and existing users' data sits at `extension_softres_it_softres`
and `extension_softres_it_name_matcher`. It stays there, untouched and unread.
`RollForSoftRes` starts empty.

Consequences, to be stated in the release notes rather than discovered:

- An existing user's soft-res list is **not** carried over. They paste their import string
  again -- one action, and the string is still on raidres/softres.it.
- Their **manual name matches** (`/sro` overrides) are **not** carried over either, and
  unlike the list these are hand-entered and not recoverable from a paste. Anyone with a
  roster full of mistyped names redoes them.
- The old keys are left in place, so nothing is destroyed and a downgrade still finds its
  data.

`RollForSoftResIt`'s own core→extension migration is deleted along with the rest of that
addon in Phase 4; it is not carried into the library.

**Done when:** no code anywhere reads `extension_softres_it_*` or `extension_raidres_*`, and
a fresh install and an upgrade-over-existing both start with an empty list and no error.

---

### Phase 4. Shrink the providers

1. `RollForSoftResIt` keeps: `.toc`, `src/Decoder.lua`, and a `RollForSoftResIt.lua` that
   registers `{ id = "softres_it", title = "softres.it", decode = ... }`. Delete the other
   14 `src/` files and the shared test harness.
2. `RollForRaidRes` likewise: `{ id = "raidres", title = "raidres" }`.
3. Both TOCs become `## Dependencies: RollFor, RollForSoftRes`. Remove
   `X-RollFor-Extension` -- they are no longer extensions.
4. They no longer register with `Extensions`, no longer create frames, no longer claim
   slash commands, no longer subscribe to `minimap_icon_right_click`. This is what fixes
   the two bugs in SR-DIFF §3.8.
5. **Transformer passthrough (required).** SR+ reads `sr_plus` out of raidres data
   (SR-PLUS §7), the provider is only a decoder, and the library owns the transformer -- so
   the transformer must carry provider-supplied per-roller values through to the store, or
   a separate `RollForSrPlus` addon can never see them.

**Done when:** both provider addons are three files each; both installed together produce
one window, one `/sr`, one minimap handler; every suite green.

---

### Phase 5. Consolidate the tests

1. Move `test/utils.lua`, `test/IntegrationTestBuilder.lua`, `test/gui_helpers.lua`,
   `test/mocking.lua`, `test/luaunit.lua` and `test/mocks/` into `RollForSoftRes/test/`.
   These are ~11.7k lines currently triplicated (SR-DIFF §1).
2. Each provider keeps **one** suite: a decoder test.
3. **Write the missing softres.it `Decoder_test`.** There has never been one (SR-DIFF §2).
   `sr-ohhaimark.zlib.base64` and `sr-ohhaimark.json` are already a matched pair. Mirror
   `RollForRaidRes/test/Decoder_test.lua`, including the negative case.
4. Rename provider-neutral: the `RaidRes*` type annotations in
   `SoftResDataTransformer.lua`, and `builder.without_softres_it`.
5. Update `import_softres_via_gui` in the harness to select a provider first.

**Done when:** no file is duplicated across the three addons, and the total test count is
at or above the Phase 0 baseline.

---

## PART B -- SR+ on a general seam

### Phase 6. The core seam

All in the core repo. Design: SR-PLUS §10.1 and §10.2. **Nothing here mentions SR+** -- if
it does, the seam is wrong.

1. `RollFor/src/Types.lua`: add `RollAdjustment` (`{ by, delta }`); add optional
   `adjustments` to `Roll` and `Winner`; carry it through `make_roll` and `make_winner`.
2. `RollFor/src/MasterLootCandidates.lua`: `transform_to_winner` passes `adjustments` from
   the winning `Roll` to the `Winner`. **This is the flattening point** -- miss it and the
   list dies here.
3. `RollFor/src/RollResultAnnouncer.lua`: render `89+30=119` by reading the winner's list.
   It already has **no** `softres` argument (`7d169a5` removed it) -- the work is *not
   re-adding one*. `main.lua` and `IntegrationTestBuilder.lua` stay untouched.
4. `RollFor/src/RollingLogicUtils.lua`: add `roll_modifiers` (empty), registration
   validation (`delta` xor `adjust`, rejecting both or neither), ordering via
   `Ordering.place`, and the `apply_modifiers` fold **with the `d ~= 0` guard**.
5. Fold it into all three `on_roll` implementations, honouring each modifier's `rounds`:
   `SoftResRollingLogic`, `TieRollingLogic`, `NonSoftResRollingLogic`. The third still
   decrements `player.rolls` inline rather than via `consume_roll`.
6. Preview path, alongside the fold and sharing its ordering and `rounds` filtering:

   ```lua
   -- What this player would get if they rolled now. `delta` modifiers only: an `adjust`
   -- modifier depends on the roll value and has nothing to say before there is one.
   ---@return RollAdjustment[]?
   function M.preview_adjustments( player, item, strategy )
   ```

   Consumed by `SoftResRollingLogic.format_name_with_rolls` and
   `DroppedLootAnnounce.print_player`, which render it the way SR+ used to render
   `player.sr_plus` -- `" (+30)"`, summed when several modifiers contribute. Re-check the
   `m.split_message` byte budget: a longer annotation splits the roll call earlier
   (SR-PLUS §9.1), which shows up as changed expected strings in integration tests.

**Done when:** core is green with an empty modifier list, and behaviour is byte-identical
to before -- an empty list must be exactly today's behaviour.

---

### Phase 7. Expose the seam to extensions

1. `RollFor/main.lua`: add `roll_modifier = { register = ... }` to the extension context.
2. `RollFor/src/Extensions.lua`: bump `API_VERSION` to 4 and document the new context field
   in the `ExtensionContext` annotation.
3. `RollForSoftRes` declares `api_version = 3` (what it is actually written against) unless
   it uses the new field. Do not claim `API_VERSION`.
4. Sync to the addons tree and re-run every extension suite.

**Done when:** an extension can register a modifier, and all suites in all addons pass.

---

### Phase 8. SR+ itself

SR+ is its own addon, `RollForSrPlus` (SR-PLUS §10.5, confirmed): a chain link on the read
path and a modifier on the roll path. `## Dependencies: RollFor, RollForSoftRes` -- it needs
the transformer's passthrough (Phase 4) to see `sr_plus` at all.

1. Read `sr_plus` off the roller (§2, SR-PLUS §10.4).
2. **Copy the roller before annotating** -- `m.clone` is shallow and writes through to the
   store (SR-PLUS §6.3). `SoftResBonusRollDecorator` is the deleted precedent; its comment
   names the failure mode.
3. Transformer takes `math.max` across a player's duplicate entries for an item, replacing
   first-entry-wins (SR-PLUS §6.2, reproduced), and warns when they disagree (§2).
4. Register one modifier: `name = "sr_plus"`, `rounds = { RS.SoftResRoll }`, `delta`.
5. Restore both display sites via the Phase 6 preview path.

**Done when:** the two restored suites below pass.

---

### Phase 9. SR+ tests

1. Restore the two original suites from `7d169a5^` (SR-PLUS §5.1, §5.2). Both were verified
   passing against that tree.
2. **The tie test first** -- SR-PLUS §6.1 is a reproduced bug and the probe source is in
   SR-PLUS's appendix, ready to adapt. Under the new design a tie re-roll must print the
   bare number.
3. Add what SR-PLUS §5.4 lists: multi-roll players, ordering, bounds, zero.
4. A **two-modifier accumulation test** built on SR-PLUS §10.3: static + static,
   order-independent total, one combined pre-roll annotation, correct decomposition in the
   announcement. This is what proves the seam is a seam.
5. Fixtures: move both root exports into the decoder test's fixtures directory with their
   decoded `.json` companions (SR-PLUS §7.4). Assert the transform and the warnings for
   each. The divergent one must fail a first-entry-wins transformer on item 32232 while
   passing on 32234 -- that asymmetry is the point.

**Done when:** every suite in every addon passes, and the tie case is covered.

---

## 3. Traps

Each of these fails **silently**. They are the reason a phase can look done and not be.

- **Vendored test harnesses.** Each extension carries its own copy of `test/utils.lua` and
  `IntegrationTestBuilder.lua`. Change core and forget `sync-bcc.sh`, and the extension
  suites test a stale core without saying so.
- **`m.clone` is shallow.** `SoftRes.get` returns a new list of the *stored* roller tables.
  Anything that annotates a roller writes through to the soft-res data itself.
- **`m.slash_cmd` refuses duplicates silently** (`modules.lua:230`) -- a `dbg` line and
  nothing the user sees.
- **`EventBus.notify` fans out to every subscriber.** Two subscribers to
  `minimap_icon_right_click` means two windows.
- **`Db` migrations run *inside* a store** and cannot rename its key. A key change needs an
  explicit copy.
- **`Ordering.place` and `Chain` resolve anchors at build time**, which is why load order
  does not matter for chain links -- do not "fix" it with load-order assumptions.
- **`split_message` budgets bytes.** Longer per-name annotations move where messages split,
  which shows up as changed expected strings in integration tests.
- **`0` is truthy in Lua.** Hence the `d ~= 0` guard in the fold.

---

## 4. Definition of done

- [ ] `RollForSoftRes` owns the store, window, name matching, slash commands, minimap
      contribution and options page; is the only registrant with core's `SoftResSource`.
- [ ] `RollForSoftResIt` and `RollForRaidRes` are three files each and register only a
      decoder.
- [ ] Both installed together: one import window, one `/sr`, one minimap handler, a
      dropdown listing both.
- [ ] No providers installed: the message shows and import is impossible; saved data intact.
- [ ] No migration code exists; the old db keys are neither read nor written, and an
      upgrade-over-existing starts empty without erroring.
- [ ] `roll_modifiers` exists in core, is empty by default, and an empty list reproduces
      today's behaviour exactly.
- [ ] SR+ is an extension registering one modifier; core contains no reference to it.
- [ ] A tie re-roll announces the bare roll (SR-PLUS §6.1 fixed).
- [ ] Two modifiers accumulate, order-independently, with a correct decomposition.
- [ ] No file duplicated across addons; the softres.it decoder test exists.
- [ ] Core + every extension suite green, at or above the Phase 0 baseline.
- [ ] `RollForSrPlus` exists as its own addon and can be disabled without affecting imports.
- [ ] Duplicate entries with differing values take the highest and print a warning; the
      divergent fixture fails a first-entry-wins transformer on 32232 (SR-PLUS §7.4).
- [ ] Every phase committed to its repo's current branch. Nothing pushed.
- [ ] PLAN.md, SR-DIFF.md and SR-PLUS.md tracked and updated where the build diverged.
- [ ] Handover names every part that needs a human to check it in the client.
