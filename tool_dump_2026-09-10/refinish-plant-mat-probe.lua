-- refinish-plant-mat-probe.lua
-- ==========================================
-- PLANT MATERIAL INJECTION: THE LOAD BEARING FACTS
-- ==========================================
-- Round 2 was written against comments in the injector and claims in
-- making_fuel_bar_naming.md. Four of the things it does rest on
-- assumptions nobody has measured. This measures them.
--
--   1. Does assign SHARE the donor's materials, or copy them.
--      Round 2 drops the clone's material entries on the belief that
--      they are the donor's own objects. If that is wrong, it is
--      dropping objects the clone owns and leaking them.
--
--   2. Does emptying the material vector actually CTD, as the
--      injector's own note warns. Round 2 empties and refills, which
--      overrides that warning on reasoning alone.
--
--   3. Do material flags iterate by index the way PLANT flags do.
--      Round 2 wipes them with the plant idiom on a different
--      bitfield.
--
--   4. Does createItem mint a BAR of a plant material at all, with a
--      working stack and dimension, and does it display bare.
--
-- Nothing is inserted into the raws. The test clone is deliberately
-- NOT deleted: if its material vector does hold the donor's pointers,
-- deleting it could free materials a real plant is using. A leaked
-- plant_raw costs a few kilobytes until the next world load.
--
-- USAGE
--   refinish-plant-mat-probe
--   refinish-plant-mat-probe WILLOW
-- ==========================================

local args = {...}
local want = args[1]

local function p(s) print(s) end
local function hr(t) p('') p(string.rep('=', 66)) if t then p(t) end p(string.rep('=', 66)) end
local function addr(o)
    local s = tostring(o)
    return s:match('0x%x+') or s
end

