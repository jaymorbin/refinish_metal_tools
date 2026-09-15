# refinish_metal_tools

> **Repository:** https://github.com/jaymorbin/refinish_metal_tools
>
> ```
> git clone --depth 1 https://github.com/jaymorbin/refinish_metal_tools.git
> ```
>
> **Companion repos:**
> - [df_data_reference](https://github.com/jaymorbin/df_data_reference) — path maps and structure dumps from a live game
> - [vanilla_raws_reference](https://github.com/jaymorbin/vanilla_raws_reference) — complete vanilla DF raws and sprite sheets
>
> A copy of this index also lives in the Refinish Metal project, where it is
> readable without cloning. See `REFERENCE_REPOS.md` there for the overview, and
> note that DFHack documentation is **not** in any repo.
> Both copies are generated; regenerate rather than hand-editing either.

Archived probe scripts and utilities from Refinish Metal development. These are **periodic clear-outs of the live scripts folder**, taken whenever it got too full, too messy, or had scripts running that interfered with testing. The directory names are strata, not categories.

These tools are **not meant to be run again**. They are kept for reference: the paths they reference, the engine questions they record, and the functions worth harvesting into generalized RM tooling later. See the reliability warning below before trusting anything here.

## Reliability warning

**These probes are hit and miss. Many are failures, half-finished, or were superseded.** A script existing here is not evidence that its approach worked. 40 of 187 files contain comments about something being broken, wrong, abandoned or superseded, but that language covers three different cases that cannot be told apart mechanically: the script is broken, the script *found* that something else was wrong (the valuable case), or the script records what an earlier version got wrong. Files carrying any such comment are marked (!) below. Read the comment before trusting the code, and verify anything load-bearing against the live game.

## How to use this

The question this archive answers is *"did we already work this out, and where?"* Use the Topic index below to narrow, then grep the file.

```
grep -rn 'reaction_class' --include='*.lua' .
grep -rln 'getTexposByHandle' .
```

**187 files** (173 unique by content), 168 Lua, 4 Python. 170 touch a `df.global` path.

## Versions that differ

Eight tool names appear in two dumps. All are byte-identical copies except these, where the two copies genuinely differ and you need to know which you are reading:

- `refinish-deep-reaction-probe.lua`
  - `Utility Scripts/refinish-deep-reaction-probe.lua` (72 lines, 3K)
  - `utility dump/refinish-deep-reaction-probe.lua` (72 lines, 3K)
- `refinish-reaction-probe-v2.lua`
  - `Utility Scripts/refinish-reaction-probe-v2.lua` (74 lines, 3K)
  - `utility dump/refinish-reaction-probe-v2.lua` (74 lines, 3K)

## Topic index

Which files carry knowledge about which subsystem. A file can appear more than once.

### inorganics/materials (83)

`check_colours_or_something.lua`, `check_reagent.lua`, `clear_material_id_string.lua`, `fiddler.lua`, `inorganic_raw_differences`, `inorganic_raw_differences.lua`, `inorganic_raw_differences.txt`, `local raws = df.global.world.raws.inorganics.lua`, `making-concrete-sand-diagnose-v2.lua`, `making-concrete-sand-diagnose.lua`, `making-concrete-sand-test.lua`, `manual stuff.txt`, `material_structure_differences.lua`, `other_refinish_compare.lua`, `probe-butcher.lua`, `probe-corpsepiece.lua`, `probe-hide.lua`, `probe-liquid-mint.lua`, `probe-pitch-tar.lua`, `refinish injection notes`, `refinish injection notes.txt`, `refinish-artifact-probe.lua`, `refinish-barrel-probe.lua`, `refinish-bars-probe.lua`, `refinish-blankname-probe.lua`, `refinish-boulder-probe.lua`, `refinish-caption-patch.lua`, `refinish-caption-probe.lua`, `refinish-civ-probe.lua`, `refinish-clear-test.lua`, `refinish-clone-test.lua`, `refinish-color-probe.lua`, `refinish-compare-inorganic.lua`, `refinish-corpsepiece-probe.lua`, `refinish-debug-civs.lua`, `refinish-deep-probe.lua`, `refinish-eval-tech-1.lua`, `refinish-eval-tech-2.lua`, `refinish-find-missing.lua`, `refinish-flag-lab.lua`, `refinish-floor-probe.lua`, `refinish-forge-test.lua`, `refinish-fuel-bypass-test.lua`, `refinish-fuel-count-probe.lua`, `refinish-fuel-slot-probe.lua`, `refinish-fuel-testbed.lua`, `refinish-fuel-trace.lua`, `refinish-ghost-hunter.lua`, `refinish-guard-probe.lua`, `refinish-inject-test.lua`, `refinish-item-fix.lua`, `refinish-matcolor-probe.lua`, `refinish-matswap-probe.lua`, `refinish-metal-probe.lua`, `refinish-metal-validation-broken-probe.lua`, `refinish-name-probe.lua`, `refinish-pitch-probe.lua`, `refinish-plant-mat-probe.lua`, `refinish-plant-product-probe.lua`, `refinish-probe-geology.lua`, `refinish-probe-missing-reactions.lua`, `refinish-probe-purple.lua`, `refinish-prototype.lua`, `refinish-prototype.lua`, `refinish-reaction-probe-v2.lua`, `refinish-reaction-probe-v2.lua`, `refinish-read-inorganic.lua`, `refinish-scan.lua`, `refinish-scrubber.lua`, `refinish-size-probe.lua`, `refinish-struct-probe.lua`, `refinish-struct-probe.lua`, `refinish-verify-metals.lua`, `refinish-verify-metals.lua`, `refinish-vessel-probe.lua`, `refinish_audit.lua`, `refinish_authorize.lua`, `refinish_deinject.lua`, `repair-module-liquids.lua`, `test-retort-claims.lua`, `test-watcher.lua`, `unedited injection notes`, `unedited injection notes.txt`

### items (78)

`check_reagent.lua`, `making-concrete-sand-diagnose-v2.lua`, `making-concrete-sand-diagnose.lua`, `making-concrete-sand-test.lua`, `making-fuel-job-probe.lua`, `manual troubleshooting commands.txt`, `probe-aftermath.lua`, `probe-bone-item.lua`, `probe-butcher.lua`, `probe-corpsepiece.lua`, `probe-cycle-detect.lua`, `probe-hide.lua`, `probe-liquid-mint.lua`, `probe-pitch-tar.lua`, `refinish injection notes`, `refinish injection notes.txt`, `refinish-artifact-probe.lua`, `refinish-ashes-probe.lua`, `refinish-barrel-probe.lua`, `refinish-bars-probe.lua`, `refinish-blankname-probe.lua`, `refinish-boulder-probe.lua`, `refinish-capacity-probe.lua`, `refinish-caption-patch.lua`, `refinish-caption-probe.lua`, `refinish-coal-key-test.lua`, `refinish-container-probe.lua`, `refinish-container-struct-probe.lua`, `refinish-corpse-probe.lua`, `refinish-corpsepiece-probe.lua`, `refinish-deep-probe.lua`, `refinish-deep-reaction-probe.lua`, `refinish-deep-reaction-probe.lua`, `refinish-empty-probe.lua`, `refinish-eval-tech-1.lua`, `refinish-eval-tech-2.lua`, `refinish-find-missing.lua`, `refinish-flag-lab.lua`, `refinish-forge-probe.lua`, `refinish-forge-test.lua`, `refinish-fuel-bypass-test.lua`, `refinish-fuel-count-probe.lua`, `refinish-fuel-quantity-test.lua`, `refinish-fuel-slot-probe.lua`, `refinish-fuel-testbed.lua`, `refinish-fuel-trace.lua`, `refinish-fuel-widen-probe.lua`, `refinish-ghost-hunter.lua`, `refinish-guard-probe.lua`, `refinish-inv-probe.lua`, `refinish-item-fix.lua`, `refinish-item-type-probe-2.lua`, `refinish-item-type-probe.lua`, `refinish-name-probe.lua`, `refinish-pitch-doctor.lua`, `refinish-pitch-probe.lua`, `refinish-plant-mat-probe.lua`, `refinish-plant-product-probe.lua`, `refinish-portal-probe.lua`, `refinish-reaction-forensics.lua`, `refinish-reaction-forensics.lua`, `refinish-reaction-probe-v2.lua`, `refinish-reaction-probe-v2.lua`, `refinish-reagent-prompt-test.lua`, `refinish-size-probe.lua`, `refinish-steel-audit.lua`, `refinish-template-hunter`, `refinish-template-hunter.lua`, `refinish-template-hunter.lua`, `refinish-tool-census.lua`, `refinish-verify-metals.lua`, `refinish-verify-metals.lua`, `refinish-vessel-probe.lua`, `repair-module-liquids.lua`, `test-retort-claims.lua`, `test-watcher.lua`, `unedited injection notes`, `unedited injection notes.txt`

### reactions (57)

`making-fuel-job-probe.lua`, `probe-aftermath.lua`, `probe-cycle-detect.lua`, `probe-liquid-mint.lua`, `refinish-civ-probe.lua`, `refinish-compare-reaction.lua`, `refinish-debug-civs.lua`, `refinish-deep-reaction-probe.lua`, `refinish-deep-reaction-probe.lua`, `refinish-diag-entity.lua`, `refinish-diagnose-pipeline.lua`, `refinish-empty-patch.lua`, `refinish-empty-probe.lua`, `refinish-eval-tech-1.lua`, `refinish-eval-tech-2.lua`, `refinish-evaluate-metal-making.lua`, `refinish-find-missing.lua`, `refinish-flag-lab.lua`, `refinish-flag-probe.lua`, `refinish-forge-test.lua`, `refinish-fuel-slot-probe.lua`, `refinish-improvement-enum.lua`, `refinish-improvement-inspect.lua`, `refinish-matswap-probe.lua`, `refinish-metal-validation-broken-probe.lua`, `refinish-pitch-doctor.lua`, `refinish-pitch-probe.lua`, `refinish-plant-product-probe.lua`, `refinish-portal-probe.lua`, `refinish-powder-probe.lua`, `refinish-print-entity-permissions.lua`, `refinish-probe-3billion.lua`, `refinish-probe-fuel.lua`, `refinish-probe-missing-reactions.lua`, `refinish-probe-purple.lua`, `refinish-probe-x1`, `refinish-probe-x1.lua`, `refinish-probe.lua`, `refinish-prototype`, `refinish-prototype.lua`, `refinish-prototype.lua`, `refinish-reaction-automatic-tag.lua`, `refinish-reaction-forensics.lua`, `refinish-reaction-forensics.lua`, `refinish-reaction-probe-v2.lua`, `refinish-reaction-probe-v2.lua`, `refinish-read-reaction.lua`, `refinish-reagent-probe.lua`, `refinish-scrubber.lua`, `refinish-template-hunter`, `refinish-template-hunter.lua`, `refinish-template-hunter.lua`, `refinish-verify-metals.lua`, `refinish-verify-metals.lua`, `refinish-workshop-probe.lua`, `refinish-workshop-probe.lua`, `test-retort-claims.lua`

### jobs (38)

`making-fuel-job-probe.lua`, `moremanualstuff.txt`, `probe-aftermath.lua`, `probe-butcher.lua`, `probe-corpsepiece.lua`, `probe-cycle-detect.lua`, `probe-hide.lua`, `probe-liquid-mint.lua`, `probe-pitch-tar.lua`, `refinish-civ-capability.lua`, `refinish-container-probe.lua`, `refinish-corpse-probe.lua`, `refinish-debug-civs.lua`, `refinish-empty-probe.lua`, `refinish-forge-probe.lua`, `refinish-fuel-bypass-test.lua`, `refinish-fuel-count-probe.lua`, `refinish-fuel-quantity-test.lua`, `refinish-fuel-slot-probe.lua`, `refinish-fuel-widen-probe.lua`, `refinish-gate-delta.lua`, `refinish-guard-probe.lua`, `refinish-item-type-probe-2.lua`, `refinish-item-type-probe.lua`, `refinish-labor-index.lua`, `refinish-manager-probe.lua`, `refinish-matswap-probe.lua`, `refinish-menu-probe.lua`, `refinish-permitted-job-enum.lua`, `refinish-pitch-doctor.lua`, `refinish-pitch-probe.lua`, `refinish-prototype`, `refinish-prototype.lua`, `refinish-prototype.lua`, `refinish-reagent-prompt-test.lua`, `test-name.lua`, `test-retort-claims.lua`, `test-watcher.lua`

### entities/civ (29)

`civ_object_paths.txt`, `refinish-building-check.lua`, `refinish-civ-capability.lua`, `refinish-civ-probe.lua`, `refinish-corpse-probe.lua`, `refinish-debug-civs.lua`, `refinish-dedup-check.lua`, `refinish-diag-entity.lua`, `refinish-diagnose-pipeline.lua`, `refinish-dump-entity-permissions.lua`, `refinish-eval-tech-1.lua`, `refinish-eval-tech-2.lua`, `refinish-find-missing.lua`, `refinish-forge-test.lua`, `refinish-gate-delta.lua`, `refinish-labor-index.lua`, `refinish-metal-validation-broken-probe.lua`, `refinish-permitted-job-enum.lua`, `refinish-portal-probe.lua`, `refinish-print-entity-permissions.lua`, `refinish-probe-3billion.lua`, `refinish-probe-geology.lua`, `refinish-prototype`, `refinish-prototype.lua`, `refinish-prototype.lua`, `refinish-scrubber.lua`, `refinish-verify-metals.lua`, `refinish-verify-metals.lua`, `refinish_authorize.lua`

### buildings/workshops (28)

`refinish injection notes`, `refinish injection notes.txt`, `refinish-ashes-probe.lua`, `refinish-building-check.lua`, `refinish-building-probe.lua`, `refinish-civ-capability.lua`, `refinish-forge-probe.lua`, `refinish-fuel-trace.lua`, `refinish-furnace-entry-probe.lua`, `refinish-furnace-mark.lua`, `refinish-furnace-probe.lua`, `refinish-ghost-hunter.lua`, `refinish-icon-hunt.lua`, `refinish-icon-probe.lua`, `refinish-menu-icon.lua`, `refinish-pitch-probe.lua`, `refinish-pixel-probe.lua`, `refinish-range-probe.lua`, `refinish-render-probe.lua`, `refinish-template-fill.lua`, `refinish-twin-probe.lua`, `refinish-workshop-probe.lua`, `refinish-workshop-probe.lua`, `refinish-wsgi-dump.lua`, `refinish-wsgi-fill.lua`, `refinish-wsgraphics-probe.lua`, `unedited injection notes`, `unedited injection notes.txt`

### misc (18)

`color_instance_sorter.py`, `colour_match_block_grabber.py`, `item_structural_differences.lua`, `missing_colours_sorter.py`, `product_colour_fixer.py`, `refinish-autosave.lua`, `refinish-bar-sprite-probe.lua`, `refinish-button-probe.lua`, `refinish-civ-tech-dump.lua`, `refinish-kill-autosave.lua`, `refinish-mod-id.lua`, `refinish-onmapload.lua`, `refinish-perf-probe.lua`, `refinish-prep.lua`, `refinish-rot-flag-probe.lua`, `refinish_compare.lua`, `search_for_armor_tables.lua`, `test-menu.lua`

### sprites/textures (16)

`refinish-floor-probe.lua`, `refinish-furnace-entry-probe.lua`, `refinish-furnace-mark.lua`, `refinish-furnace-probe.lua`, `refinish-icon-hunt.lua`, `refinish-icon-probe.lua`, `refinish-image-probe.lua`, `refinish-menu-icon-probe.lua`, `refinish-menu-icon.lua`, `refinish-pixel-probe.lua`, `refinish-range-probe.lua`, `refinish-render-probe.lua`, `refinish-template-fill.lua`, `refinish-twin-probe.lua`, `refinish-wsgi-fill.lua`, `refinish-wsgraphics-probe.lua`

### units/creatures (13)

`making-concrete-sand-diagnose-v2.lua`, `making-concrete-sand-test.lua`, `making-fuel-job-probe.lua`, `probe-bone-item.lua`, `probe-butcher.lua`, `probe-corpsepiece.lua`, `probe-hide.lua`, `refinish-boulder-probe.lua`, `refinish-coal-key-test.lua`, `refinish-corpse-probe.lua`, `refinish-fuel-testbed.lua`, `refinish-plant-mat-probe.lua`, `refinish-size-probe.lua`

### gui/overlay (12)

`check_reagent.lua`, `notes.txt`, `refinish injection notes`, `refinish injection notes.txt`, `refinish-building-probe.lua`, `refinish-desc-probe.lua`, `refinish-flag-lab.lua`, `refinish-floor-probe.lua`, `refinish-fuel-testbed.lua`, `turn item to material manual command.txt`, `unedited injection notes`, `unedited injection notes.txt`

### plants (6)

`refinish-branch-probe.lua`, `refinish-fuel-testbed.lua`, `refinish-name-probe.lua`, `refinish-plant-mat-probe.lua`, `refinish-plant-state-probe.lua`, `refinish-wood-color-probe.lua`

## Path index

The `df.global` paths this archive **references**, and where. These are attempts, not verified findings: A path appearing here means a script reached for it, not that it worked. Use this to find prior attempts, then read the file and verify against the live game.

| Path | Files | Where |
|---|---|---|
| `world.raws.reactions.reactions` | 52 | refinish-template-hunter.lua, refinish-prototype, refinish-powder-probe.lua +49 |
| `world.raws.inorganics.all` | 47 | refinish-scan.lua, refinish-deep-probe.lua, refinish-clone-test.lua +44 |
| `world.items.all` | 36 | refinish-deep-probe.lua, probe-corpsepiece.lua, refinish-artifact-probe.lua +33 |
| `world.jobs.list` | 16 | probe-butcher.lua, test-name.lua, refinish-item-type-probe.lua +13 |
| `world.entities.all` | 13 | refinish-prototype, refinish-prototype.lua, refinish-verify-metals.lua +10 |
| `plotinfo.civ_id` | 12 | refinish-forge-test.lua, refinish-scrubber.lua, refinish-portal-probe.lua +9 |
| `world.buildings.all` | 10 | refinish-ghost-hunter.lua, refinish injection notes, unedited injection notes.txt +7 |
| `world.raws.buildings.workshop_graphics_info` | 9 | refinish-wsgi-fill.lua, refinish-furnace-probe.lua, refinish-furnace-entry-probe.lua +6 |
| `texture.page` | 9 | refinish-furnace-probe.lua, refinish-menu-icon-probe.lua, refinish-icon-hunt.lua +6 |
| `world.jobs.list.next` | 7 | refinish-fuel-bypass-test.lua, refinish-fuel-count-probe.lua, refinish-corpse-probe.lua +4 |
| `world.raws.buildings.all` | 7 | refinish-pitch-probe.lua, refinish-menu-icon.lua, refinish-render-probe.lua +4 |
| `world.units.active` | 6 | probe-corpsepiece.lua, refinish-fuel-testbed.lua, refinish-boulder-probe.lua +3 |
| `world.raws.inorganics.all` | 6 | refinish-prototype.lua, refinish-prototype.lua, refinish-pitch-probe.lua +3 |
| `world.raws.mat_table` | 6 | refinish injection notes, unedited injection notes.txt, unedited injection notes +3 |
| `world.raws.reactions.reactions` | 5 | refinish-flag-probe.lua, refinish-print-entity-permissions.lua, refinish-diag-entity.lua +2 |
| `world.constructions` | 5 | refinish injection notes, manual troubleshooting commands.txt, unedited injection notes.txt +2 |
| `world.raws.plants.all` | 5 | refinish-wood-color-probe.lua, refinish-plant-state-probe.lua, refinish-fuel-testbed.lua +2 |
| `world.raws.descriptors.colors` | 4 | refinish-scan.lua, refinish-color-probe.lua, refinish-wood-color-probe.lua +1 |
| `world.map.map_blocks` | 4 | refinish injection notes, unedited injection notes.txt, unedited injection notes +1 |
| `world.raws.mat_table.armor.mat_index` | 4 | refinish injection notes, unedited injection notes.txt, unedited injection notes +1 |
| `world.raws.mat_table.builtin` | 4 | refinish injection notes, unedited injection notes.txt, unedited injection notes +1 |
| `world.raws.mat_table.shield.mat_index` | 4 | refinish injection notes, unedited injection notes.txt, unedited injection notes +1 |
| `world.raws.mat_table.weapon.mat_index` | 4 | refinish injection notes, unedited injection notes.txt, unedited injection notes +1 |
| `world.items.all.` | 4 | refinish-container-struct-probe.lua, refinish-barrel-probe.lua, refinish-corpsepiece-probe.lua +1 |
| `world.raws.itemdefs.tools` | 4 | refinish-container-struct-probe.lua, refinish-tool-census.lua, refinish-vessel-probe.lua +1 |
| `world.raws.creatures.all` | 3 | probe-butcher.lua, refinish-size-probe.lua, probe-bone-item.lua |
| `world` | 3 | refinish-forge-probe.lua, refinish-steel-audit.lua, refinish-pitch-probe.lua |
| `world.raws.entities.all` | 3 | refinish-dump-entity-permissions.lua, refinish-print-entity-permissions.lua, refinish-find-missing.lua |
| `world.raws` | 3 | search_for_armor_tables.lua, refinish-corpse-probe.lua, probe-liquid-mint.lua |
| `world.frame_counter` | 3 | refinish-item-fix.lua, making-concrete-sand-diagnose.lua, making-concrete-sand-test.lua |

## Files by dump

### `tool_dump_2026-09-10/` (83 files)

| File | Lines | ! | What it covers | Key paths / API | Functions |
|---|---|---|---|---|---|
| `making-concrete-sand-diagnose-v2.lua` | 259 | ! | making-concrete-sand-diagnose-v2.lua SAND BAG DISPLAY: SEQUENCE REPRODUCTION TEST Attempts to r... | `cur_year_tick`, `world.items.all`, `dfhack.items.createItem`, `dfhack.items.getContainedItems` | `build_refs`, `copy_props`, `flush_log` +1 |
| `making-concrete-sand-diagnose.lua` | 193 |  | making-concrete-sand-diagnose.lua SAND BAG DIAGNOSTIC DUMP Dumps every field on: 1. Every bag c... | `world.frame_counter`, `world.items.all`, `dfhack.items.getContainedItems` | `dump_item`, `w` |
| `making-concrete-sand-test.lua` | 166 |  | making-concrete-sand-test.lua SAND MULTIPLIER END-TO-END TEST Starts the onJobCompleted hook wi... | `world.frame_counter`, `world.raws.inorganics.all`, `dfhack.items.createItem`, `dfhack.items.getContainedItems` | `log` |
| `making-fuel-job-probe.lua` | 339 | ! | @ module = true making-fuel-job-probe.lua MAKING FUEL: STALLED JOB PROBE READ ONLY. This script... | `world.items.all`, `world.items.other.CORPSE`, `dfhack.isMapLoaded`, `dfhack.items.getContainer` | `census_corpses`, `describe_location`, `dump_attached` +5 |
| `probe-aftermath.lua` | 248 | ! | @ module = true probe-aftermath.lua WHAT A CANCELLED JOB LEAVES BEHIND ONE QUESTION: after a re... | `world.items.all`, `world.items.other.TOOL`, `dfhack.items.getContainedItems`, `dfhack.items.getDescription` | `dump_bases`, `dump_containers`, `dump_feed` +3 |
| `probe-bone-item.lua` | 262 | ! | @ module = true probe-bone-item.lua BONE ITEM PROBE TWO QUESTIONS, and they need opposite fixes... | `world.items.all`, `world.raws.creatures.all`, `dfhack.isMapLoaded`, `dfhack.items.getDescription` | `all_bones`, `diff`, `dump` +6 |
| `probe-cycle-detect.lua` | 370 |  | @ module = true probe-cycle-detect.lua CYCLE DETECTION PROBE ONE QUESTION: why do six bone cons... | `world.items.all`, `world.jobs.list`, `dfhack.isMapLoaded`, `dfhack.items.getDescription` | `amount_of`, `find_reaction`, `log` +7 |
| `probe-liquid-mint.lua` | 364 | ! | @ module = true probe-liquid-mint.lua LIQUID MINT PROBE ONE QUESTION: when a retort completes, ... | `world.items.all`, `world.items.other.LIQUID_MISC`, `dfhack.isMapLoaded`, `dfhack.items.getContainer` | `count_keys`, `describe`, `fmt` +11 |
| `probe-pitch-tar.lua` | 153 |  | probe-pitch-tar.lua ONE PURPOSE: watch what a first generation tar item's dimension does across... | `world.items.all`, `world.jobs.list`, `dfhack.items.getContainedItems`, `dfhack.items.getContainer` | `describe_tar`, `tar_products` |
| `refinish-ashes-probe.lua` | 223 |  | refinish-ashes-probe.lua CAN CREMATION PRODUCE A BURYABLE, NAMED OBJECT Three questions, none a... | `world.buildings.all`, `dfhack.items.getDescription` | `coffin`, `enum_names`, `head` +4 |
| `refinish-bar-sprite-probe.lua` | 272 |  | refinish-bar-sprite-probe.lua BAR SPRITE MAPPING PROBE QUESTION: where does [BARS_GRAPHICS:PAGE... | `game`, `world.raws.graphics` | `describe`, `dump_page`, `fields_of` +6 |
| `refinish-barrel-probe.lua` | 380 | ! | refinish-barrel-probe.lua BARREL PROBE Measures what a barrel actually is, before any code is w... | `world.items.all`, `world.items.all.`, `dfhack.items.getContainedItems`, `dfhack.items.getDescription` | `collect`, `collector_accepts`, `d` +3 |
| `refinish-bars-probe.lua` | 203 |  | refinish-bars-probe.lua THE "BARS" SUFFIX: WHERE DOES THE WORD LIVE One question, asked four wa... | `world.items.all`, `world.raws.inorganics`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `as`, `describe`, `hr` +2 |
| `refinish-blankname-probe.lua` | 163 |  | refinish-blankname-probe.lua CAN A TOOL DROP ITS MATERIAL WORD A tool renders as material then ... | `world.items.all`, `world.raws.itemdefs.tools`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `blank_test`, `d`, `hr` +2 |
| `refinish-boulder-probe.lua` | 408 | ! | @ module = true refinish-boulder-probe.lua WHAT A BOULDER ACTUALLY IS The coke model needs one ... | `world.items.other.IN_PLAY`, `world.items.other`, `dfhack.isMapLoaded`, `dfhack.items.createItem` | `boulder_vector`, `fort_citizen`, `measure` +6 |
| `refinish-branch-probe.lua` | 352 | ! | refinish-branch-probe.lua BRANCH DATA PROBE, v2 v1 assumed the tree body was plane objects and ... | `world.plants`, `world.plants.all` | `count_tree`, `plane_first`, `tile_at` +1 |
| `refinish-building-check.lua` | 138 | ! | refinish-building-check.lua CUSTOM BUILDING PERMISSION DIAGNOSTIC A raw building can parse clea... | `plotinfo.civ_id`, `world.raws.buildings.workshops` | - |
| `refinish-building-probe.lua` | 198 | ! | refinish-building-probe.lua BUILDING DEF PERSISTENCE PROBE WHAT THIS ANSWERS A placed custom bu... | `world.buildings.all`, `world.raws.buildings`, `dfhack.gui.getSelectedBuilding` | `cmd_orphan`, `cmd_restore`, `cmd_status` +3 |
| `refinish-button-probe.lua` | 32 |  | refinish-button-probe.lua  (replace prior version) Uses the access pattern proven in making-con... | `game.main_interface.building` | - |
| `refinish-capacity-probe.lua` | 38 |  | refinish-capacity-probe.lua Reports capacity and volume for every container-capable item in the... | `world.items.all`, `dfhack.items.getCapacity` | - |
| `refinish-caption-patch.lua` | 128 |  | refinish-caption-patch.lua THE "BARS" CAPTION: WRITE IT THE HARD WAY The plain write was refuse... | `world.items.all`, `dfhack.internal.patchMemory`, `dfhack.items.getDescription` | `describe`, `hr`, `p` |
| `refinish-caption-probe.lua` | 136 |  | refinish-caption-probe.lua THE "BARS" CAPTION: IS IT WRITABLE, AND DOES DF READ IT df.item_type... | `world.items.all`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `describe`, `hr`, `p` |
| `refinish-civ-capability.lua` | 173 | ! | @ module = true refinish-civ-capability.lua CIV CAPABILITY DIAGNOSTIC Dumps the raw capability ... | `world.entities.all`, `world.raws.buildings.workshops` | `workshop_code` |
| `refinish-civ-tech-dump.lua` | 136 |  | @ module = true refinish-civ-tech-dump.lua CIV_TECH VS PANEL DUMP Read only. Changes nothing. P... |  | `yn` |
| `refinish-coal-key-test.lua` | 177 | ! | refinish-coal-key-test.lua WHAT SATISFIES THE COAL CHECK pressable() is a vmethod: engine code,... | `cursor`, `world.items.all`, `dfhack.items.createItem`, `dfhack.items.getDescription` | `coal_items`, `describe`, `flagstr` +1 |
| `refinish-container-probe.lua` | 126 |  | @ module = true refinish-container-probe.lua ONE QUESTION: what does DF do to CONTENTS when a r... | `world.jobs.list`, `dfhack.items.getDescription` | `arm`, `mark`, `say` +1 |
| `refinish-container-struct-probe.lua` | 339 | ! | refinish-container-struct-probe.lua CONTAINER STRUCTURE DUMP Enumerates everything DF exposes o... | `world.items.all`, `world.items.all.`, `dfhack.items.getContainedItems`, `dfhack.items.getDescription` | `describe`, `dump_object`, `main` +2 |
| `refinish-corpse-probe.lua` | 475 | ! | refinish-corpse-probe.lua  (v2) CAN A REAGENT TARGET A CITIZEN CORPSE READ ONLY. Creates nothin... | `plotinfo.civ_id`, `world.items.all`, `dfhack.items.getDescription`, `dfhack.units.isCitizen` | `audit`, `bits_of`, `corpses` +6 |
| `refinish-corpsepiece-probe.lua` | 650 | ! | refinish-corpsepiece-probe.lua CORPSE PIECE CLASS PROBE, for R9 Answers one question: if item_v... | `world.items.all`, `world.items.all.`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `bit`, `collect`, `d` +5 |
| `refinish-dedup-check.lua` | 99 | ! | @ module = true refinish-dedup-check.lua ENTITY_RAW DEDUP CHECK Read only. Changes nothing. Two... | `world.entities.all` | - |
| `refinish-desc-probe.lua` | 65 |  | @ module = true refinish-desc-probe.lua SELECTION PROBE FOR THE DESCRIPTION PANEL One question:... | `game.main_interface.view_sheets`, `dfhack.gui.getCurFocus` | `say`, `scalar`, `scan` +1 |
| `refinish-empty-patch.lua` | 65 |  | refinish-empty-patch.lua SET THE EMPTY BIT IN RAM, RIGHT NOW Measured this session: Refuel's ty... | `world.raws.reactions.reactions` | - |
| `refinish-empty-probe.lua` | 139 | ! | refinish-empty-probe.lua WHY DOES REFUEL'S CONTAINER REAGENT REFUSE A FULL ONE AND OURS NOT? Me... | `world.jobs.list`, `world.raws.reactions.reactions`, `dfhack.items.getContainedItems`, `dfhack.items.getDescription` | `get`, `hex`, `matches` |
| `refinish-flag-lab.lua` | 245 |  | refinish-flag-lab.lua THE GATE LAB: TEST A JOB-ITEM FLAG BEFORE SHIPPING IT Every reagent gate ... | `world.raws.reactions.reactions`, `dfhack.gui.getSelectedItem`, `dfhack.items.getContainedItems` | `find_word`, `inspect`, `printf` +3 |
| `refinish-floor-probe.lua` | 144 |  | refinish-floor-probe.lua WHERE DOES A FLOOR TILE GET ITS ART Peat draws as stone floor because ... | `cursor`, `texture`, `dfhack.gui.getMousePos`, `dfhack.maps.getTileType` | `hr`, `p` |
| `refinish-fuel-bypass-test.lua` | 321 |  | refinish-fuel-bypass-test.lua FUEL GATE BYPASS: MECHANISM TEST RIG One script, several mechanis... | `game.main_interface`, `world.jobs.list.next` | `clone_button`, `coal_rc`, `cp` +5 |
| `refinish-fuel-count-probe.lua` | 339 | ! | @ module = true refinish-fuel-count-probe.lua DOES A WIDENED FUEL FILTER SURVIVE count > 1 THE ... | `world.jobs.list.next`, `dfhack.isMapLoaded`, `dfhack.matinfo.decode` | `T`, `all_covered`, `coverage` +10 |
| `refinish-fuel-quantity-test.lua` | 252 | ! | refinish-fuel-quantity-test.lua FUEL: QUANTITY, MATERIAL GATING, AND PROMPT Three questions, on... | `world.jobs.list.next`, `dfhack.isMapLoaded`, `dfhack.items.getDescription` | `is_fuel_filter`, `log`, `poll` +1 |
| `refinish-fuel-slot-probe.lua` | 611 | ! | @ module = true refinish-fuel-slot-probe.lua WHAT A WIDENED FUEL FILTER WILL ACCEPT Supersedes ... | `world.jobs.list.next`, `world.raws.reactions.reactions`, `dfhack.isMapLoaded`, `dfhack.matinfo.decode` | `T`, `append_slots`, `attached_ids` +16 |
| `refinish-fuel-testbed.lua` | 346 |  | refinish-fuel-testbed.lua MAKING FUEL: TEST BENCH Spawns a sample of every item the char and sp... | `world.raws.itemdefs`, `world.raws.plants.all`, `dfhack.gui.getSelectedUnit`, `dfhack.items.createItem` | `find_subtype`, `find_unit`, `find_woods` +1 |
| `refinish-fuel-trace.lua` | 275 |  | refinish-fuel-trace.lua FUEL CHAIN TRACER Read only. Walks every link of the fuel access chain ... | `game.main_interface.view_sheets`, `world.buildings.all`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `blocking_flags`, `classes_of`, `has` +5 |
| `refinish-fuel-widen-probe.lua` | 206 | ! | refinish-fuel-widen-probe.lua FUEL FILTER WIDENING PROBE Answers the last open question: will D... | `world.jobs.list.next`, `dfhack.isMapLoaded` | `is_fuel_filter`, `log`, `poll` +4 |
| `refinish-furnace-entry-probe.lua` | 63 |  | refinish-furnace-entry-probe.lua Creates a workshop_graphics_info entry for CUSTOM furnaces, cl... | `world.raws.buildings.workshop_graphics_info`, `dfhack.textures.getTexposByHandle` | - |
| `refinish-furnace-mark.lua` | 47 |  | refinish-furnace-mark.lua Marks ALL nonzero cells (every stage) of is_furnace entries in worksh... | `texture.page`, `world.raws.buildings.workshop_graphics_info` | - |
| `refinish-furnace-probe.lua` | 126 |  | refinish-furnace-probe.lua  (replace prior version) ADAPTIVE FURNACE GRAPHICS CENSUS Prior cens... | `texture.page`, `world.raws.buildings.workshop_graphics_info` | `census` |
| `refinish-gate-delta.lua` | 146 | ! | @ module = true refinish-gate-delta.lua CAPABILITY GATE: BEFORE AND AFTER Read only. Changes no... | `world.entities.all` | `any`, `mark`, `prof` +2 |
| `refinish-icon-hunt.lua` | 124 |  | refinish-icon-hunt.lua VALUE HUNT: generic custom workshop icon The generic menu icon is BUILDI... | `buildreq`, `game` | `walk` |
| `refinish-icon-probe.lua` | 35 |  | refinish-icon-probe.lua Reverse-lookups a texpos against every loaded tile page. A hit names th... | `texture.page`, `world.raws.buildings.all` | - |
| `refinish-image-probe.lua` | 136 |  | refinish-image-probe.lua RUNTIME IMAGE PROBE Answers one question: which exact path string does... | `dfhack.filesystem.exists`, `dfhack.filesystem.isfile` | `add`, `hr`, `p` |
| `refinish-improvement-enum.lua` | 169 |  | @ module = true refinish-improvement-enum.lua IMPROVEMENT ENUM AND PREFIX RESOLVER Read only. C... | `world.raws.reactions.reactions` | - |
| `refinish-improvement-inspect.lua` | 189 |  | @ module = true refinish-improvement-inspect.lua IMPROVEMENT PRODUCT INSPECTOR Read only. Chang... | `world.raws.reactions.reactions` | `dump_improvement`, `dump_reagents`, `field_names` +1 |
| `refinish-item-fix.lua` | 405 | ! | REFINISH-ITEM-FIX Patches items created by dfhack.items.createItem() so they match the state of... | `world.frame_counter`, `world.items.all`, `dfhack.items.createItem`, `dfhack.items.getWeight` | `apply_bag_improvements`, `apply_flags_and_temp`, `apply_thermal_from_material` +3 |
| `refinish-labor-index.lua` | 96 |  | @ module = true refinish-labor-index.lua PERMITTED_JOB INDEX CHECK Answers one question: is ent... | `world.entities.all` | `enum_count`, `read` |
| `refinish-manager-probe.lua` | 143 |  | refinish-manager-probe.lua THE MANAGER, READ OFF THE LIVE STRUCTS Two surfaces, two modes. CREA... | `game.main_interface.create_work_order`, `world.manager_orders.all` | `bump`, `jobname`, `printf` +1 |
| `refinish-matcolor-probe.lua` | 197 | ! | refinish-matcolor-probe.lua WHAT COLOUR IS THIS MATERIAL, REALLY Reads the colour fields on a m... | `world.raws.descriptors.colors`, `dfhack.matinfo.find` | `by_name`, `hr`, `ipairs_index` +4 |
| `refinish-matswap-probe.lua` | 284 | ! | refinish-matswap-probe.lua PRODUCT MATERIAL REBIND PROBE Answers one question, and RETORT_DRAIN... | `world.jobs.list`, `world.raws.inorganics.all`, `dfhack.printerr` | `do_swap`, `ghosted_jobs`, `inorganic_name` +4 |
| `refinish-menu-icon-probe.lua` | 126 |  | refinish-menu-icon-probe.lua BUILD MENU ICON HUNT list_icon_texpos drives the workshop's own pa... | `game.main_interface`, `game.main_interface.build_selector` | `looks_iconish`, `walk` |
| `refinish-menu-icon.lua` | 105 |  | refinish-menu-icon.lua BUILD MENU ICON: SURVEY AND WRITE The build menu lives at main_interface... | `game.main_interface.construction`, `texture.page` | - |
| `refinish-menu-probe.lua` | 159 |  | refinish-menu-probe.lua THE FURNACE TASK MENU, READ OFF THE LIVE STRUCT Two questions, one stru... | `game.main_interface.building` | `classname`, `get`, `jobname` +1 |
| `refinish-mod-id.lua` | 100 |  | @ module = true refinish-mod-id.lua MOD ID DIAGNOSTIC Prints the [ID:...] from every installed ... | `dfhack.filesystem.exists`, `dfhack.filesystem.isdir` | `contains_file`, `read_mod_id` |
| `refinish-name-probe.lua` | 275 |  | refinish-name-probe.lua BAR NAME SUFFIX PROBE ESTABLISHED SO FAR B1: the suffix is not flag con... | `world.items.other.BAR`, `world.raws.plants.all`, `dfhack.items.getDescription`, `dfhack.items.getReadableDescription` | `any_plant_wood_token`, `evidence_row`, `find_bar` +6 |
| `refinish-permitted-job-enum.lua` | 117 |  | @ module = true refinish-permitted-job-enum.lua IDENTIFY THE permitted_job INDEX ENUM entity_ra... | `world.entities.all` | `enum_size`, `show` |
| `refinish-pitch-doctor.lua` | 411 | ! | refinish-pitch-doctor.lua  (D3) ADAPTIVE CYCLE DOCTOR One script, one run of any adaptive react... | `world.jobs.list`, `world.raws.reactions.reactions`, `dfhack.findScript`, `dfhack.items.getContainedItems` | `autopsy`, `bank_table`, `classify` +9 |
| `refinish-pitch-probe.lua` | 633 | ! | refinish-pitch-probe.lua BOIL_PITCH NO-PRODUCT PROBE Answers one question: why does "boil tar d... | `item_next_id`, `world`, `dfhack.items.getContainedItems`, `dfhack.items.getContainer` | `attach_sig`, `dig`, `dump_attachments` +13 |
| `refinish-pixel-probe.lua` | 46 | ! | refinish-pixel-probe.lua Three hand-packed 32x32 solid tiles via dfhack.textures.createTile, gr... | `world.raws.buildings.all`, `world.raws.buildings.workshop_graphics_info`, `dfhack.textures.createTile`, `dfhack.textures.getTexposByHandle` | `solid` |
| `refinish-plant-mat-probe.lua` | 202 | ! | refinish-plant-mat-probe.lua PLANT MATERIAL INJECTION: THE LOAD BEARING FACTS Round 2 was writt... | `world.raws.plants.all`, `world.units.active`, `dfhack.items.createItem`, `dfhack.items.getDescription` | `addr`, `hr`, `p` |
| `refinish-plant-product-probe.lua` | 164 |  | refinish-plant-product-probe.lua CAN A REACTION PRODUCE A PLANT MATERIAL createItem mints a bar... | `world.raws.reactions.reactions`, `dfhack.matinfo.decode`, `dfhack.matinfo.find` | `find_reaction`, `hr`, `p` |
| `refinish-plant-state-probe.lua` | 76 |  | refinish-plant-state-probe.lua PLANT STATE PROBE One report for two questions, read straight fr... | `world.raws.plants.all` | `carries_code`, `find_mat` |
| `refinish-range-probe.lua` | 26 |  | refinish-range-probe.lua  (replace prior version) Same-pixels-different-path test. Requires ret... | `world.raws.buildings.all`, `dfhack.textures.getTexposByHandle`, `dfhack.textures.loadTileset` | - |
| `refinish-reagent-prompt-test.lua` | 243 |  | refinish-reagent-prompt-test.lua ASK THE PLAYER HOW MANY One reaction, any batch size. Click CH... | `world.jobs.list.next`, `dfhack.isMapLoaded` | `ask`, `describe_reagent`, `is_fuel_filter` +3 |
| `refinish-render-probe.lua` | 46 |  | refinish-render-probe.lua Discriminates DEF RESOLUTION vs PIXELS for completed buildings. Write... | `texture.page`, `world.buildings.all` | - |
| `refinish-rot-flag-probe.lua` | 48 |  | refinish-rot-flag-probe.lua REAGENT FLAG DUMP The engine's reagent filters write job item flag ... |  | `dump_group` |
| `refinish-size-probe.lua` | 562 | ! | refinish-size-probe.lua ITEM SIZE PROBE Finds out where a runtime size (volume in cm3) can actu... | `world.items.all`, `world.raws.creatures.all`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `census`, `creature_paths`, `flush` +7 |
| `refinish-template-fill.lua` | 21 |  | refinish-template-fill.lua | `world.raws.buildings.workshop_graphics_info`, `dfhack.textures.getTexposByHandle` | - |
| `refinish-tool-census.lua` | 176 |  | refinish-tool-census.lua TOOL ITEM CENSUS A runnable script, not a module. Type this at the DFH... | `world.items.all`, `world.raws.itemdefs.tools` | - |
| `refinish-twin-probe.lua` | 83 |  | refinish-twin-probe.lua THREE QUESTIONS, ONE FILL, TWO LOOKS Both custom furnace twins get COMP... | `texture.page`, `world.raws.buildings.workshop_graphics_info`, `dfhack.textures.getTexposByHandle` | `wr` |
| `refinish-vessel-probe.lua` | 767 | ! | refinish-vessel-probe.lua VESSEL SIZING PROBE One job: work out how to size a VAT so it behaves... | `world.items.all`, `world.items.all.`, `dfhack.items.getContainedItems`, `dfhack.items.getDescription` | `collect`, `d`, `inspect` +4 |
| `refinish-wood-color-probe.lua` | 65 |  | refinish-wood-color-probe.lua WOOD COLOR CENSUS Walks every plant in the loaded raws, finds its... | `world.raws.descriptors.colors`, `world.raws.plants.all` | - |
| `refinish-wsgi-dump.lua` | 49 |  | refinish-wsgi-dump.lua Full-truth dump of workshop_graphics_info entries. refinish-wsgi-dump   ... | `world.raws.buildings.workshop_graphics_info` | - |
| `refinish-wsgi-fill.lua` | 85 |  | refinish-wsgi-fill.lua  (replace prior version) Custom-range is_furnace entries (subtype > 7, D... | `world.raws.buildings.workshop_graphics_info`, `dfhack.textures.getTexposByHandle` | `fill` |
| `refinish-wsgraphics-probe.lua` | 70 |  | refinish-wsgraphics-probe.lua  (replace prior version) flags is a PACKED RECORD: color_index bi... | `texture.page`, `world.raws.buildings.workshop_graphics_info` | - |
| `repair-module-liquids.lua` | 85 | ! | repair-module-liquids.lua ONE PURPOSE: repair first generation module liquids minted with stack... | `world.items.all`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | `module_mat` |
| `test-retort-claims.lua` | 495 | ! | @ module = true test-retort-claims.lua RETORT CLAIM TESTS Every claim the retort fix rests on, ... | `world.items.all`, `world.jobs.list`, `dfhack.isMapLoaded`, `dfhack.items.getContainedItems` | `check_adaptive_coverage`, `check_banks`, `check_corpsepiece_count` +15 |

### `Utility Scripts/` (46 files)

| File | Lines | ! | What it covers | Key paths / API | Functions |
|---|---|---|---|---|---|
| `check_reagent.lua` | 47 |  | check_reagent.lua Run this in the DFHack console while hovering over the Mason's shop | `dfhack.gui.getSelectedBuilding`, `dfhack.items.getDescription` | - |
| `civ_object_paths.txt` | 46 |  | _(no header comment)_ | `world.entities.all` | - |
| `color_instance_sorter.py` | 252 |  | _(no header comment)_ |  | - |
| `colour_match_block_grabber.py` | 1019 |  | _(no header comment)_ |  | - |
| `fiddler.lua` | 26 |  | fiddle.lua | `dfhack.matinfo.find` | - |
| `manual stuff.txt` | 248 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `missing_colours_sorter.py` | 232 |  | _(no header comment)_ |  | - |
| `moremanualstuff.txt` | 13 |  | _(no header comment)_ |  | - |
| `probe-butcher.lua` | 345 | ! | probe-butcher.lua BUTCHER OUTPUT PROBE ONE QUESTION: what does a butcher job actually emit for ... | `world.jobs.list`, `world.raws.creatures.all`, `dfhack.isMapLoaded`, `dfhack.job.getHolder` | `creature_of`, `log`, `mat_of` +6 |
| `probe-corpsepiece.lua` | 390 | ! | probe-corpsepiece.lua CORPSEPIECE CREATION PROBE THREE QUESTIONS, in order: 1. Can we create a ... | `item_next_id`, `world.items.all`, `dfhack.isMapLoaded`, `dfhack.items.createItem` | `cmd_dump`, `cmd_make`, `dump_item` +9 |
| `probe-hide.lua` | 511 | ! | probe-hide.lua HIDE PROBE ONE QUESTION: does a skin corpsepiece carrying material_amount.Leathe... | `world.items.all`, `world.raws.creatures.all`, `dfhack.isMapLoaded`, `dfhack.items.getDescription` | `amounts`, `body_shape`, `cmd_dump` +11 |
| `product_colour_fixer.py` | 272 |  | _(no header comment)_ |  | - |
| `refinish-artifact-probe.lua` | 57 |  | _(no header comment)_ | `world.items.all`, `world.raws.inorganics.all` | - |
| `refinish-clear-test.lua` | 21 |  | SCRIPT LOGIC | `world.raws.inorganics.all` | - |
| `refinish-clone-test.lua` | 61 |  | refinish-clone-test.lua Prototype 2: Memory Allocation and Deep Copy Test | `world.raws.inorganics.all` | - |
| `refinish-deep-probe.lua` | 81 |  | _(no header comment)_ | `world.items.all`, `world.raws.inorganics.all`, `dfhack.TranslateName`, `dfhack.translation` | `safe_name` |
| `refinish-deep-reaction-probe.lua` | 72 |  | refinish-probe-deep.lua PROBE FIRST: Deep Structural Verification of C++ Reaction Shapes | `world.raws.reactions.reactions` | - |
| `refinish-flag-probe.lua` | 29 |  | @ module = false refinish-flag-probe.lua | `world.raws.reactions.reactions` | - |
| `refinish-forge-probe.lua` | 323 |  | refinish-forge-probe.lua READ ONLY DIAGNOSTIC: DUPLICATE FORGE METALS Measures the live state b... | `world` | `color_word`, `id_family`, `state_names` |
| `refinish-forge-test.lua` | 86 |  | refinish-forge-test.lua Prototype 4: Reaction and Entity Injection (v50 Plotinfo Fix) | `plotinfo.civ_id`, `world.raws.inorganics.all` | - |
| `refinish-ghost-hunter.lua` | 87 |  | refinish-ghost-hunter.lua | `world.buildings.all`, `world.buildings.all...`, `dfhack.persistent.getSiteData` | - |
| `refinish-guard-probe.lua` | 265 |  | @ module = true refinish-guard-probe.lua  (v2) READ ONLY: VERIFY THE COMPLETION-FRAME CONTRACT ... | `world.raws.inorganics.all`, `dfhack.isMapLoaded`, `dfhack.matinfo.decode` | `field`, `inorg_id`, `job_via_general_refs` +8 |
| `refinish-inject-test.lua` | 53 |  | refinish-inject-test.lua Prototype 3: Global Array Injection | `world.raws.inorganics.all` | - |
| `refinish-inv-probe.lua` | 65 |  | @ module = false refinish-inv-probe.lua | `world.items.other.BAR`, `world.items.other.POWDER_MISC` | - |
| `refinish-item-type-probe-2.lua` | 39 |  | _(no header comment)_ | `world.jobs.list` | - |
| `refinish-item-type-probe.lua` | 41 |  | _(no header comment)_ | `world.jobs.list` | - |
| `refinish-metal-probe.lua` | 34 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `refinish-perf-probe.lua` | 543 | ! | refinish-perf-probe.lua SCRIPT LOGIC: REFINISH PERF PROBE (v4, TWO MECHANISMS) Times every repe... | `dfhack.getTickCount`, `dfhack.timeout` | `adopt`, `adopt_all`, `arm` +14 |
| `refinish-portal-probe.lua` | 70 |  | @ module = false refinish-portal-probe.lua | `plotinfo.civ_id`, `world.raws.reactions.reactions` | - |
| `refinish-powder-probe.lua` | 41 |  | refinish-powder-probe.lua Scans all vanilla reactions for a native POWDER_MISC reagent to map i... | `world.raws.reactions.reactions` | - |
| `refinish-probe.lua` | 56 |  | @ module = false refinish-probe.lua | `world.raws.reactions.reactions` | `dump_reaction` |
| `refinish-prototype` | 155 |  | @ module = true refinish-prototype.lua Isolated test environment for global tech evaluation and... | `world.entities.all`, `world.raws.reactions.reactions` | `inject_payload` |
| `refinish-prototype.lua` | 222 |  | @ module = true refinish-prototype.lua | `world.entities.all`, `world.raws.inorganics.all` | `inject_payload` |
| `refinish-reaction-forensics.lua` | 64 |  | refinish-forensics.lua Deep diagnostic probe for Reaction Reagents and Products | `world.raws.reactions.reactions` | `dump_product`, `dump_reagent` |
| `refinish-reaction-probe-v2.lua` | 74 |  | refinish-probe-v2.lua PROBE FIRST: Deep Structural Verification (Filtered for Inorganics & Meta... | `world.raws.inorganics.all`, `world.raws.reactions.reactions` | - |
| `refinish-reagent-probe.lua` | 26 |  | refinish-probe.lua Diagnostic tool to map vanilla reaction reagent arrays. | `world.raws.reactions.reactions` | - |
| `refinish-scan.lua` | 68 |  | refinish-scan.lua Prototype 1.1: State Color & Value Dictionary Builder | `world.raws.descriptors.colors`, `world.raws.inorganics.all` | - |
| `refinish-scrubber.lua` | 68 |  | THE UNIVERSAL SCRUBBER (LIFO TEARDOWN) | `plotinfo.civ_id`, `world.raws.inorganics.all` | `scrub_injected_data` |
| `refinish-steel-audit.lua` | 347 |  | refinish-steel-audit.lua READ ONLY AUDIT: STRANDED MATERIALS + STEEL REACTIONS Answers two ques... | `plotinfo.site_id`, `world`, `dfhack.persistent.getSiteData` | `field`, `gather`, `load_site_json` +1 |
| `refinish-struct-probe.lua` | 53 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `refinish-template-hunter` | 125 |  | refinish-test-hunter.lua Standalone Drop Script: Tests dynamic template acquisition and synthes... | `world.raws.reactions.reactions` | - |
| `refinish-template-hunter.lua` | 125 |  | refinish-test-hunter.lua Standalone Drop Script: Tests dynamic template acquisition and synthes... | `world.raws.reactions.reactions` | - |
| `refinish-verify-metals.lua` | 102 | ! | @ module = true refinish-verify-metals.lua Diagnostic tool to verify if civ.resources.metals al... | `world.entities.all`, `world.raws.inorganics.all` | - |
| `refinish-workshop-probe.lua` | 9 |  | refinish-workshop-probe.lua | `world.raws.reactions.reactions` | - |
| `test-name.lua` | 22 |  | _(no header comment)_ | `world.jobs.list` | - |
| `test-watcher.lua` | 47 |  | _(no header comment)_ | `world.jobs.list`, `dfhack.items.getDescription`, `dfhack.matinfo.decode` | - |

### `utility dump/` (32 files)

| File | Lines | ! | What it covers | Key paths / API | Functions |
|---|---|---|---|---|---|
| `refinish-civ-probe.lua` | 58 |  | @ module = true refinish-probe-civs.lua Read-only diagnostic tool to dump live civ resource and... | `world.entities.all`, `world.raws.inorganics.all`, `dfhack.getDFPath` | `dprint` |
| `refinish-color-probe.lua` | 47 |  | refinish-color-probe.lua READ-ONLY DIAGNOSTIC SCRIPT (UNRESTRICTED) | `world.raws.descriptors.colors`, `world.raws.inorganics.all` | `run_probe` |
| `refinish-compare-inorganic.lua` | 379 |  | REFINISH STEEL: INORGANIC COMPARATOR Purpose: Exhaustively compares any number of inorganic mat... | `world.raws.inorganics.all` | `copy_num_vector`, `copy_string_vector`, `find_inorganic` +2 |
| `refinish-compare-reaction.lua` | 390 |  | refinish-reaction-compare.lua Hardcoded analysis tool to compare ANY number of reactions using ... | `world.raws.reactions.reactions`, `world.raws.reactions.reactions[` | `extract_reaction`, `safe_iterate`, `safe_string_parse` +2 |
| `refinish-debug-civs.lua` | 64 |  | refinish-debug-civs.lua Hardened Diagnostic Probe | `world.entities.all`, `world.raws.inorganics.all`, `dfhack.script_environment` | `safe_id` |
| `refinish-deep-reaction-probe.lua` | 72 |  | refinish-probe-deep.lua PROBE FIRST: Deep Structural Verification of C++ Reaction Shapes | `world.raws.reactions.reactions` | - |
| `refinish-diag-entity.lua` | 70 |  | @ module = true refinish-diag-entity.lua Diagnostic probe to isolate the disconnect between eva... | `plotinfo.civ_id`, `world.raws.reactions.reactions`, `dfhack.script_environment` | - |
| `refinish-diagnose-pipeline.lua` | 44 |  | refinish-diagnose-pipeline.lua | `plotinfo.civ_id`, `world.raws.reactions.reactions` | - |
| `refinish-dump-entity-permissions.lua` | 37 |  | @ module = true refinish-dump-raws.lua | `world.raws.entities.all`, `dfhack.getDFPath` | - |
| `refinish-eval-tech-1.lua` | 95 |  | @ module = true refinish-probe-tech.lua DIAGNOSTIC: CIVILIZATION METALLURGY PROBE | `plotinfo.civ_id`, `world.raws.inorganics.all` | `run` |
| `refinish-eval-tech-2.lua` | 68 |  | refinish-probe-tech.lua | `plotinfo.civ_id`, `world.raws.inorganics.all` | - |
| `refinish-evaluate-metal-making.lua` | 137 |  | REFINISH STEEL: REACTION EVALUATOR (PROBE) Purpose: Safely evaluates all loaded reactions to id... | `world.raws.reactions.reactions` | `evaluate_reaction`, `run_evaluation` |
| `refinish-find-missing.lua` | 77 |  | @ module = true refinish-find-missing.lua | `world.raws.entities.all`, `world.raws.inorganics.all` | - |
| `refinish-metal-validation-broken-probe.lua` | 87 | ! | REFINISH STEEL: DIAGNOSTIC PROBE Purpose: Safely track the data path of a known modded metal to... | `plotinfo.civ_id`, `world.raws.inorganics.all`, `dfhack.isMapLoaded` | `run_probe` |
| `refinish-print-entity-permissions.lua` | 40 |  | @ module = true refinish-dump-entity.lua | `world.raws.entities.all`, `world.raws.reactions.reactions`, `dfhack.getDFPath` | - |
| `refinish-probe-3billion.lua` | 33 |  | refinish-probe.lua | `plotinfo.civ_id`, `world.raws.reactions.reaction_categories` | - |
| `refinish-probe-fuel.lua` | 26 |  | refinish-probe-fuel.lua | `world.raws.reactions.reactions` | - |
| `refinish-probe-geology.lua` | 39 |  | @ module = true refinish-probe-geology.lua | `world.entities.all`, `world.raws.inorganics.all` | - |
| `refinish-probe-missing-reactions.lua` | 70 |  | refinish-probe-missing-reactions.lua | `world.raws.inorganics.all`, `world.raws.reactions.reactions` | - |
| `refinish-probe-purple.lua` | 74 |  | refinish-probe-purple.lua | `world.raws.inorganics.all`, `world.raws.reactions.reactions` | - |
| `refinish-probe-x1` | 24 |  | refinish-probe.lua | `world.raws.reactions.reactions` | - |
| `refinish-probe-x1.lua` | 24 |  | refinish-probe.lua | `world.raws.reactions.reactions` | - |
| `refinish-prototype.lua` | 222 |  | @ module = true refinish-prototype.lua | `world.entities.all`, `world.raws.inorganics.all` | `inject_payload` |
| `refinish-reaction-automatic-tag.lua` | 36 |  | @ module = true refinish-probe-reaction.lua | `world.raws.reactions.reactions` | - |
| `refinish-reaction-forensics.lua` | 64 |  | refinish-forensics.lua Deep diagnostic probe for Reaction Reagents and Products | `world.raws.reactions.reactions` | `dump_product`, `dump_reagent` |
| `refinish-reaction-probe-v2.lua` | 74 |  | refinish-probe-v2.lua PROBE FIRST: Deep Structural Verification (Filtered for Inorganics & Meta... | `world.raws.inorganics.all`, `world.raws.reactions.reactions` | - |
| `refinish-read-inorganic.lua` | 337 |  | @ module = true REFINISH STEEL: INORGANIC DATA READER Purpose: Exhaustively extracts and organi... | `world.raws.inorganics.all` | `copy_num_vector`, `copy_string_vector`, `find_inorganic` +3 |
| `refinish-read-reaction.lua` | 271 |  | refinish-read-reaction.lua Hardcoded analysis tool using strictly mapped DFHack paths, protecte... | `world.raws.reactions.reactions`, `world.raws.reactions.reactions[` | `s`, `safe_iterate`, `w` |
| `refinish-struct-probe.lua` | 53 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `refinish-template-hunter.lua` | 125 |  | refinish-test-hunter.lua Standalone Drop Script: Tests dynamic template acquisition and synthes... | `world.raws.reactions.reactions` | - |
| `refinish-verify-metals.lua` | 102 | ! | @ module = true refinish-verify-metals.lua Diagnostic tool to verify if civ.resources.metals al... | `world.entities.all`, `world.raws.inorganics.all` | - |
| `refinish-workshop-probe.lua` | 9 |  | refinish-workshop-probe.lua | `world.raws.reactions.reactions` | - |

### `old_tools/` (26 files)

| File | Lines | ! | What it covers | Key paths / API | Functions |
|---|---|---|---|---|---|
| `check_colours_or_something.lua` | 17 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `clear_material_id_string.lua` | 6 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `inorganic_raw_differences` | 22 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `inorganic_raw_differences.lua` | 22 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `inorganic_raw_differences.txt` | 22 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `item_structural_differences.lua` | 19 |  | _(no header comment)_ |  | - |
| `local raws = df.global.world.raws.inorganics.lua` | 22 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `manual troubleshooting commands.txt` | 24 |  | _(no header comment)_ | `world.constructions`, `world.items.all` | - |
| `material_structure_differences.lua` | 21 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `notes.txt` | 64 |  | _(no header comment)_ | `dfhack.buildings.findAtTile`, `dfhack.gui.getMousePos` | - |
| `other_refinish_compare.lua` | 22 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `refinish injection notes` | 965 |  | _(no header comment)_ | `world.buildings.all`, `world.constructions`, `dfhack.gui.getMousePos`, `dfhack.gui.getSelectedItem` | - |
| `refinish injection notes.txt` | 965 |  | _(no header comment)_ | `world.buildings.all`, `world.constructions`, `dfhack.gui.getMousePos`, `dfhack.gui.getSelectedItem` | - |
| `refinish-autosave.lua` | 14 |  | _(no header comment)_ | `dfhack.persistent.getUnsavedSeconds`, `dfhack.run_script` | `trigger_ghost_save` |
| `refinish-kill-autosave.lua` | 1 |  | _(no header comment)_ | `d_init.autosave_mode` | - |
| `refinish-onmapload.lua` | 41 |  | _(no header comment)_ | `cur_year_tick`, `d_init.feature.autosave`, `dfhack.isMapLoaded`, `dfhack.run_command` | `calendar_loop` |
| `refinish-prep.lua` | 21 |  | _(no header comment)_ | `pause_state`, `dfhack.run_command`, `dfhack.run_script` | - |
| `refinish_audit.lua` | 75 |  | _(no header comment)_ | `world.raws.inorganics.all` | `check` |
| `refinish_authorize.lua` | 30 |  | _(no header comment)_ | `plotinfo.civ_id`, `plotinfo.group_id` | `authorize_metal` |
| `refinish_compare.lua` | 52 |  | _(no header comment)_ |  | - |
| `refinish_deinject.lua` | 0 |  | _(no header comment)_ | `world.raws.inorganics.all` | - |
| `search_for_armor_tables.lua` | 22 |  | _(no header comment)_ | `world.raws`, `world.raws.itemdefs` | `search_keys` |
| `test-menu.lua` | 17 |  | _(no header comment)_ | `game.main_interface.options.open`, `dfhack.timeout` | `menu_watcher` |
| `turn item to material manual command.txt` | 0 |  | _(no header comment)_ | `dfhack.gui.getSelectedItem` | - |
| `unedited injection notes` | 1146 |  | _(no header comment)_ | `world.buildings.all`, `world.constructions`, `dfhack.gui.getMousePos`, `dfhack.gui.getSelectedItem` | - |
| `unedited injection notes.txt` | 1146 |  | _(no header comment)_ | `world.buildings.all`, `world.constructions`, `dfhack.gui.getMousePos`, `dfhack.gui.getSelectedItem` | - |
