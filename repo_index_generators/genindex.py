#!/usr/bin/env python3
"""Generate the three repo INDEX.md files plus the project-side signpost."""
import json, os, collections, textwrap

d = json.load(open('extract.json'))
OUT = '/mnt/user-data/outputs'
os.makedirs(OUT, exist_ok=True)
def kb(n): return f"{n/1024:.0f}K" if n >= 1024 else f"{n}B"

# ============================================================ DATA REFERENCE
x = d['data']
pm = sorted([f for f in x if f['kind'] == 'path map'], key=lambda f: (f['family'] or 'zz', f['name']))
om = [f for f in x if f['kind'] == 'object map']
other = [f for f in x if f['kind'] not in ('path map', 'object map')]
L = []
L.append("# df_data_reference\n")
L.append("Path maps and structure dumps captured from a **live Dwarf Fortress game**. "
         "These are ground truth for where data actually lives in the DF object tree, "
         "as opposed to what documentation says about it.\n")
L.append("## How to use this\n")
L.append("Each path map is a flattened trace of one object, every field recursively "
         "expanded, in the form `df.global.world.raws.<family>.<list>[i].<field> = <value>`. "
         "To find where something lives, grep for the field or value name across the repo. "
         "The hit gives you the full access path verbatim.\n")
L.append("```\ngrep -rn 'reaction_class' 'Object Path Maps/' 'Path Maps/'\n```\n")
L.append(f"## Path maps ({len(pm)} files)\n")
L.append("Grouped by object family. 'Subject' is the object the map was taken from.\n")
fam = collections.defaultdict(list)
for f in pm: fam[f['family'] or 'other'].append(f)
for family in sorted(fam):
    L.append(f"### {family} ({len(fam[family])})\n")
    L.append("| File | Subject | Code | Size |")
    L.append("|---|---|---|---|")
    for f in sorted(fam[family], key=lambda a: a['name']):
        L.append(f"| `{f['name']}` | `{f['subject'] or ''}` | {f['code'] or ''} | {kb(f['size'])} |")
    L.append("")
if om:
    L.append(f"## Object maps ({len(om)})\n")
    L.append("| File | Subject | Code | Size |")
    L.append("|---|---|---|---|")
    for f in om: L.append(f"| `{f['name']}` | `{f['subject'] or ''}` | {f['code'] or ''} | {kb(f['size'])} |")
    L.append("")
L.append(f"## Dumps, enums and notes ({len(other)})\n")
L.append("| File | Kind | Lines | Size |")
L.append("|---|---|---|---|")
for f in sorted(other, key=lambda a: a['name']):
    L.append(f"| `{f['name']}` | {f['kind']} | {f['lines']} | {kb(f['size'])} |")
L.append("")
L.append("## Notes\n")
L.append("- `building_types_and_subtypes_numbers` has **no file extension**. Searches "
         "filtered on `*.txt` will miss it. Its `.txt` twin is byte-identical.")
L.append("- `path map directory.txt` is a stale PowerShell directory listing of an old "
         "local folder, not an index. It carries timestamps but no descriptions, and may "
         "name files no longer present. This INDEX supersedes it.")
open(f'{OUT}/df_data_reference_INDEX.md','w').write('\n'.join(L))

# ============================================================ VANILLA RAWS
r = d['raws']; sp = d['sprites']
L = []
L.append("# vanilla_raws_reference\n")
L.append("Complete unmodified Dwarf Fortress vanilla raws, plus the vanilla sprite sheets. "
         "Mirrors DF's own mod folder layout, so the directory name tells you the object "
         "type before you open anything.\n")
L.append("## How to use this\n")
L.append("This is the authority for **what vanilla actually defines**: token spellings, "
         "existing material and reaction IDs, graphics tags, and name collisions to avoid "
         "when injecting new content.\n")
L.append("```\ngrep -rln 'REACTION_CLASS:PITCH' vanilla_*/objects/\n```\n")
bydir = collections.defaultdict(list)
for f in r: bydir[f['dir'] or '(root)'].append(f)
L.append(f"## Raws files ({len(r)} text files)\n")
for dd in sorted(bydir):
    files = bydir[dd]
    types = collections.Counter(f['otype'] for f in files if f['otype'])
    tdesc = ', '.join(f"{k} x{v}" for k, v in types.most_common(4)) or 'no OBJECT token'
    tot = sum(f['ndefs'] for f in files)
    L.append(f"### `{dd}/`\n")
    L.append(f"{len(files)} files, {tdesc}" + (f", {tot} definitions total" if tot else "") + "\n")
    big = sorted(files, key=lambda a: -a['ndefs'])[:8]
    if any(f['ndefs'] for f in big):
        L.append("| File | Object | Defs | Examples |")
        L.append("|---|---|---|---|")
        for f in big:
            if not f['ndefs']: continue
            L.append(f"| `{f['name']}` | {f['otype']} | {f['ndefs']} | {', '.join(f['sample'][:4])} |")
        if len(files) > 8: L.append(f"| _...{len(files)-8} more_ | | | |")
        L.append("")
L.append(f"## Sprite sheets ({sum(v['n'] for v in sp.values())} images across {len(sp)} directories)\n")
L.append("| Directory | Images | Size |")
L.append("|---|---|---|")
for dd in sorted(sp, key=lambda a: -sp[a]['bytes']):
    L.append(f"| `{dd}/` | {sp[dd]['n']} | {kb(sp[dd]['bytes'])} |")
L.append("")
L.append("## Notes\n")
L.append("- `readme.txt` at the root is **Bay 12's public-domain waiver** that shipped with "
         "the raws, not a description of this repo. GitHub renders it as the landing page.")
L.append("- Images remain under copyright per that notice; the text raws are public domain.")
open(f'{OUT}/vanilla_raws_reference_INDEX.md','w').write('\n'.join(L))
print("data + raws indexes written")
