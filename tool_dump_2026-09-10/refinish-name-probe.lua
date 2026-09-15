-- refinish-name-probe.lua
-- ==========================================
-- BAR NAME SUFFIX PROBE
-- ==========================================
-- ESTABLISHED SO FAR
--   B1: the suffix is not flag controlled.
--   B2: the suffix is appended in the INORGANIC branch only.
--       Plant mode bars display bare names.
--   B3: the plant name prefix ("willow plant") survived renaming
--       the plant itself, which exposed the mechanism: PREFIX is
--       not composed at display time. It is a string field,
--       material.prefix, snapshotted at raw parse. The wheat path
--       map confirms it on live data: STRUCTURAL, LEAF and SEED
--       carry prefix "single-grain wheat", DRINK and MILL carry
--       prefix "" via [PREFIX:NONE] in the raws, and builtin COAL
--       carries "". Display is prefix + state name when the prefix
--       is non empty, state name alone when it is blank.
--
-- B4 confirms the field is what the name builder reads LIVE, then
-- rehearses the exact configuration the injected fuel materials
-- will use: a plain plant material, no special flags, prefix
-- blanked, state name "charcoal". A bare "charcoal" on the final
-- line locks the design: one module host plant, three materials,
-- prefix written empty at injection.
--
-- Every mutation is captured and restored inside the run. The
-- simulation is suspended for the whole script. The fuel key is
-- untouched.
--
-- USAGE (DFHack console, fort loaded, module band up, at least
-- one module coal bar in the fort)
--   refinish-name-probe                 probe with a bar of
--                                       MAKING_FUEL_CHARCOAL
--   refinish-name-probe <INORGANIC_ID>  probe with another mat
-- ==========================================

-- ==========================================
-- BUILD STAMP
-- ==========================================
-- Printed at the top of every run. If the number on screen is not
-- the number you expect, the file in the scripts folder is stale.
local PROBE_BUILD = 'B4  prefix field confirmation'
-- ==========================================

local args  = {...}
local TOKEN = (args[1] or 'MAKING_FUEL_CHARCOAL'):upper()

print('')
print('refinish-name-probe  build ' .. PROBE_BUILD)
print('')

