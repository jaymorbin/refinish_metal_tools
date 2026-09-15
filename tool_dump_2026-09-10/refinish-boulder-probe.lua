--@ module = true
-- refinish-boulder-probe.lua
-- ==========================================
-- WHAT A BOULDER ACTUALLY IS
-- ==========================================
-- The coke model needs one number nobody in this project has read:
-- the internal volume of a stone boulder. The wiki says 60000, which
-- would be 6000 internally on the tenth scale every other size in the
-- module uses, but a wiki figure is somebody's note and the whole
-- point of this file is to stop treating those as measurements.
--
-- It matters because absolute yield scales with the square root of
-- volume. At 3000 a bituminous boulder pays 15.35 charcoal
-- equivalents under the new tuning; at 6000 it pays 21.7. The ratios
-- between coals do not move, so the rank table is safe either way,
-- but every bar count printed at a furnace does.
--
-- ---- WHAT IT READS, AND WHY FROM RAM ----
-- Everything here comes off the live material struct, never the raws
-- text. The raws are the seed; RAM is the thing the game is actually
-- using, it carries every default the template filled in, and it
-- carries whatever another mod did to it after load. A number read
-- from a text file is a number that was true before the world
-- existed.
--
-- ---- THE THREE QUESTIONS ----
--   1. Is getVolume flat across every stone, or does it vary?
--      If it varies, the coke model has a second axis for free and
--      the rank table gets easier. If it is flat, rank is the only
--      axis and the declaration stands.
--   2. What does it actually read?
--   3. Does JET pass the classifier's ignite gate? STONE_TEMPLATE
--      carries IGNITE_POINT:NONE, so jet may well be INERT, which
--      would make COKE_JET pay exactly zero the moment it goes
--      adaptive. Measured here rather than assumed.
--
-- ---- MODES ----
--   (none)  Read only. Walks the boulders the fort holds and reports.
--   mint    For any coal the fort does not happen to have lying
--           about, mint ONE boulder, measure it, destroy it. Loud
--           about every step. Nothing survives the call.
--
-- Console only. This is an instrument, not a feature.
-- ==========================================

local LOG_TAG = 'BOULDER PROBE: '

local tuning = nil
pcall(function() tuning = reqscript('making-fuel-tuning') end)

local function say(msg)
    print(LOG_TAG .. msg)
end

-- The materials the coke work turns on. Both peats ride along
-- because dried peat is the module's only adaptive boulder feed
-- today, so its numbers are the ones that can be checked against a
-- live ghost log, and the raw one is the moisture contrast.
--
-- JET IS GONE. Measured: ignite 60001, melting 11500, boiling 14000.
-- It fails the classifier's ignite gate and behaves like glass, not
-- coal, so it is out of the fuel family and nothing here should keep
-- inviting it back.
local WANTED = {
    'INORGANIC:LIGNITE',
    'INORGANIC:COAL_BITUMINOUS',
    'INORGANIC:PEAT',
    'INORGANIC:MAKING_FUEL_PEAT_DRIED',
}

-- ==========================================
-- READING WITHOUT GUESSING
-- ==========================================
-- One statement per pcall and the failure returned, not discarded, so
-- a field this build does not carry prints ABSENT instead of quietly
-- becoming an initialiser. Same rule the fuel probe learned the hard
-- way.
local function rd(obj, ...)
    local path = { ... }
    local ok, v = pcall(function()
        local cur = obj
        for _, k in ipairs(path) do cur = cur[k] end
        return cur
    end)
    if not ok or v == nil then return nil, 'ABSENT' end
    return v, tostring(v)
end

-- ==========================================
-- FINDING THE BOULDERS
-- ==========================================
-- items.other is keyed by df.items_other_id, NOT by df.item_type, and
-- indexing it with the wrong enum returns nil in silence. So the
-- bucket is tried by name and the answer is verified by walking it;
-- if anything about that fails, the whole IN_PLAY vector is filtered
-- on getType instead, which is slower and always correct.
local function boulder_vector()
    local vec, how = nil, nil
    pcall(function()
        local id = df.items_other_id.BOULDER
        if id then
            vec = df.global.world.items.other[id]
            how = 'items.other.BOULDER'
        end
    end)
    if vec then return vec, how, false end

    local filtered = {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.other.IN_PLAY) do
            local t = nil
            pcall(function() t = it:getType() end)
            if t == df.item_type.BOULDER then
                table.insert(filtered, it)
            end
        end
    end)
    return filtered, 'IN_PLAY filtered on getType', true
end

local function token_of(item)
    local tok = '?'
    pcall(function()
        local mi = dfhack.matinfo.decode(item)
        if mi then tok = tostring(mi:getToken()) end
    end)
    return tok
end

