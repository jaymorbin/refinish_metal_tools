-- refinish-bars-probe.lua
-- ==========================================
-- THE "BARS" SUFFIX: WHERE DOES THE WORD LIVE
-- ==========================================
-- One question, asked four ways: is the word "bars" a string in
-- reachable game DATA, which could be blanked, or is it in the
-- executable, which cannot be reached from Lua at all.
--
-- Nothing is written and nothing is changed. Every mutation below is
-- undone in the same breath, with the simulation never advancing a
-- frame between the two, exactly as the B1 to B4 name probes worked.
--
-- USAGE
--   refinish-bars-probe
--
-- Wants a module coal bar, or any inorganic bar, lying in the fort.
-- It finds one itself.
-- ==========================================

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

local function describe(it)
    local d = '?'
    pcall(function() d = dfhack.items.getDescription(it, 0) end)
    return tostring(d)
end

-- ==========================================
-- FIND A BAR
-- ==========================================
-- An INORGANIC bar specifically: that is the branch that appends the
-- word, per B2. A builtin coal bar names itself inside a different
-- branch and would answer a question nobody asked.
-- ==========================================
local bar, bar_mi
pcall(function()
    for _, it in ipairs(df.global.world.items.all) do
        if it:getType() == df.item_type.BAR then
            local mi = dfhack.matinfo.decode(it)
            if mi and tostring(mi.mode) == 'inorganic' then
                bar, bar_mi = it, mi
                return
            end
        end
    end
end)

hr('SUBJECT')
if not bar then
    p('  No inorganic bar found in the fort. Forge one iron bar, or')
    p('  drop a module coal bar on the floor, and run this again.')
    return
end
p('  ' .. describe(bar) .. '   [' .. tostring(bar_mi:getToken()) .. ']')

-- ==========================================
-- 1. THE ENUM ATTRIBUTE TABLE
-- ==========================================
-- DFHack exposes type.attrs for enums that carry them. If item_type
-- has one, and it holds a caption, that is a table in memory and a
-- writable candidate. Printed rather than assumed either way.
-- ==========================================
hr('1. df.item_type.attrs')
local attrs = nil
pcall(function() attrs = df.item_type.attrs end)
if not attrs then
    p('  item_type carries no attrs table. The word is not here.')
else
    local a = nil
    pcall(function() a = attrs[df.item_type.BAR] end)
    if not a then
        p('  attrs exists but has no BAR entry.')
    else
        local found = false
        pcall(function()
            for k, v in pairs(a) do
                p(string.format('  %-24s %s', tostring(k), tostring(v)))
                found = true
            end
        end)
        if not found then p('  BAR entry is empty.') end
    end
end

-- ==========================================
-- 2. THE WAFERS LEVER, CONFIRMED LIVE
-- ==========================================
-- B1 found WAFERS swaps the word. Re-run here for one reason: if the
-- word is DATA, WAFERS is selecting between two strings that must
-- also be data, and the next section can go looking for them. If the
-- swap works and no string is findable, both words are in the
-- binary and this line is the proof of that rather than a repeat.
-- ==========================================
hr('2. the WAFERS lever')
local inorg = nil
pcall(function()
    inorg = df.global.world.raws.inorganics[bar_mi.index]
end)
if not inorg then
    p('  material is not an inorganic entry, skipping.')
else
    local before = describe(bar)
    local was = nil
    pcall(function() was = inorg.flags.WAFERS end)
    pcall(function() inorg.flags.WAFERS = true end)
    local during = describe(bar)
    pcall(function() inorg.flags.WAFERS = was end)
    local after = describe(bar)
    p('  before  ' .. before)
    p('  WAFERS  ' .. during)
    p('  after   ' .. after)
    if before ~= during then
        p('  The lever works, so two words exist and DF picks between')
        p('  them. Section 3 decides whether either is reachable.')
    else
        p('  No change. Either this material ignores it or the probe')
        p('  is reading a stale description.')
    end
end

-- ==========================================
-- 3. IS EITHER WORD A REACHABLE STRING
-- ==========================================
-- Every string-shaped field on the material and the inorganic entry,
-- printed. If "bar", "bars" or "wafers" appears in any of them, it
-- is data and it is writable. If none does, the words are minted in
-- the item description code from constants in the executable, and no
-- amount of Lua reaches them.
--
-- state_name is the interesting one: it is the field the display
-- composes WITH, and the doc's model is prefix plus state_name. The
-- suffix would have to come from somewhere else entirely.
-- ==========================================
hr('3. every string on the material')
local m = bar_mi.material
local function show(label, v)
    local s = nil
    pcall(function() s = tostring(v) end)
    if s and s ~= '' and s ~= 'nil' then
        local hit = ''
        local low = s:lower()
        if low:find('bar', 1, true) or low:find('wafer', 1, true) then
            hit = '   <-- CONTAINS THE WORD'
        end
        p(string.format('  %-34s %s%s', label, s, hit))
    end
end
pcall(function() show('material.prefix', m.prefix) end)
pcall(function() show('material.id', m.id) end)
for _, st in ipairs({ 'Solid', 'Liquid', 'Gas', 'Powder', 'Paste',
                      'Pressed' }) do
    pcall(function() show('state_name.' .. st, m.state_name[st]) end)
    pcall(function() show('state_adj.' .. st, m.state_adj[st]) end)
end
if inorg then
    pcall(function() show('inorganic.id', inorg.id) end)
end

-- ==========================================
-- 4. WHAT THE OTHER MODES DO
-- ==========================================
-- The comparison that decides the whole question. Same item, same
-- bar, four material identities. If plant and creature mode come
-- back bare while inorganic does not, the suffix is a property of
-- the INORGANIC BRANCH of the description code, not of any string,
-- and the road is the one the naming doc already found: mint the
-- coals as plant materials with a blank prefix.
-- ==========================================
hr('4. the same bar in every material mode')
local saved_t, saved_i = bar.mat_type, bar.mat_index
local function as(label, token)
    local mi = nil
    pcall(function() mi = dfhack.matinfo.find(token) end)
    if not mi then p(string.format('  %-28s (not in this world)', label)) return end
    pcall(function()
        bar.mat_type  = mi.type
        bar.mat_index = mi.index
    end)
    p(string.format('  %-28s %s', label, describe(bar)))
end
as('builtin COAL:CHARCOAL', 'COAL:CHARCOAL')
as('INORGANIC:IRON', 'INORGANIC:IRON')
as('PLANT_MAT:WILLOW:WOOD', 'PLANT_MAT:WILLOW:WOOD')
as('PLANT_MAT:WILLOW:STRUCTURAL', 'PLANT_MAT:WILLOW:STRUCTURAL')
pcall(function()
    bar.mat_type  = saved_t
    bar.mat_index = saved_i
end)
p('')
p('  restored to ' .. describe(bar))

hr('READING THIS')
p('  A caption in section 1, or a hit in section 3, means the word')
p('  is data: blank it and the suffix goes, for every bar of that')
p('  material only if the field is per material, for every bar in')
p('  the game if it is not. Section 1 being empty and section 3')
p('  clean means the word is in the executable and unreachable.')
p('')
p('  Section 4 is the fallback either way. A bare plant mode name')
p('  is the same bar, same item type, same fuel behaviour, with no')
p('  suffix, which is what making_fuel_bar_naming.md measured.')
p('')