-- ==========================================
-- NAME READERS
-- ==========================================
-- getDescription regenerates the name exactly as the game does
-- (modes: stack, singular, plural). getReadableDescription is
-- read as a second surface. pcall keeps any throw from aborting
-- the run with a mutation still in place.
local function name_of(item)
    local out = {}
    for mode = 0, 2 do
        local s = '<error>'
        pcall(function()
            s = dfhack.items.getDescription(item, mode, false)
        end)
        out[#out + 1] = s
    end
    return table.concat(out, ' | ')
end

local function readable_of(item)
    local s = '<error>'
    pcall(function()
        s = dfhack.items.getReadableDescription(item)
    end)
    return s
end

-- ==========================================
-- LOOKUPS
-- ==========================================
local function mat_info(token)
    local mi = nil
    pcall(function() mi = dfhack.matinfo.find(token) end)
    return mi
end

local function first_found(candidates)
    for _, tok in ipairs(candidates) do
        local mi = mat_info(tok)
        if mi then return mi, tok end
    end
    return nil
end

local function any_plant_wood_token()
    local tok = nil
    pcall(function()
        for _, p in ipairs(df.global.world.raws.plants.all) do
            for _, m in ipairs(p.material) do
                if tostring(m.id) == 'WOOD' then
                    tok = 'PLANT_MAT:' .. tostring(p.id) .. ':WOOD'
                    return
                end
            end
        end
    end)
    return tok
end

local function find_bar(inorg_index)
    local found = nil
    pcall(function()
        for _, it in ipairs(df.global.world.items.other.BAR) do
            if it.mat_type == 0
               and it.mat_index == inorg_index
               and not it.flags.in_job then
                found = it
                return
            end
        end
    end)
    return found
end

-- ==========================================
-- SETUP
-- ==========================================
local mi = mat_info('INORGANIC:' .. TOKEN)
if not mi then
    print('Material not found: INORGANIC:' .. TOKEN)
    print('Is the module band up in this fort?')
    return
end

local bar = find_bar(mi.index)
if not bar then
    print('No idle BAR of ' .. TOKEN .. ' found in this fort.')
    print('Produce one, then run the probe again.')
    return
end

local old_type, old_index = bar.mat_type, bar.mat_index

print(string.format('probing item id %d, INORGANIC:%s (index %d)',
    bar.id, TOKEN, mi.index))

local function swap_and_read(mtype, mindex)
    local shown, readable = '<error>', '<error>'
    local ok = pcall(function()
        bar.mat_type  = mtype
        bar.mat_index = mindex
        shown    = name_of(bar)
        readable = readable_of(bar)
    end)
    -- Restore runs no matter what happened above.
    bar.mat_type  = old_type
    bar.mat_index = old_index
    return ok, shown, readable
end

-- ==========================================
-- STEP 1: PREFIX EVIDENCE TABLE
-- ==========================================
-- Field reads only, no swaps: the live prefix and state name of
-- every material B2 and B3 measured, plus dog bone. Each display
-- already on record should equal prefix + state name, or the
-- state name alone where the prefix is blank. One mechanism,
-- every observation.
print('')
print('==========================================')
print('STEP 1: PREFIX EVIDENCE TABLE')
print('==========================================')

local function evidence_row(tok)
    local m = mat_info(tok)
    if not m then
        print(string.format('  %-44s lookup failed', tok))
        return m
    end
    local pfx, sn = '<unreadable>', '<unreadable>'
    pcall(function() pfx = m.material.prefix end)
    pcall(function() sn = m.material.state_name.Solid end)
    print(string.format('  %-44s prefix="%s"  state_name="%s"',
        tok, tostring(pfx), tostring(sn)))
    return m
end

local wood_tok = 'PLANT_MAT:WILLOW:WOOD'
local wood_mi  = evidence_row(wood_tok)
if not wood_mi then
    wood_tok = any_plant_wood_token()
    if wood_tok then wood_mi = evidence_row(wood_tok) end
end

local struct_mi, struct_tok = nil, nil
if wood_tok then
    struct_tok = wood_tok:gsub(':WOOD$', ':STRUCTURAL')
    struct_mi  = evidence_row(struct_tok)
end
evidence_row('PLANT_MAT:MUSHROOM_HELMET_PLUMP:STRUCTURAL')
evidence_row('PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK')
evidence_row('PLANT_MAT:SINGLE-GRAIN_WHEAT:MILL')
evidence_row('CREATURE_MAT:DOG:BONE')

-- ==========================================
-- STEP 2: THE TWO SIMULATIONS
-- ==========================================
-- Both run on the tree's STRUCTURAL material: plain, unflagged,
-- prefix carrying, the config B3 could not clear.
--
--   R1 POSITIVE CONTROL  prefix set to a nonsense word, state
--                        name to "charcoal". If the display says
--                        "xyzzy charcoal", the field is what the
--                        name builder reads, live, right now.
--   R2 FINAL CONFIG      prefix blanked, state name "charcoal".
--                        This IS the injected fuel material. A
--                        bare "charcoal" locks the design.
local function simulate(label, mi_case, tok, new_prefix, new_name)
    if not mi_case then
        print('  ' .. label .. ' : lookup failed, skipped')
        return
    end
    local mat = mi_case.material

    -- Capture originals. A nil slot was never reached and the
    -- restore below skips it.
    local saved = {}
    pcall(function() saved.pfx = mat.prefix end)
    pcall(function() saved.sn  = mat.state_name.Solid end)
    pcall(function() saved.sa  = mat.state_adj.Solid end)

    -- Mutate.
    pcall(function() mat.prefix          = new_prefix end)
    pcall(function() mat.state_name.Solid = new_name end)
    pcall(function() mat.state_adj.Solid  = new_name end)

    local ok, shown, readable = swap_and_read(mi_case.type, mi_case.index)

    -- Restore everything that was captured.
    if saved.pfx ~= nil then pcall(function() mat.prefix           = saved.pfx end) end
    if saved.sn  ~= nil then pcall(function() mat.state_name.Solid = saved.sn  end) end
    if saved.sa  ~= nil then pcall(function() mat.state_adj.Solid  = saved.sa  end) end

    print('')
    print(string.format('  %s  on %s', label, tok))
    print('    name:     ' .. (ok and shown or 'FAILED'))
    print('    readable: ' .. tostring(readable))
end

print('')
print('==========================================')
print('STEP 2: SIMULATIONS')
print('==========================================')

simulate('R1 control: prefix "xyzzy", name "charcoal"',
    struct_mi, tostring(struct_tok), 'xyzzy', 'charcoal')
simulate('R2 final config: prefix "", name "charcoal"',
    struct_mi, tostring(struct_tok), '', 'charcoal')

-- ==========================================
-- HOW TO READ THE RESULT
-- ==========================================
print('')
print('==========================================')
print('HOW TO READ THE RESULT')
print('==========================================')
print('  R1 "xyzzy charcoal" plus R2 bare "charcoal" closes the')
print('  case: material.prefix is the live prefix source, blanking')
print('  it yields the bare name, and the injected fuel materials')
print('  need exactly that: plant mode, plain flags, prefix "",')
print('  state names set to the three coal names. One host plant')
print('  carries all three.')
print('  Anything else: paste the run, the evidence table above')
print('  is what the reading falls back on.')
