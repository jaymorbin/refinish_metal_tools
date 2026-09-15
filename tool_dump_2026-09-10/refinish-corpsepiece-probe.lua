-- refinish-corpsepiece-probe.lua
-- ==========================================
-- CORPSE PIECE CLASS PROBE, for R9
-- ==========================================
-- Answers one question: if item_value stopped hardcoding FLESH for
-- corpse pieces, what class would each piece in this fort actually
-- get, and what would that do to its yield?
--
-- WHY THIS EXISTS
--
-- R9 said bones classify FLESH and blamed the classifier's wet tissue
-- test. That was wrong twice over. BONE_TEMPLATE carries SPEC_HEAT
-- 1000, so it clears that gate comfortably, and more to the point the
-- classifier is never consulted for a corpse piece at all.
-- item_value computes `classify(mi)` at the top and then the CORPSE
-- and CORPSEPIECE branches throw the answer away:
--
--     return whole * frac, size * frac, 'FLESH', nil, 'piece', ...
--
-- The literal string. So every bone, skull, hide and severed limb in
-- the game is priced as wet tissue by construction, not by accident.
--
-- Whether that should change is a BALANCE decision and this probe does
-- not make it. It only measures what the alternative would be.
--
-- WHAT MAKES THIS TEST DISCRIMINATING
--
-- The register's own lesson: a test that never discriminates is the
-- signature to watch for. Here the failure mode is that every piece
-- reports the SAME material regardless of what it visibly is, which
-- would mean DF hands a piece its creature's general material rather
-- than the tissue's. That is the outcome that would make the whole
-- idea a dead end, so this probe checks for it explicitly and says so
-- in as many words rather than leaving it to be noticed.
--
-- USAGE
--   refinish-corpsepiece-probe          survey every piece in the fort
--   refinish-corpsepiece-probe full     one row per item, no grouping
-- ==========================================

-- reqscript returns the script's ENVIRONMENT, and the tuning file
-- keeps everything in a global table called T inside that. Same path
-- the ghost uses at its line 90, so the two cannot drift apart.
local T = nil
local ok_tuning = pcall(function()
    T = reqscript('making-fuel-tuning').T
end)

local args = {...}
local MODE = (args[1] or ''):lower()

-- ==========================================
-- CLASSIFIER COPY
-- ==========================================
-- A faithful copy of classify() as it stands in making-fuel-ghost.lua
-- on 2026-09-08, INCLUDING the L0.9 fat test added for R16.
--
-- Copied rather than called because classify is a file local in the
-- ghost and nothing exports it. That means it can drift. If the ghost's
-- classifier changes, re-cut this block; do not trust a stale copy to
-- report on live behaviour.
--
-- Only L0.9 through L2 are reproduced. Those are the layers a creature
-- material can reach. L2.5 and L3 are for the mod's own materials and
-- for stone, and a corpse piece cannot land there.
-- ==========================================

local BY_ID = {
    PARCHMENT = 'LEATHER', SKIN      = 'LEATHER',
    HAIR      = 'HAIR',    SCALE     = 'HAIR',
    NAIL      = 'BONE',    CHITIN    = 'BONE',  CARTILAGE = 'BONE',
    SEED      = 'PLANT',   LEAF      = 'PLANT', FRUIT     = 'PLANT',
    MILL      = 'PLANT',   DRINK     = 'PLANT', STRUCTURAL = 'PLANT',
    FAT       = 'FAT',     TALLOW    = 'FAT',   SOAP      = 'FAT',
    WOOD      = 'WOOD',
}

-- Every flag the classifier tests, in the order it tests them. Kept as
-- data so the report can show which ones are actually set on an item
-- rather than only the verdict.
local FLAG_ROWS = {
    { cls = 'BONE',    bits = { 'BONE', 'TOOTH', 'HORN', 'HOOF',
                                'SHELL', 'PEARL' } },
    { cls = 'LEATHER', bits = { 'LEATHER' } },
    { cls = 'HAIR',    bits = { 'SILK', 'YARN', 'FEATHER' } },
    { cls = 'WOOD',    bits = { 'WOOD' } },
    { cls = 'PLANT',   bits = { 'THREAD_PLANT', 'STRUCTURAL_PLANT_MAT' } },
}