-- ==========================================
-- ONE BOULDER, EVERY NUMBER ON IT
-- ==========================================
local function measure(item)
    local m = {}
    m.token = token_of(item)
    -- These three are METHODS, not fields, so they are called rather
    -- than walked. Each keeps its own failure: a nil here means the
    -- method did not answer, not that the value was zero.
    local ok, v = pcall(function() return tonumber(item:getVolume()) end)
    m.volume = ok and v or nil
    ok, v = pcall(function() return tonumber(item:getStackSize()) end)
    m.stack = ok and v or nil
    ok, v = pcall(function() return tonumber(item:getTotalDimension()) end)
    m.dimension = ok and v or nil

    pcall(function()
        local mi = dfhack.matinfo.decode(item)
        if not mi or not mi.material then return end
        local mat = mi.material
        m.density = rd(mat, 'solid_density')
        m.spec    = rd(mat, 'heat', 'spec_heat')
        m.ignite  = rd(mat, 'heat', 'ignite_point')
        m.melt    = rd(mat, 'heat', 'melting_point')
        m.boil    = rd(mat, 'heat', 'boiling_point')
        m.value   = rd(mat, 'material_value')
        local classes = {}
        pcall(function()
            -- reaction_class is a vector of string POINTERS. The text
            -- is on .value; tostring on the pointer yields an address.
            for _, s in ipairs(mat.reaction_class) do
                table.insert(classes, tostring(s.value))
            end
        end)
        m.classes = table.concat(classes, ' ')
    end)
    return m
end

local function print_measure(label, m)
    say(string.format('  %-34s vol=%-7s stack=%-4s dim=%-6s',
        label, tostring(m.volume), tostring(m.stack),
        tostring(m.dimension)))
    say(string.format('      density=%-7s spec_heat=%-7s value=%s',
        tostring(m.density), tostring(m.spec), tostring(m.value)))
    -- ---- THE INERT GATE ----
    -- The ghost classifier refuses anything whose ignite point is
    -- missing, zero or 60000 and over, and returns INERT, which
    -- multiplies every yield to nothing. This is the line that says
    -- whether a material can be adaptive fuel at all.
    local ig = tonumber(m.ignite)
    local passes = ig and ig > 0 and ig < 60000
    say(string.format('      ignite=%-8s melt=%-8s boil=%-8s  %s',
        tostring(m.ignite), tostring(m.melt), tostring(m.boil),
        passes and 'BURNS' or 'INERT: adaptive yield would be ZERO'))
    if m.classes and m.classes ~= '' then
        say('      reaction_class: ' .. m.classes)
    end
end

-- ==========================================
-- MINTING, WHEN THE FORT HAS NONE
-- ==========================================
-- A boulder is minted under a living citizen, measured, and removed
-- in the same call. Nothing is left behind and nothing is hidden: if
-- the removal fails it says so by id, loudly, so the stray can be
-- dealt with rather than discovered later.
local function fort_citizen()
    local found = nil
    pcall(function()
        for _, u in ipairs(df.global.world.units.active) do
            local ok_u = false
            pcall(function()
                ok_u = dfhack.units.isCitizen(u)
                    and dfhack.units.isAlive(u)
                    and not u.flags1.caged
                    and u.pos.x >= 0
            end)
            if ok_u then found = u return end
        end
    end)
    return found
end

local function mint_and_measure(token)
    local mi = nil
    pcall(function() mi = dfhack.matinfo.find(token) end)
    if not mi then
        say(string.format('  %-34s NOT IN THIS WORLD', token))
        return nil
    end
    local u = fort_citizen()
    if not u then
        say('  no living citizen to mint against; skipping mint.')
        return nil
    end
    local item = nil
    local ok, err = pcall(function()
        local made = dfhack.items.createItem(
            u, df.item_type.BOULDER, -1, mi.type, mi.index)
        item = made and made[1]
    end)
    if not ok or not item then
        say(string.format('  %-34s MINT FAILED: %s', token,
            tostring(err)))
        return nil
    end
    local m = measure(item)
    local id = item.id
    local gone = pcall(function() dfhack.items.remove(item) end)
    if not gone then
        pcall(function()
            item.flags.garbage_collect = true
            item.flags.hidden = true
        end)
        say(string.format('  MINTED BOULDER %d COULD NOT BE REMOVED.'
            .. ' Flagged for collection. Check it.', id))
    end
    return m
end

