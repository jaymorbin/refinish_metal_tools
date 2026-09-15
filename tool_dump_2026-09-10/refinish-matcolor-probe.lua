-- refinish-matcolor-probe.lua
-- ==========================================
-- WHAT COLOUR IS THIS MATERIAL, REALLY
-- ==========================================
-- Reads the colour fields on a material, names the descriptor behind
-- the index, and lets the index be set live so a change can be
-- watched on screen without a recycle.
--
-- WHY THIS EXISTS. resolve_color in refinish-module-inject.lua ends
-- with "return 7", light gray, when neither the named colour nor any
-- fallback matches a descriptor. It also returns i from an ipairs
-- walk of the descriptor vector, so if that walk is 1 based while
-- descriptor indices are 0 based, every colour in every module is
-- one off. Both produce a wrong colour with no error anywhere, and
-- both look identical from outside.
--
-- USAGE
--   refinish-matcolor-probe
--       read the cinder material and the char material beside it
--   refinish-matcolor-probe find BLACK
--       what index a descriptor name sits at
--   refinish-matcolor-probe set BLACK
--   refinish-matcolor-probe set 42
--       write state_color.Solid on the cinder material, live
--   refinish-matcolor-probe restore
--
-- Set is not persistent: a recycle rebuilds the material from the
-- JSON. Restore is there so a session can be put back without one.
-- ==========================================

local args   = {...}
local verb   = args[1] or 'read'
local arg2   = args[2]
local TARGET = 'PLANT_MAT:MAKING_FUEL_COAL_HOST:CINDER'
local COMPARE = 'INORGANIC:MAKING_FUEL_CHAR'

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

_G.refinish_matcolor_saved = _G.refinish_matcolor_saved or {}
local saved = _G.refinish_matcolor_saved

local function mat(token)
    local mi = nil
    pcall(function() mi = dfhack.matinfo.find(token) end)
    return mi
end

local colors = df.global.world.raws.descriptors.colors

-- ==========================================
-- DESCRIPTOR BY NAME
-- ==========================================
-- Walked by INDEX, 0 based, which is how DF numbers the vector.
-- resolve_color walks it with ipairs instead, and that difference is
-- the whole off by one question.
local function by_name(name)
    local up = string.upper(tostring(name))
    for i = 0, #colors - 1 do
        local id = nil
        pcall(function() id = tostring(colors[i].id) end)
        if id == up then return i end
    end
    return nil
end

local function name_at(i)
    if not i or i < 0 or i >= #colors then return '(out of range)' end
    local id = '?'
    pcall(function() id = tostring(colors[i].id) end)
    return id
end

-- What ipairs gives for the same name, so the two can be compared
-- directly rather than reasoned about.
local function ipairs_index(name)
    local up = string.upper(tostring(name))
    local found = nil
    pcall(function()
        for i, c in ipairs(colors) do
            if tostring(c.id) == up then found = i return end
        end
    end)
    return found
end

-- ==========================================
-- FIND
-- ==========================================
if verb == 'find' then
    hr('DESCRIPTOR: ' .. tostring(arg2))
    local i = by_name(arg2)
    p('  descriptors total   ' .. tostring(#colors))
    p('  index by 0 based    ' .. tostring(i)
      .. (i and ('   = ' .. name_at(i)) or '   NOT PRESENT'))
    p('  index by ipairs     ' .. tostring(ipairs_index(arg2)))
    if i then
        p('  neighbours          ' .. (i > 0 and name_at(i - 1) or '-')
          .. '  [' .. name_at(i) .. ']  ' .. name_at(i + 1))
    end
    p('')
    return
end

-- ==========================================
-- SET / RESTORE
-- ==========================================
if verb == 'set' or verb == 'restore' then
    local mi = mat(TARGET)
    if not mi or not mi.material then
        p('  ' .. TARGET .. ' does not resolve.')
        return
    end
    local m = mi.material

    if verb == 'restore' then
        hr('RESTORE')
        if saved.solid == nil then p('  nothing was set.') return end
        pcall(function() m.state_color.Solid = saved.solid end)
        p('  state_color.Solid   ' .. tostring(saved.solid)
          .. '   = ' .. name_at(saved.solid))
        saved.solid = nil
        p('')
        return
    end

    local idx = tonumber(arg2) or by_name(arg2)
    if not idx then
        p('  no descriptor named ' .. tostring(arg2)
          .. '. Try: refinish-matcolor-probe find ' .. tostring(arg2))
        return
    end
    if saved.solid == nil then
        pcall(function() saved.solid = m.state_color.Solid end)
    end
    pcall(function()
        m.state_color.Solid   = idx
        m.state_color.Powder  = idx
        m.state_color.Paste   = idx
        m.state_color.Pressed = idx
    end)
    hr('SET')
    p('  state_color.Solid   ' .. tostring(idx) .. '   = ' .. name_at(idx))
    p('')
    p('  Look at a cinder now. If it changed, the colour path works')
    p('  and resolve_color was handing over the wrong index. If it did')
    p('  not, bar_texpos art is not tinted and the sprite is the')
    p('  colour, full stop.')
    p('')
    return
end

-- ==========================================
-- READ
-- ==========================================
local function report(label, token)
    hr(label)
    local mi = mat(token)
    if not mi or not mi.material then p('  ' .. token .. ' does not resolve.') return end
    local m = mi.material
    p('  token               ' .. token)
    local s = nil
    pcall(function() s = m.state_color.Solid end)
    p('  state_color.Solid   ' .. tostring(s) .. '   = ' .. name_at(s))
    local bt, tf = nil, nil
    pcall(function() bt = m.bar_texpos end)
    pcall(function() tf = m.texflag end)
    p('  bar_texpos          ' .. tostring(bt)
      .. (bt and bt > 0 and '   (set, so the sprite is drawn as painted)'
          or '   (unset, so DF tints the generic bar)'))
    p('  texflag             ' .. tostring(tf))
    local tc = {}
    pcall(function()
        for i = 0, 2 do tc[#tc + 1] = tostring(m.tile_color[i]) end
    end)
    p('  tile_color          ' .. table.concat(tc, ', ')
      .. '   (ASCII only, no effect on a graphics tileset)')
end

report('THE CINDER', TARGET)
report('THE CHAR MATERIAL, FOR COMPARISON', COMPARE)

hr('THE COLOURS THE SCHEMA ASKS FOR')
for _, n in ipairs({ 'CHARCOAL', 'BLACK', 'DARK_GRAY', 'GRAY' }) do
    local i = by_name(n)
    p(string.format('  %-12s 0 based %-6s ipairs %-6s %s',
        n, tostring(i), tostring(ipairs_index(n)),
        i and name_at(i) or 'NOT A DESCRIPTOR'))
end
p('')
p('  A name reading NOT A DESCRIPTOR is one resolve_color cannot')
p('  match, and it falls through to its final "return 7", which is')
p('  light gray. Two different indices in the two columns is the off')
p('  by one, and it would affect every material in every module.')
p('')
p('  Next: refinish-matcolor-probe set BLACK')
p('')