-- Reads one material flag safely. A flag name that does not exist on
-- this DF build raises rather than returning false, so every read is
-- wrapped and an unreadable flag counts as unset.
local function bit(m, name)
    local v = false
    pcall(function() v = m.flags[name] end)
    return v == true
end

-- Returns class, why, and the list of flags found set. Mirrors the
-- ghost's ordering exactly: gate, fat, wet tissue, flags, material id.
local function would_classify(mi)
    if not mi or not mi.material then return 'WOOD', 'no matinfo', {} end
    local m = mi.material

    local ig, sp = nil, 0
    pcall(function() ig = m.heat.ignite_point end)
    pcall(function() sp = m.heat.spec_heat or 0 end)

    local set = {}
    for _, row in ipairs(FLAG_ROWS) do
        for _, b in ipairs(row.bits) do
            if bit(m, b) then table.insert(set, b) end
        end
    end

    if not ig or ig <= 0 or ig >= 60000 then
        return 'INERT', 'no ignite point', set
    end

    local id = ''
    pcall(function() id = tostring(m.id):upper() end)

    -- L0.9, the R16 fix: fat before wet tissue can swallow it.
    if BY_ID[id] == 'FAT' then return 'FAT', 'id ' .. id, set end

    -- L1, flags.
    if sp >= 4000 then return 'FLESH', 'wet tissue', set end
    for _, row in ipairs(FLAG_ROWS) do
        for _, b in ipairs(row.bits) do
            if bit(m, b) then return row.cls, 'flag ' .. b, set end
        end
    end

    -- L2, material id.
    if BY_ID[id] then return BY_ID[id], 'id ' .. id, set end

    return 'UNRESOLVED', 'fell past L2, id ' .. id, set
end

-- ==========================================
-- ITEM COLLECTION
-- ==========================================
-- Same defensive pattern the ghost uses for its own scans: prefer the
-- typed vector, fall back to items.all, and give up rather than guess
-- if neither resolves.
-- ==========================================

local WANTED = {
    [df.item_type.CORPSEPIECE] = 'CORPSEPIECE',
    [df.item_type.CORPSE]      = 'CORPSE',
    [df.item_type.REMAINS]     = 'REMAINS',
}

local function collect()
    local vec = nil
    pcall(function() vec = df.global.world.items.all end)
    if not vec then
        dfhack.printerr('Could not read df.global.world.items.all.')
        return {}
    end

    local out = {}
    for _, it in ipairs(vec) do
        pcall(function()
            local ty = tonumber(it:getType())
            if WANTED[ty] then
                table.insert(out, { item = it, kind = WANTED[ty] })
            end
        end)
    end
    return out
end