-- ==========================================
-- THE REPORT
-- ==========================================
function run(mode)
    if not dfhack.isMapLoaded() then
        print('No map loaded.')
        return
    end
    local minting = (mode == 'mint')

    local vec, how, is_list = boulder_vector()
    local n = 0
    pcall(function() n = #vec end)
    say(string.format('boulder vector: %s, %d item(s)%s', how, n,
        is_list and ' (fallback path)' or ''))

    -- ---- QUESTION 1: IS getVolume FLAT ----
    -- Grouped by material so a per material difference cannot hide
    -- inside an average. Distinct volumes are collected rather than
    -- min and max, because two values would be the interesting answer
    -- and a range hides how many there were.
    local seen, order = {}, {}
    pcall(function()
        for _, it in ipairs(vec) do
            local tok = token_of(it)
            local g = seen[tok]
            if not g then
                g = { n = 0, vols = {}, sample = it }
                seen[tok] = g
                table.insert(order, tok)
            end
            g.n = g.n + 1
            local ok, v = pcall(function()
                return tonumber(it:getVolume())
            end)
            if ok and v then g.vols[v] = (g.vols[v] or 0) + 1 end
        end
    end)

    table.sort(order)
    local all_vols = {}
    say('')
    say('---- VOLUME BY MATERIAL ----')
    for _, tok in ipairs(order) do
        local g = seen[tok]
        local parts = {}
        for v, c in pairs(g.vols) do
            all_vols[v] = true
            table.insert(parts, string.format('%d x%d', v, c))
        end
        table.sort(parts)
        say(string.format('  %-40s %4d boulder(s)  volume: %s',
            tok, g.n, table.concat(parts, ', ')))
    end

    local distinct = {}
    for v in pairs(all_vols) do table.insert(distinct, v) end
    table.sort(distinct)
    say('')
    if #distinct == 0 then
        say('VERDICT: no boulders in the fort to measure.')
    elseif #distinct == 1 then
        say(string.format('VERDICT: getVolume is FLAT at %d across'
            .. ' %d material(s). Rank is the only axis coke has.',
            distinct[1], #order))
    else
        local s = {}
        for _, v in ipairs(distinct) do
            table.insert(s, tostring(v))
        end
        say(string.format('VERDICT: getVolume VARIES: %s. The coke'
            .. ' model has a second axis and the rank table can lean'
            .. ' on it.', table.concat(s, ', ')))
    end

    -- ---- QUESTION 2 AND 3: THE COALS THEMSELVES ----
    say('')
    say('---- THE COAL MATERIALS, LIVE FROM RAM ----')
    -- Kept so the yield section below can use the density the game
    -- is actually holding rather than a figure copied out of a raws
    -- file. Same rule as everywhere else here: RAM wins.
    local live = {}
    for _, want in ipairs(WANTED) do
        local hit = nil
        for _, tok in ipairs(order) do
            if tok == want then hit = seen[tok].sample end
        end
        if hit then
            local m = measure(hit)
            live[want] = m
            print_measure(want .. '  (in the fort)', m)
        elseif minting then
            local m = mint_and_measure(want)
            if m then
                live[want] = m
                print_measure(want .. '  (minted)', m)
            end
        else
            say(string.format('  %-34s none in the fort. Re-run with'
                .. ' `mint` to measure one.', want))
        end
    end

    -- ---- WHAT THE TUNING WOULD PAY ----
    -- Only printed when a volume was actually measured. The whole
    -- reason this file exists is to stop the yield table being quoted
    -- against a number nobody read.
    if tuning and tuning.yield and #distinct >= 1 then
        local V = distinct[1]
        say('')
        say(string.format('---- YIELD AT THE MEASURED VOLUME %d ----',
            V))
        local rows = {
            { 'lignite',    'COAL_LIGNITE',    1250,
              'INORGANIC:LIGNITE' },
            { 'bituminous', 'COAL_BITUMINOUS', 1346,
              'INORGANIC:COAL_BITUMINOUS' },
            { 'dried peat', 'PEAT',             850,
              'INORGANIC:MAKING_FUEL_PEAT_DRIED' },
            { 'raw peat',   'PEAT',             850,
              'INORGANIC:PEAT' },
        }
        for _, r in ipairs(rows) do
            -- ---- LIVE DENSITY, NOT THE RAWS FIGURE ----
            -- The fallback is only there so a material absent from
            -- the fort still prints something, and it says so.
            local m = live[r[4]]
            local dens = m and tonumber(m.density) or r[3]
            local from = m and 'live' or 'fallback'

            -- ---- THE BREAKDOWN, NOT JUST THE NUMBER ----
            -- yield_explained hands back every factor with the note
            -- it chose. A bare total cannot tell "the class is 1.300"
            -- from "the class is unknown so it defaulted to 1.0", and
            -- those two produce very different bars for the same
            -- printed reason.
            local v, parts = 0, {}
            pcall(function()
                v, parts = tuning.yield_explained(
                    V, r[2], dens, { mat_token = r[4] })
            end)
            say(string.format('  %-12s as %-16s density %d (%s)'
                .. '  ->  %6.2f', r[1], r[2], dens, from, v))
            for _, part in ipairs(parts or {}) do
                say(string.format('        %-10s x%-7.3f %s',
                    part.name, part.mult, tostring(part.note)))
            end
        end
    end
end

if dfhack_flags and dfhack_flags.module then return end
local args = {...}
if args[1] == nil or args[1] == 'mint' then
    run(args[1])
else
    print('usage: refinish-boulder-probe [mint]')
end
