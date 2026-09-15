# Reference material

Where to look things up for Refinish Metal. Two tiers: DFHack documentation stays
in this project, everything else lives in three public GitHub repos under
`jaymorbin` that are too large for the project mirror. Each repo carries its own
`INDEX.md`, copied into this project so it is readable without cloning.

---

## Tier 1: in this project (do not look for these in a repo)

DFHack documentation is kept here deliberately, because it is load-bearing for
almost every RM question and should never depend on a clone succeeding.

| File | Covers |
|---|---|
| `Lua_API.txt` | `dfhack.matinfo`, `textures.loadTileset`, `dfhack.timeout`, `createItem`, `reqscript`, persistent data |
| `modding-guide.txt` | `repeat-util` and `eventful`. `repeat-util` appears **nowhere** in `Lua_API.txt` |
| `overlay-dev-guide.txt` | overlay and HUD work |
| `Core.txt` | script loading, init files, environment |

The rest of the DFHack doc set was moved out. Notably `SYNTAX.txt` is the
df-structures **XML authoring** syntax, which RM never writes, and
`Structures-intro.txt` is a 12-line stub containing no structure data.

---

## Tier 2: the repos

## Standing instruction

**Do not answer from recall on any of the below. Read the source.**

| Question is about | Go to |
|---|---|
| DFHack API behaviour, `repeat-util`, `eventful`, overlays | Tier 1 files above, in this project |
| DF data structure layout, struct contents, enum values, `df.global` paths | `df_data_reference` |
| Vanilla token spellings, material and reaction IDs, graphics tags, ID collisions | `vanilla_raws_reference` |
| Whether something was attempted before | `refinish_metal_tools` |

If the answer is not in the project or the repos, say so rather than filling the
gap.

Clone once per session, on first need:

```bash
git clone --depth 1 https://github.com/jaymorbin/df_data_reference.git
git clone --depth 1 https://github.com/jaymorbin/vanilla_raws_reference.git
git clone --depth 1 https://github.com/jaymorbin/refinish_metal_tools.git
```

The sandbox resets between sessions, so this is not persistent. Sessions where
nothing calls for a lookup do not need a clone.

---

## `df_data_reference` — 9.6M, 65 files

Path maps and structure dumps captured from a **live game**. Flattened traces of
real objects, every field recursively expanded:

```
df.global.world.raws.reactions.reactions[116].code = "MAKE_QUICKLIME"
```

- 50 path maps across `Object Path Maps/` and `Path Maps/`
- Families covered: inorganics (23), reactions (14), mat_table (6), entities (3),
  plus buildings, jobs, itemdefs, descriptors, material_templates, plants
- Enum dumps (`item_type`, `furnace_type`, building types and skills), a struct
  field list for `item_corpsepiecest`, and assorted notes

**Go here when:** you need to know where a field actually lives, what a struct
really contains, or what an enum value maps to. This is ground truth over any
documentation, and over my recall.

---

## `vanilla_raws_reference` — 40M, 962 files

Complete unmodified vanilla DF raws plus vanilla sprite sheets, laid out mirroring
DF's own mod folders.

- 360 text raws: creatures, inorganics, reactions, items, entities, plants,
  descriptors, bodies, tissue and material templates, language, text sets
- 583 PNG sprite sheets across 20 directories, plus tile pages
- 17 Lua files, in `examples and notes/` and `interaction examples/`

**Go here when:** you need exact vanilla token spellings, existing material or
reaction IDs, graphics tags, or a check for ID collisions before injecting
something new.

Note: root `readme.txt` is Bay 12's public-domain waiver shipped with the raws,
not a repo description. The sprite images remain under copyright.

---

## `refinish_metal_tools` — 2.2M, 187 files

Archived probe scripts from RM development. These are **periodic clear-outs of the
live scripts folder**, so the four directories are strata rather than categories.

**These tools are not to be resurrected or run, and they are hit and miss.** Many
are failures, half-finished, or superseded. A script existing here is not evidence
that its approach worked. They are kept for the paths they reference, the engine
questions they record, and functions worth harvesting into generalized RM tooling
later. Always read a file before trusting it, and verify anything load-bearing
against the live game.

- 168 Lua, 4 Python, 173 unique by content
- 170 of 187 touch a `df.global` path
- Heaviest coverage: inorganics/materials (83), items (78), reactions (57),
  jobs (38), entities/civ (29), buildings/workshops (28)
- 40 of 187 files carry comments about something being broken, wrong, abandoned or
  superseded; those are flagged `!` in that repo's index
- `INDEX.md` carries a topic index, a path index of every `df.global` path the
  archive *references*, and per-file purpose and function listings

**Go here when:** the question is "did we already try this, and where?" The path
index shows prior attempts, not proven answers. Use it to find the earlier work,
then read it critically.

Two tools exist in two genuinely different versions, noted in that repo's index:
`refinish-deep-reaction-probe.lua` and `refinish-reaction-probe-v2.lua`.

---

## Caveats that apply to all three

- **Read-only.** I can clone and read. I cannot push. Changes still ship to you as
  FIND/REPLACE pairs.
- **Line endings are mixed and deliberate.** Nothing in these repos has been
  normalized by git. The tools archive in particular is mostly CRLF Lua, which
  cuts against RM's LF-for-Lua convention. Do not copy a file out of the archive
  into live RM without checking its endings.
- **These are reference, not source of truth for RM itself.** The live code in the
  project remains authoritative for how RM currently works. The archive records
  what was true when it was captured.