-- Everything worth knowing about one piece, read defensively. Any
-- field that will not resolve comes back nil and prints as a dash,
-- because a blank column is information and a crash is not.
local function inspect(rec)
    local it = rec.item
    local r = { kind = rec.kind }

    pcall(function() r.id = it.id end)
    pcall(function() r.desc = dfhack.items.getDescription(it, 0) end)
    pcall(function() r.amount = it.material_amount end)

    local mi = nil
    pcall(function() mi = dfhack.matinfo.decode(it) end)
    r.has_mi = (mi ~= nil)

    pcall(function() r.token = tostring(mi:getToken()) end)
    pcall(function() r.mat_id = tostring(mi.material.id) end)
    pcall(function() r.spec = mi.material.heat.spec_heat end)
    pcall(function() r.ignite = mi.material.heat.ignite_point end)
    pcall(function() r.density = mi.material.solid_density end)
    pcall(function() r.mat_type = it.mat_type end)
    pcall(function() r.mat_index = it.mat_index end)

    r.class, r.why, r.flags = would_classify(mi)

    -- ---- DF'S OWN TEMPERATURE PREDICATES ----
    -- The field dump named isTemperatureSafe and isDamagedByHeat on
    -- item_corpsepiecest. Those are the engine's own answers, so the
    -- FIRE_SAFE question can be settled by asking DF instead of by
    -- inferring from ignite points.
    --
    -- The signature is not assumed. Every arity and argument that
    -- might be right is tried and whatever resolves is reported,
    -- including reporting that none did.
    r.tsafe = {}
    for _, cat in ipairs({ 0, 1, 2, 3 }) do
        pcall(function()
            local v = it:isTemperatureSafe(cat)
            if v ~= nil then r.tsafe[cat] = (v == true or v == 1) end
        end)
    end
    pcall(function()
        local v = it:isTemperatureSafe()
        if v ~= nil then r.tsafe.none = (v == true or v == 1) end
    end)
    pcall(function()
        local v = it:isDamagedByHeat()
        if v ~= nil then r.heatdmg = (v == true or v == 1) end
    end)

    -- Heat properties, for the FIRE_SAFE question. DF's FIRE_SAFE
    -- reagent flag keys off whether a material survives fire, so these
    -- are the numbers that would decide whether a gate could refuse a
    -- dragon at the reagent instead of at the valuation.
    pcall(function() r.melt   = mi.material.heat.melting_point end)
    pcall(function() r.boil   = mi.material.heat.boiling_point end)
    pcall(function() r.heatdm = mi.material.heat.heatdam_point end)

    -- ---- CORPSE FLAGS, DISCOVERED NOT ASSUMED ----
    -- The field this whole probe now exists for. It is not read by
    -- name from memory: whatever bitfield the item carries is walked
    -- and every set bit reported. If the field does not exist, that is
    -- reported too, because a probe that prints nothing is the worst
    -- outcome there is.
    r.cflags = {}
    r.cflags_read = false
    for _, fname in ipairs({ 'corpse_flags', 'flags', 'body_flags' }) do
        pcall(function()
            local bf = it[fname]
            if bf == nil then return end
            local names = {}
            for k, v in pairs(bf) do
                if v == true then table.insert(names, fname .. '.' .. k) end
            end
            if #names > 0 then r.cflags_read = true end
            for _, n in ipairs(names) do table.insert(r.cflags, n) end
        end)
    end

    -- The relsize fraction, the same arithmetic item_value does, so a
    -- piece can be recognised by how much of its creature it is.
    pcall(function()
        local rs     = it.body.body_part_relsize
        local status = it.body.components.body_part_status
        local total, present = 0, 0
        for k = 0, #rs - 1 do
            total = total + rs[k]
            local gone = true
            pcall(function() gone = status[k].missing end)
            if not gone then present = present + rs[k] end
        end
        if total > 0 then
            r.frac = present / total
            r.parts = present
            r.parts_total = total
        end
    end)

    return r
end

-- ==========================================
-- REPORT
-- ==========================================

-- Every token on these rows starts CREATURE_MAT:, which is 13
-- characters of nothing and pushes the rest of the table out of
-- alignment. Dropped for display only; the full token is still what
-- gets read and compared.
local function short(tok)
    if not tok then return '-' end
    return (tostring(tok):gsub('^CREATURE_MAT:', ''))
end

local function d(v, fmt)
    if v == nil then return '-' end
    if fmt then return string.format(fmt, v) end
    return tostring(v)
end

