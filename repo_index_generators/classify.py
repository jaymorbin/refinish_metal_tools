#!/usr/bin/env python3
"""Second pass: classify data-repo files by kind, and topic-tag the tools."""
import json, re, os, collections

d = json.load(open('extract.json'))

def read(p):
    return open(p,'rb').read().decode('utf-8', errors='replace').replace('\r\n','\n')

# --- classify data repo files ---
for x in d['data']:
    p = os.path.join('/df_data_reference', x['rel'])
    head = read(p)[:600]
    if x['subject'] and 'PATH MAP FOR' in head: kind = 'path map'
    elif x['subject']:                          kind = 'object map'
    elif head.lstrip().startswith('> :lua'):    kind = 'console dump'
    elif head.lstrip().startswith('FIELDS ON'): kind = 'struct field list'
    elif 'LastWriteTime' in head:               kind = 'stale dir listing'
    elif re.match(r'\s*--', head):              kind = 'notes'
    else:                                       kind = 'dump'
    x['kind'] = kind

# --- topic-tag the tools by dominant subsystem ---
TOPIC = [
 ('reactions',  ['raws.reactions']),
 ('inorganics/materials', ['raws.inorganics','matinfo','mat_table','material_templates']),
 ('items',      ['world.items','item_type','items.createItem','items.getDescription']),
 ('jobs',       ['world.jobs','job_type']),
 ('buildings/workshops', ['world.buildings','raws.buildings','workshop']),
 ('sprites/textures', ['texture','textures.','tile_page','getTexposByHandle']),
 ('units/creatures',  ['world.units','raws.creatures','units.']),
 ('entities/civ',     ['world.entities','raws.entities','plotinfo.civ']),
 ('plants',     ['raws.plants']),
 ('gui/overlay',['dfhack.gui','overlay','viewscreen']),
]
for t in d['tools']:
    blob = ' '.join(t['paths'] + t['apis'] + t['types'] + [t['name']])
    hits = [name for name, keys in TOPIC if any(k in blob for k in keys)]
    t['topics'] = hits or ['misc']

# duplicate detection
byhash = collections.defaultdict(list)
for t in d['tools']: byhash[t['md5']].append(t['rel'])
byname = collections.defaultdict(list)
for t in d['tools']: byname[t['name']].append(t)
for t in d['tools']:
    t['dup_of'] = [r for r in byhash[t['md5']] if r != t['rel']]
    others = [o for o in byname[t['name']] if o['rel'] != t['rel']]
    t['variant'] = bool(others) and any(o['md5'] != t['md5'] for o in others)

json.dump(d, open('extract.json','w'), indent=1)
print("data kinds:", dict(collections.Counter(x['kind'] for x in d['data'])))
print("topic spread:", dict(collections.Counter(tp for t in d['tools'] for tp in t['topics']).most_common()))
print("variants (differing same-name copies):", sorted({t['name'] for t in d['tools'] if t['variant']}))
