#!/usr/bin/env python3
"""Extract index data from the three reference repos."""
import os, re, json, hashlib
from collections import defaultdict

def read(p):
    with open(p, 'rb') as f:
        return f.read().decode('utf-8', errors='replace').replace('\r\n', '\n')

def walk(root, exts=None):
    for dp, dn, fn in os.walk(root):
        if '.git' in dp.split(os.sep): continue
        for f in fn:
            p = os.path.join(dp, f)
            if exts is None or os.path.splitext(f)[1].lower() in exts:
                yield p, os.path.relpath(p, root)

# ---------------------------------------------------------------- DATA REPO
data = []
for p, rel in walk('/df_data_reference'):
    txt = read(p)
    lines = [l for l in txt.split('\n')[:40]]
    subject, depth, code = None, None, None
    for l in lines:
        m = re.match(r'PATH MAP FOR:\s*(.+)', l)
        if m: subject = m.group(1).strip()
        m = re.match(r'MAX DEPTH:\s*(\d+)', l)
        if m: depth = m.group(1)
        if subject is None:
            m = re.match(r'\s*(df\.global\.[\w\.\[\]]+?)\s*=\s*<', l)
            if m: subject = m.group(1)
        m = re.search(r'\.code\s*=\s*"([^"]+)"', l)
        if m and not code: code = m.group(1)
        m = re.search(r'\.id\s*=\s*"([^"]+)"', l)
        if m and not code: code = m.group(1)
    # root object family
    fam = None
    if subject:
        m = re.match(r'df\.global\.world\.raws\.(\w+)', subject)
        fam = m.group(1) if m else (subject.split('.')[3] if subject.count('.') > 3 else None)
    data.append(dict(rel=rel, dir=os.path.dirname(rel), name=os.path.basename(rel),
                     size=os.path.getsize(p), lines=txt.count('\n'),
                     subject=subject, depth=depth, code=code, family=fam))

# ---------------------------------------------------------------- RAWS REPO
raws, sprites = [], defaultdict(lambda: dict(n=0, bytes=0))
OBJ_TOKEN = re.compile(r'^\[([A-Z_]+):([^\]]+)\]', re.M)
for p, rel in walk('/vanilla_raws_reference'):
    ext = os.path.splitext(p)[1].lower()
    if ext in ('.png', '.bmp'):
        d = os.path.dirname(rel)
        sprites[d]['n'] += 1; sprites[d]['bytes'] += os.path.getsize(p)
        continue
    if ext not in ('.txt', '.lua'): continue
    txt = read(p)
    m = re.search(r'\[OBJECT:(\w+)\]', txt)
    otype = m.group(1) if m else None
    defs = []
    if otype:
        for tok, val in OBJ_TOKEN.findall(txt):
            if tok == otype or (otype == 'ITEM' and tok.startswith('ITEM_')) \
               or (otype == 'GRAPHICS' and tok in ('TILE_PAGE',)) \
               or (otype == 'DESCRIPTOR_COLOR' and tok == 'COLOR'):
                defs.append(val.split(':')[0])
    raws.append(dict(rel=rel, dir=os.path.dirname(rel), name=os.path.basename(rel),
                     size=os.path.getsize(p), otype=otype, ndefs=len(defs),
                     sample=defs[:6]))

# ---------------------------------------------------------------- TOOLS REPO
PATH_RE  = re.compile(r'\bdf\.global\.[A-Za-z0-9_.\[\]]+')
API_RE   = re.compile(r'\bdfhack\.[A-Za-z0-9_.]+')
DFTYPE_RE= re.compile(r'\bdf\.(?!global)([a-z_]+)\b')
FUNC_RE  = re.compile(r'^\s*(?:local\s+)?function\s+([A-Za-z0-9_.:]+)\s*\(', re.M)
tools = []
for p, rel in walk('/refinish_metal_tools'):
    ext = os.path.splitext(p)[1].lower()
    txt = read(p)
    h = hashlib.md5(open(p,'rb').read()).hexdigest()
    # leading comment block = stated purpose
    purpose = []
    for l in txt.split('\n')[:12]:
        s = l.strip()
        if s.startswith('--'):
            s = s.lstrip('-').strip()
            if s and not set(s) <= set('-=# '): purpose.append(s)
        elif s and purpose: break
        elif s: break
    paths = sorted({re.sub(r'\[[^\]]*\]', '[]', x) for x in PATH_RE.findall(txt)})
    apis  = sorted(set(API_RE.findall(txt)))
    types = sorted(set(DFTYPE_RE.findall(txt)))
    funcs = sorted(set(FUNC_RE.findall(txt)))
    tools.append(dict(rel=rel, dir=rel.split(os.sep)[0], name=os.path.basename(rel),
                      ext=ext, size=os.path.getsize(p), lines=txt.count('\n'), md5=h,
                      purpose=' '.join(purpose)[:300], paths=paths, apis=apis,
                      types=types, funcs=funcs))

json.dump(dict(data=data, raws=raws, sprites=dict(sprites), tools=tools),
          open('extract.json','w'), indent=1)
print(f"data:{len(data)}  raws:{len(raws)}  spritedirs:{len(sprites)}  tools:{len(tools)}")