local function main()
    print('')
    print('CORPSE PIECE CLASS PROBE, R9')
    print('item_value currently returns the literal FLESH for every one')
    print('of these. This is what the classifier would say instead.')
    print('')

    if not ok_tuning or not T then
        print('NOTE: making-fuel-tuning did not load, so the yield impact')
        print('      table below is skipped. The class findings are still')
        print('      valid; only the numbers that price them are missing.')
        print('')
    end

    local recs = collect()
    if #recs == 0 then
        print('No corpses, corpse pieces or remains in the fort.')
        print('Butcher something and run this again. Use BUTCHERED stock:')
        print('register N1 records that gui/create-item bones carry a whole')
        print('skeleton part list against a count of one, so no yield')
        print('number taken from them means anything.')
        return
    end

    local rows = {}
    for _, rec in ipairs(recs) do table.insert(rows, inspect(rec)) end

    -- ---- PER ITEM ----
    if MODE == 'full' then
        print(string.format('%-6s %-12s %-24s %-8s %-6s %-7s %s',
              'id', 'kind', 'material', 'class', 'amt', 'share',
              'item'))
        for _, r in ipairs(rows) do
            print(string.format('%-6s %-12s %-24s %-8s %-6s %-7s %s',
                  d(r.id), r.kind, short(r.token), r.class,
                  d(r.amount), d(r.frac, '%.4f'), d(r.desc)))
        end
        print('')
    end

    -- ---- GROUPED BY MATERIAL ----
    -- The grouping is the point. If every visibly different piece lands
    -- in one bucket, the material is not piece specific and the whole
    -- idea is dead.
    local groups, order = {}, {}
    for _, r in ipairs(rows) do
        local key = (r.token or 'UNREADABLE') .. ' | ' .. r.kind
        if not groups[key] then
            groups[key] = { n = 0, r = r, names = {} }
            table.insert(order, key)
        end
        local g = groups[key]
        g.n = g.n + 1
        if #g.names < 3 and r.desc then table.insert(g.names, r.desc) end
    end

    print('BY MATERIAL')
    print(string.format('%-4s %-26s %-12s %-9s %-14s %s',
          'n', 'material', 'kind', 'would be', 'why', 'example'))
    for _, key in ipairs(order) do
        local g = groups[key]
        local r = g.r
        print(string.format('%-4d %-26s %-12s %-9s %-14s %s',
              g.n, short(r.token), r.kind, r.class, r.why,
              g.names[1] or '-'))
    end
    print('')

    -- ---- MATERIAL DETAIL ----
    print('MATERIAL PROPERTIES, one row per distinct material')
    print(string.format('%-26s %-8s %-8s %-8s %s',
          'material', 'spec', 'ignite', 'density', 'flags set'))
    for _, key in ipairs(order) do
        local r = groups[key].r
        local fl = (#r.flags > 0) and table.concat(r.flags, ',') or 'none'
        print(string.format('%-26s %-8s %-8s %-8s %s',
              short(r.token), d(r.spec), d(r.ignite), d(r.density), fl))
    end
    print('')

    -- ---- THE DISCRIMINATION CHECK ----
    -- Stated out loud, pass or fail, because the previous probe in this
    -- project reported a column that read the same for every row and
    -- nobody noticed for a session.
    local pieces, tokens = 0, {}
    local n_tokens = 0
    for _, r in ipairs(rows) do
        if r.kind == 'CORPSEPIECE' then
            pieces = pieces + 1
            local t = r.token or 'UNREADABLE'
            if not tokens[t] then tokens[t] = 0 n_tokens = n_tokens + 1 end
            tokens[t] = tokens[t] + 1
        end
    end

    print('DISCRIMINATION CHECK')
    if pieces == 0 then
        print('  INCONCLUSIVE. No corpse pieces in the fort, only whole')
        print('  corpses or remains. Butcher something and re-run.')
    elseif n_tokens < 2 then
        local only = next(tokens)
        print(string.format(
            '  NOT DISCRIMINATING. All %d corpse piece(s) report the same',
            pieces))
        print(string.format('  material: %s', tostring(only)))
        print('  Either the fort holds only one kind of piece, or DF hands')
        print('  every piece its creature general material rather than the')
        print('  tissue. Butcher a second creature and keep both the bones')
        print('  and the skin, then re-run. If it still reads one material,')
        print('  R9 cannot be fixed this way and the entry should say so.')
    else
        print(string.format(
            '  DISCRIMINATING. %d corpse piece(s) across %d distinct',
            pieces, n_tokens))
        print('  materials, so DF does give a piece its own tissue and the')
        print('  classifier has something real to read.')
    end
    print('')

    -- ---- YIELD IMPACT ----
    -- What changing it would actually cost or pay, so the balance
    -- decision is made on numbers rather than on principle.
    if ok_tuning and T then
        local CLASS, SPLIT = nil, nil
        pcall(function() CLASS = T.CLASS end)
        pcall(function() SPLIT = T.FLUID_SPLIT end)

        if CLASS then
            local flesh = CLASS.FLESH
            print('YIELD IMPACT, solid side')
            print(string.format('  FLESH, what every piece gets today: %s',
                  d(flesh, '%.3f')))
            print(string.format('%-4s %-26s %-9s %-9s %s',
                  'n', 'material', 'would be', 'factor', 'change'))
            for _, key in ipairs(order) do
                local g = groups[key]
                local f = CLASS[g.r.class]
                local ch = '-'
                if f and flesh and flesh > 0 then
                    ch = string.format('%.2fx', f / flesh)
                end
                print(string.format('%-4d %-26s %-9s %-9s %s',
                      g.n, short(g.r.token), g.r.class, d(f, '%.3f'), ch))
            end
            print('')
        end

        if SPLIT then
            print('YIELD IMPACT, liquid side')
            local function show(cls)
                local sp = SPLIT[cls]
                if not sp then return '-' end
                local parts = {}
                for cur, share in pairs(sp) do
                    table.insert(parts,
                        string.format('%s %.3f', cur, share))
                end
                table.sort(parts)
                return table.concat(parts, ', ')
            end
            print('  FLESH, today: ' .. show('FLESH'))
            local said = {}
            for _, key in ipairs(order) do
                local c = groups[key].r.class
                if not said[c] then
                    said[c] = true
                    print(string.format('  %-8s would be: %s', c, show(c)))
                end
            end
            print('')
        end
    end

    -- ---- FIELD DISCOVERY ----
    -- Every field DFHack says a corpse piece has. Printed once, from
    -- the struct definition rather than from a guess, so the next
    -- question about these items can be answered by reading rather
    -- than by another round of this.
    print('FIELDS ON item_corpsepiecest, from the struct definition')
    local fnames, got_fields = {}, false
    pcall(function()
        for name in pairs(df.item_corpsepiecest._fields) do
            table.insert(fnames, name)
            got_fields = true
        end
    end)
    if got_fields then
        table.sort(fnames)
        local line = '  '
        for _, n in ipairs(fnames) do
            if #line + #n + 2 > 74 then print(line) line = '  ' end
            line = line .. n .. '  '
        end
        if line ~= '  ' then print(line) end
    else
        print('  Could not read df.item_corpsepiecest._fields on this')
        print('  build. The flag survey below still stands.')
    end
    print('')

    -- ---- FLAG SURVEY ----
    -- The discriminator hunt. If one bit separates the butchery
    -- products, bone [14] and horn [2] and hoof [4] and skull, from
    -- the combat severings, head and neck and tail and lower body,
    -- then it is the field R9 needs and it will be obvious here.
    print('CORPSE FLAGS SET, and on what')
    local seen_flag, forder = {}, {}
    local any_flags = false
    for _, r in ipairs(rows) do
        if r.kind == 'CORPSEPIECE' then
            for _, fn in ipairs(r.cflags) do
                any_flags = true
                if not seen_flag[fn] then
                    seen_flag[fn] = { n = 0, eg = {} }
                    table.insert(forder, fn)
                end
                local e = seen_flag[fn]
                e.n = e.n + 1
                if #e.eg < 3 then table.insert(e.eg, r.desc or '?') end
            end
        end
    end
    if not any_flags then
        print('  NO FLAG BITS SET ANYWHERE, or no readable bitfield.')
        print('  If the field list above names something flag shaped that')
        print('  this did not walk, say so and I will aim at it directly.')
    else
        table.sort(forder)
        print(string.format('  %-28s %-4s %s', 'flag', 'n', 'examples'))
        for _, fn in ipairs(forder) do
            local e = seen_flag[fn]
            print(string.format('  %-28s %-4d %s', fn, e.n,
                  table.concat(e.eg, ' | ')))
        end
    end
    print('')

    print('PIECES WITH NO FLAGS SET, the other half of the same question')
    local none_n = 0
    for _, r in ipairs(rows) do
        if r.kind == 'CORPSEPIECE' and #r.cflags == 0 then
            none_n = none_n + 1
            if none_n <= 8 then
                print('  ' .. d(r.desc))
            end
        end
    end
    if none_n == 0 then print('  none, every piece carries at least one bit') end
    if none_n > 8 then print(string.format('  ... and %d more', none_n - 8)) end
    print('')

    -- ---- FIRE SAFE ----
    -- Whether a reagent gate could refuse a fireproof piece outright,
    -- which is the clean version of the armour model. Jay confirmed in
    -- play that a false flag DOES exclude: RETORT_CORPSEPIECE carries
    -- bone false and cancels on a bone stack with "Needs 14 body
    -- parts". So fire_safe false is a real candidate, and these are
    -- the numbers that decide whether it would bite.
    print('HEAT PROPERTIES, and what DF ITSELF says about them')
    print('  60001 is DF\'s never sentinel. Note that MELT reads 60001')
    print('  for every material here, so if FIRE_SAFE keys on melting')
    print('  point it is true of everything and a gate is useless. If it')
    print('  keys on ignite or heat damage, only scale is safe and a')
    print('  gate would work. The tsafe columns are DF answering.')
    print('')
    print(string.format('  %-24s %-7s %-7s %-7s %-14s %s',
          'material', 'ignite', 'heatdm', 'melt', 'isTempSafe',
          'byHeat'))
    local safe_set, unsafe_set = {}, {}
    for _, key in ipairs(order) do
        local r = groups[key].r
        local ts = {}
        for _, cat in ipairs({ 0, 1, 2, 3 }) do
            if r.tsafe[cat] ~= nil then
                table.insert(ts, cat .. '=' .. tostring(r.tsafe[cat]))
            end
        end
        if r.tsafe.none ~= nil then
            table.insert(ts, 'bare=' .. tostring(r.tsafe.none))
        end
        local tsl = (#ts > 0) and table.concat(ts, ' ') or 'unreadable'
        print(string.format('  %-24s %-7s %-7s %-7s %-14s %s',
              short(r.token), d(r.ignite), d(r.heatdm), d(r.melt),
              tsl, d(r.heatdmg)))

        local fireproof = (not r.ignite or r.ignite >= 60000)
        if fireproof then table.insert(safe_set, r)
        else table.insert(unsafe_set, r) end
    end
    print('')

    -- ---- THE VERDICT, STATED ----
    -- Same rule as the discrimination check above: if the column reads
    -- the same for a fireproof material and a burnable one, it cannot
    -- be used as a gate and this says so rather than leaving it to be
    -- noticed.
    print('FIRE_SAFE VERDICT')
    if #safe_set == 0 or #unsafe_set == 0 then
        print('  INCONCLUSIVE. The fort holds only one kind of material')
        print('  by ignite point, so nothing here can separate them.')
        print('  Spawn a dragon part alongside ordinary stock and re-run.')
    else
        local cats = {}
        for _, cat in ipairs({ 0, 1, 2, 3, 'none' }) do
            local a, b = safe_set[1].tsafe[cat], unsafe_set[1].tsafe[cat]
            if a ~= nil and b ~= nil then
                cats[#cats + 1] = { cat = cat, splits = (a ~= b),
                                    safe = a, burn = b }
            end
        end
        if #cats == 0 then
            print('  isTemperatureSafe did not resolve on any arity, so')
            print('  DF was not asked and this is unanswered. The gate')
            print('  would have to be tested by putting fire_safe false')
            print('  on RETORT_CORPSEPIECE and watching whether bones')
            print('  still go in.')
        else
            local any = false
            for _, c in ipairs(cats) do
                if c.splits then
                    any = true
                    print(string.format(
                        '  SEPARATES at category %s: fireproof reads %s,'
                        .. ' burnable reads %s.', tostring(c.cat),
                        tostring(c.safe), tostring(c.burn)))
                end
            end
            if any then
                print('  So FIRE_SAFE is NOT keyed on melting point,')
                print('  which is 60001 for everything here. A')
                print('  fire_safe gate on the reagent would refuse')
                print('  fireproof pieces and leave ordinary stock')
                print('  alone, which is the armour model.')
            else
                print('  NOT DISCRIMINATING. Every category reads the')
                print('  same for a dragon scale and for bone, so this')
                print('  predicate cannot be the basis of a gate. If')
                print('  FIRE_SAFE uses it, fire_safe false would')
                print('  exclude everything and the retort would stop')
                print('  accepting corpse pieces entirely. Do not ship')
                print('  that gate on this evidence.')
            end
        end
    end
    print('')

    print('WHAT THIS DOES NOT DECIDE')
    print('  Whole CORPSE items should almost certainly keep the hardcoded')
    print('  FLESH. item_value says why, and it is a good reason: a')
    print('  corpse material is whichever tissue dominates, so the same')
    print('  dwarf reads BONE on one corpse and SKIN on another. That')
    print('  argument does not obviously carry to a butchered piece,')
    print('  which is one tissue by construction, and the rows above are')
    print('  the evidence for whether it does.')
    print('')
end

main()