-- ==========================================
-- A DONOR
-- ==========================================
local donor, d_index
pcall(function()
    for i, pl in ipairs(df.global.world.raws.plants.all) do
        if (not want and #pl.material > 0)
           or (want and tostring(pl.id) == want) then
            donor, d_index = pl, i
            return
        end
    end
end)

hr('DONOR')
if not donor then p('  no plant found.') return end
p('  id            ' .. tostring(donor.id))
p('  index         ' .. tostring(d_index))
p('  materials     ' .. tostring(#donor.material))
for i = 0, math.min(#donor.material, 6) - 1 do
    local m = donor.material[i]
    p(string.format('    [%d] %-14s prefix=%q  solid=%q  %s',
        i, tostring(m.id), tostring(m.prefix),
        tostring(m.state_name.Solid), addr(m)))
end

-- ==========================================
-- 1. SHARED OR COPIED
-- ==========================================
hr('1. does assign share the material objects')
local clone = df.plant_raw:new()
clone:assign(donor)
p('  donor material[0]   ' .. addr(donor.material[0]))
p('  clone material[0]   ' .. addr(clone.material[0]))
if addr(clone.material[0]) == addr(donor.material[0]) then
    p('  SHARED. Round 2 is right to drop rather than delete, and')
    p('  writing through a clone material would rename the donor.')
else
    p('  COPIED. Round 2 is WRONG: those entries belong to the clone,')
    p('  and dropping them without deleting leaks one material each.')
end
p('')
p('  (the clone is left alive on purpose, see the header)')

-- ==========================================
-- 2. THE EMPTY VECTOR WARNING
-- ==========================================
-- Emptied and refilled on the CLONE ONLY, which is not in the raws
-- and is not rendered, so nothing can crash from it. This says
-- whether the operations succeed, not whether a rendered plant
-- survives it: only a real injection answers that.
hr('2. emptying and refilling on the clone')
local before_n = #clone.material
local template = clone.material[0]
local ok_empty = pcall(function()
    while #clone.material > 0 do
        clone.material:erase(#clone.material - 1)
    end
end)
p('  erase to empty      ' .. tostring(ok_empty)
  .. '   (' .. before_n .. ' -> ' .. tostring(#clone.material) .. ')')

local fresh, ok_new = nil, false
ok_new = pcall(function()
    fresh = df.material:new()
    fresh:assign(template)
end)
p('  new + assign        ' .. tostring(ok_new) .. '   ' .. addr(fresh))
if fresh then
    p('  fresh is a copy     '
      .. tostring(addr(fresh) ~= addr(template)))
    local ok_ins = pcall(function() clone.material:insert('#', fresh) end)
    p('  insert              ' .. tostring(ok_ins)
      .. '   (' .. tostring(#clone.material) .. ' entries)')
end

-- ==========================================
-- 3. MATERIAL FLAGS BY INDEX
-- ==========================================
hr('3. do material flags iterate like plant flags')
local m0 = donor.material[0]
local n_flags, read_ok, first = nil, false, nil
pcall(function() n_flags = #m0.flags end)
pcall(function() first = m0.flags[0] read_ok = true end)
p('  #material.flags     ' .. tostring(n_flags))
p('  flags[0] readable   ' .. tostring(read_ok) .. '   value ' .. tostring(first))
if not n_flags then
    p('  NO LENGTH. Round 2 wipes flags with a loop over #m.flags,')
    p('  which does nothing here. Named flags would be needed instead.')
end
-- Round trip one bit on the CLONE's fresh material, never the donor's.
if fresh then
    local was = nil
    pcall(function() was = fresh.flags[0] end)
    local ok_w = pcall(function() fresh.flags[0] = not was end)
    local now = nil
    pcall(function() now = fresh.flags[0] end)
    pcall(function() fresh.flags[0] = was end)
    p('  write by index      ' .. tostring(ok_w)
      .. '   changed=' .. tostring(now ~= was))
end

-- ==========================================
-- 4. A BAR OF A PLANT MATERIAL
-- ==========================================
-- The assumption the whole naming fix stands on. Minted, read,
-- removed.
hr('4. createItem with a plant material')
local token = 'PLANT_MAT:' .. tostring(donor.id) .. ':'
              .. tostring(donor.material[0].id)
local mi = nil
pcall(function() mi = dfhack.matinfo.find(token) end)
p('  token               ' .. token)
p('  resolves            ' .. tostring(mi ~= nil))
if mi then
    p('  mat_type/index      ' .. tostring(mi.type) .. ' / ' .. tostring(mi.index))
    local u = nil
    pcall(function()
        for _, unit in ipairs(df.global.world.units.active) do
            if dfhack.units.isCitizen(unit) and dfhack.units.isAlive(unit) then
                u = unit return
            end
        end
    end)
    if not u then
        p('  no citizen to mint against, skipping the mint.')
    else
        local made = nil
        local ok_mint = pcall(function()
            made = dfhack.items.createItem(u, df.item_type.BAR, -1,
                                           mi.type, mi.index)
        end)
        local it = made and made[1]
        p('  createItem          ' .. tostring(ok_mint)
          .. '   ' .. tostring(it and 'minted' or 'nothing'))
        if it then
            local d, stack, dim = '?', nil, nil
            pcall(function() d = dfhack.items.getDescription(it, 0) end)
            pcall(function() stack = it.stack_size end)
            pcall(function() dim = it.dimension end)
            p('  displays as         ' .. tostring(d)
              .. (tostring(d):lower():find('bar') and '' or '   <-- BARE'))
            p('  stack_size          ' .. tostring(stack))
            p('  dimension           ' .. tostring(dim))
            pcall(function() dfhack.items.remove(it) end)
            p('  removed again       yes')
        end
    end
end

hr('WHAT THIS DECIDES')
p('  1 SHARED and 3 with a length: Round 2 stands as written.')
p('  1 COPIED: the drop loop must delete, not erase.')
p('  3 without a length: the flag wipe is a no-op and needs')
p('    replacing before any food crop donor is used.')
p('  4 not bare, or no mint: the plant road does not work and the')
p('    suffix stays. Everything else is moot.')
p('')
