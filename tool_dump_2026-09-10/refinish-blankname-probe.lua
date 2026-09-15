-- refinish-blankname-probe.lua
-- ==========================================
-- CAN A TOOL DROP ITS MATERIAL WORD
-- ==========================================
-- A tool renders as material then item name, so the module's cinder
-- reads "char cinder". The goal is "cinder".
--
-- The bar fix proved DF SKIPS an empty name component rather than
-- padding it: a material with a blank prefix reads "charcoal", not
-- " charcoal". If that holds for state_name on a tool, a material
-- with no name at all gives a bare "cinder" and the word is gone
-- without renaming anything else.
--
-- That is the one unknown. This measures it on a live item, in both
-- material modes, and restores everything.
--
-- WHAT IT DOES
--   1. Reads a cinder as it is now.
--   2. Blanks its material's Solid name and adjective, reads again.
--   3. Restores, reads again to prove the restore took.
--   4. Repeats 1 to 3 against a PLANT material on the coal host, so
--      the answer covers the mode the material would actually live
--      in.
--
-- Every write is undone in the same breath. The simulation is never
-- advanced between a write and its restore.
--
-- USAGE
--   refinish-blankname-probe
--   refinish-blankname-probe MAKING_FUEL_BARK      (any tool id)
-- ==========================================

local args = {...}
local want_tool = args[1] or 'MAKING_FUEL_CINDER'
local HOST      = 'PLANT_MAT:MAKING_FUEL_COAL_HOST:CHARCOAL'

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end
local function d(it)
    local s = '?'
    pcall(function() s = dfhack.items.getDescription(it, 0) end)
    return tostring(s)
end

-- ==========================================
-- FIND THE TOOL
-- ==========================================
-- By itemdef id rather than by subtype number: injected subtypes are
-- array positions and move whenever a tool key is added.
local function tool_subtype(id)
    for i, td in ipairs(df.global.world.raws.itemdefs.tools) do
        local ok, tid = pcall(function() return td.id end)
        if ok and tid == id then
            local ok2, sub = pcall(function() return td.subtype end)
            if ok2 and type(sub) == 'number' and sub >= 0 then return sub end
            return i
        end
    end
    return nil
end

local sub = tool_subtype(want_tool)
local item
if sub then
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.TOOL
               and it:getSubtype() == sub then
                item = it return
            end
        end
    end)
end

hr('SUBJECT')
if not item then
    p('  No ' .. want_tool .. ' in the fort. Make one and run again,')
    p('  or pass a different tool id as the argument.')
    return
end
p('  ' .. d(item))

-- ==========================================
-- THE TEST, ONCE PER MATERIAL
-- ==========================================
-- Blanks Solid name and adjective, reads, restores. Both fields,
-- because DF picks between them by context and a half blanked
-- material would answer neither question cleanly.
local function blank_test(label, mi)
    hr(label)
    if not mi or not mi.material then p('  material unavailable.') return end
    local m = mi.material
    p('  token               ' .. tostring(mi:getToken()))
    p('  state_name.Solid    ' .. tostring(m.state_name.Solid))
    p('  prefix              ' .. string.format('%q', tostring(m.prefix)))
    p('  before              ' .. d(item))

    local was_n, was_a = nil, nil
    pcall(function()
        was_n = tostring(m.state_name.Solid)
        was_a = tostring(m.state_adj.Solid)
        m.state_name.Solid = ""
        m.state_adj.Solid  = ""
    end)
    local blanked = d(item)
    p('  with a blank name   [' .. blanked .. ']')

    pcall(function()
        m.state_name.Solid = was_n
        m.state_adj.Solid  = was_a
    end)
    p('  restored            ' .. d(item))

    -- Brackets above are deliberate: a leading or doubled space is
    -- the failure mode, and it is invisible without them.
    local lead = blanked:match('^%s') ~= nil
    local dbl  = blanked:find('  ') ~= nil
    if lead or dbl then
        p('')
        p('  STRAY SPACE. DF padded the empty component instead of')
        p('  skipping it, so a nameless material is not the answer.')
    else
        p('')
        p('  CLEAN. DF skipped the empty component, exactly as it does')
        p('  for a blank prefix on a bar.')
    end
end

-- 1. The material the cinder has now.
local mi_now = nil
pcall(function() mi_now = dfhack.matinfo.decode(item) end)
blank_test('1. AS IT IS NOW', mi_now)

-- 2. The same item worn as a PLANT material on the coal host, which
-- is the mode a new cinder material would live in.
local mi_plant = nil
pcall(function() mi_plant = dfhack.matinfo.find(HOST) end)
if not mi_plant then
    hr('2. AS A PLANT MATERIAL')
    p('  ' .. HOST .. ' does not resolve, skipping.')
else
    local t, i = item.mat_type, item.mat_index
    pcall(function()
        item.mat_type  = mi_plant.type
        item.mat_index = mi_plant.index
    end)
    blank_test('2. AS A PLANT MATERIAL', mi_plant)
    pcall(function()
        item.mat_type  = t
        item.mat_index = i
    end)
    p('  item restored       ' .. d(item))
end

hr('WHAT THIS DECIDES')
p('  CLEAN in section 2: the cinder gets its own nameless material')
p('  on the coal host, black, carrying the same fuel classes, and it')
p('  reads "cinder".')
p('')
p('  STRAY SPACE: a nameless material is out, and the word in front')
p('  of "cinder" has to be a real one. "charred" and "spent" both')
p('  read better than "char" does.')
p('')
