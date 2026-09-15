-- refinish-floor-probe.lua
-- ==========================================
-- WHERE DOES A FLOOR TILE GET ITS ART
-- ==========================================
-- Peat draws as stone floor because IS_STONE puts its tiles in the
-- stone family. Changing the tiletype would fix the picture and
-- break the yield, so the tiletype is not the lever. The question is
-- whether the ART is reachable some other way.
--
-- Three places it could live, and this looks in all three:
--
--   1. ON THE MATERIAL. The material struct carries texpos fields
--      for bars, boulders, wood and rough. If a soil material has
--      something set that a stone does not, terrain art hangs off
--      the material and is writable per material, the way the bar
--      slot was.
--
--   2. IN A GLOBAL TABLE keyed by tiletype. Then the art is shared
--      by every material of that tiletype, and changing it for peat
--      would change it for all stone floors. Reachable but useless.
--
--   3. NOWHERE REACHABLE, composited at graphics load like the
--      boulder sprites were. Then peat's floor is fixed and the
--      answer is no.
--
-- Nothing is written. Reads only.
--
-- USAGE
--   refinish-floor-probe
--   refinish-floor-probe GRANITE SILTY_CLAY
-- ==========================================

local args = {...}
local STONE = args[1] or 'GRANITE'
local SOIL  = args[2] or 'SILTY_CLAY'

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end

local FIELDS = {
    'wood_texpos', 'boulder_texpos1', 'boulder_texpos2',
    'rough_texpos1', 'rough_texpos2', 'bar_texpos',
    'cheese_texpos1', 'cheese_texpos2', 'texflag', 'tile',
}

-- ==========================================
-- 1. THE MATERIALS, SIDE BY SIDE
-- ==========================================
-- A field that is set on the soil and zero on the stone is the
-- candidate. A field that is zero on both is not where floors live.
hr('1. MATERIAL TEXPOS FIELDS')
local subjects = {
    { 'PEAT (stone, wrong art)', 'INORGANIC:PEAT' },
    { STONE .. ' (stone)',       'INORGANIC:' .. STONE },
    { SOIL  .. ' (soil)',        'INORGANIC:' .. SOIL },
}
p(string.format('  %-28s %s', 'field', 'peat / stone / soil'))
p('  ' .. string.rep('-', 62))
local mats = {}
for i, s in ipairs(subjects) do
    local mi = nil
    pcall(function() mi = dfhack.matinfo.find(s[2]) end)
    mats[i] = mi and mi.material or nil
    if not mats[i] then p('  ' .. s[2] .. ' does not resolve') end
end
for _, f in ipairs(FIELDS) do
    local vals = {}
    for i = 1, 3 do
        local v = 'n/a'
        if mats[i] then pcall(function() v = tostring(mats[i][f]) end) end
        vals[#vals + 1] = v
    end
    local differs = (vals[1] ~= vals[3]) and '   <-- differs from soil' or ''
    p(string.format('  %-28s %s / %s / %s%s',
        f, vals[1], vals[2], vals[3], differs))
end

-- ==========================================
-- 2. THE GLOBAL TEXTURE STRUCT
-- ==========================================
-- Top level only. Anything shaped like a per tiletype vector is the
-- second candidate, and its LENGTH says what it is keyed by: a
-- vector as long as df.tiletype is keyed by tiletype.
hr('2. df.global.texture, top level')
local n_tiletype = 0
pcall(function()
    for _ in ipairs(df.tiletype) do n_tiletype = n_tiletype + 1 end
end)
p('  df.tiletype has ' .. tostring(n_tiletype) .. ' entries')
p('')
local ok = pcall(function()
    for k, v in pairs(df.global.texture) do
        local desc = tostring(v)
        local len = nil
        pcall(function() len = #v end)
        p(string.format('  %-24s %s%s', tostring(k), desc:sub(1, 30),
            len and ('   [' .. len .. ' entries]'
                     .. (len == n_tiletype and '  <-- KEYED BY TILETYPE' or ''))
                or ''))
    end
end)
if not ok then p('  could not enumerate df.global.texture') end

-- ==========================================
-- 3. WHAT A PEAT TILE ACTUALLY IS
-- ==========================================
-- Stand on or beside peat and run this: it reads the tile under the
-- cursor, so the tiletype and its material family are named rather
-- than assumed.
hr('3. THE TILE UNDER THE CURSOR')
-- getMousePos, not df.global.cursor: the old global is not the
-- cursor in DF 50 and reads as nothing. Hover the mouse over a peat
-- tile and run this.
local pos = nil
pcall(function() pos = dfhack.gui.getMousePos() end)
if not pos then
    p('  No cursor. Put the cursor on a peat tile with k or by')
    p('  designating, and run this again to see its tiletype.')
else
    local tt = nil
    pcall(function() tt = dfhack.maps.getTileType(pos) end)
    p('  position            ' .. pos.x .. ',' .. pos.y .. ',' .. pos.z)
    p('  tiletype            ' .. tostring(tt) .. '  '
      .. tostring(tt and df.tiletype[tt] or '?'))
    pcall(function()
        local a = df.tiletype.attrs[tt]
        p('  shape               ' .. tostring(df.tiletype_shape[a.shape]))
        p('  material            ' .. tostring(df.tiletype_material[a.material]))
        p('  variant             ' .. tostring(a.variant))
    end)
end

hr('READING THIS')
p('  A field in 1 that is set on soil and zero on peat is the lever:')
p('  write it on peat and the floor changes, per material, the way')
p('  the bar slot did.')
p('')
p('  Nothing in 1, but a tiletype keyed vector in 2, means the art is')
p('  shared by every material of that tiletype. Changing it moves')
p('  every stone floor in the game, which is not what you asked for.')
p('')
p('  Neither means the floor is composited at load like the boulder')
p('  sprites, and peat keeps the stone floor.')
p('')
