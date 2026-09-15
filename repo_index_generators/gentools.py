#!/usr/bin/env python3
"""Generate the tools-archive knowledge index."""
import json, os, collections
d = json.load(open('extract.json'))
t = d['tools']; OUT = '/mnt/user-data/outputs'
def kb(n): return f"{n/1024:.0f}K" if n >= 1024 else f"{n}B"
def short(p): return p.replace('df.global.', '').replace('[]', '')

L = []
L.append("# refinish_metal_tools\n")
L.append("Archived probe scripts and utilities from Refinish Metal development. These are "
         "**periodic clear-outs of the live scripts folder**, taken whenever it got too full, "
         "too messy, or had scripts running that interfered with testing. The directory names "
         "are strata, not categories.\n")
L.append("These tools are **not meant to be run again**. They are kept for reference: the "
         "paths they proved out, the engine facts they encode, and the functions worth "
         "harvesting into generalized RM tooling later.\n")
L.append("## Reliability warning\n")
L.append("**These probes are hit and miss. Many are failures, half-finished, or were "
         "superseded.** A script existing here is not evidence that its approach worked. "
         f"{sum(1 for x in t if x['caveat'])} of {len(t)} files contain comments about "
         "something being broken, wrong, abandoned or superseded, but that language covers "
         "three different cases that cannot be told apart mechanically: the script is broken, "
         "the script *found* that something else was wrong (the valuable case), or the script "
         "records what an earlier version got wrong. Files carrying any such comment are "
         "marked (!) below. Read the comment before trusting the code, and verify anything "
         "load-bearing against the live game.\n")
L.append("## How to use this\n")
L.append("The question this archive answers is *\"did we already work this out, and where?\"* "
         "Use the Topic index below to narrow, then grep the file.\n")
L.append("```\ngrep -rn 'reaction_class' --include='*.lua' .\ngrep -rln 'getTexposByHandle' .\n```\n")
n_uniq = len({x['md5'] for x in t})
L.append(f"**{len(t)} files** ({n_uniq} unique by content), {sum(1 for x in t if x['ext']=='.lua')} Lua, "
         f"{sum(1 for x in t if x['ext']=='.py')} Python. "
         f"{sum(1 for x in t if x['paths'])} touch a `df.global` path.\n")

# ---- duplicate / variant warning
var = sorted({x['name'] for x in t if x['variant']})
L.append("## Versions that differ\n")
L.append("Eight tool names appear in two dumps. All are byte-identical copies except these, "
         "where the two copies genuinely differ and you need to know which you are reading:\n")
for v in var:
    cps = [x for x in t if x['name'] == v]
    L.append(f"- `{v}`")
    for c in sorted(cps, key=lambda a: -a['lines']):
        L.append(f"  - `{c['rel']}` ({c['lines']} lines, {kb(c['size'])})")
L.append("")

# ---- topic index
L.append("## Topic index\n")
L.append("Which files carry knowledge about which subsystem. A file can appear more than once.\n")
bytopic = collections.defaultdict(list)
for x in t:
    for tp in x['topics']: bytopic[tp].append(x)
for tp in sorted(bytopic, key=lambda a: -len(bytopic[a])):
    files = sorted(bytopic[tp], key=lambda a: a['name'])
    L.append(f"### {tp} ({len(files)})\n")
    L.append(', '.join(f"`{f['name']}`" for f in files))
    L.append("")

# ---- path index
L.append("## Path index\n")
L.append("The `df.global` paths this archive **references**, and where. These are attempts, not verified findings: "
         "A path appearing here means a script reached for it, not that it worked. Use this to find prior attempts, then read the file and verify against the live game.\n")
pc = collections.Counter(p for x in t for p in x['paths'])
L.append("| Path | Files | Where |")
L.append("|---|---|---|")
for p, c in pc.most_common(30):
    who = [x['name'] for x in t if p in x['paths']][:3]
    more = f" +{c-3}" if c > 3 else ""
    L.append(f"| `{short(p)}` | {c} | {', '.join(who)}{more} |")
L.append("")

# ---- per-directory file listing
L.append("## Files by dump\n")
bydir = collections.defaultdict(list)
for x in t: bydir[x['dir']].append(x)
for dd in sorted(bydir, key=lambda a: -len(bydir[a])):
    files = sorted(bydir[dd], key=lambda a: a['name'])
    L.append(f"### `{dd}/` ({len(files)} files)\n")
    L.append("| File | Lines | ! | What it covers | Key paths / API | Functions |")
    L.append("|---|---|---|---|---|---|")
    for f in files:
        purpose = (f['purpose'][:95] + '...') if len(f['purpose']) > 95 else f['purpose']
        purpose = purpose.replace('|', '/') or '_(no header comment)_'
        keys = [short(p) for p in f['paths'][:2]] + [a for a in f['apis'][:2]]
        fn = ', '.join(f"`{x}`" for x in f['funcs'][:3]) + (f" +{len(f['funcs'])-3}" if len(f['funcs']) > 3 else "")
        L.append(f"| `{f['name']}` | {f['lines']} | {'!' if f['caveat'] else ''} | {purpose} | "
                 f"{', '.join('`'+k+'`' for k in keys)} | {fn or '-'} |")
    L.append("")
open(f'{OUT}/refinish_metal_tools_INDEX.md','w').write('\n'.join(L))
print(f"tools index: {len(L)} lines, {os.path.getsize(OUT+'/refinish_metal_tools_INDEX.md')/1024:.0f}K")
