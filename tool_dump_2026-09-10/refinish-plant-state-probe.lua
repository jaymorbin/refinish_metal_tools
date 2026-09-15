-- refinish-plant-state-probe.lua
-- =====================================================================
-- PLANT STATE PROBE
-- One report for two questions, read straight from the live world:
--
--   1. Does MAKING_FUEL_COAL_HOST exist in world.raws.plants right
--      now? If absent, the cinder token cannot resolve and the
--      warning flood at reactions build is explained: the plants
--      payload never made it into RAM this session.
--
--   2. Which plants carry BARK_DYE_MAT on their WOOD material right
--      now? This is the bark dye push's ground truth, independent of
--      whatever the gamelog said. PEACH should appear; SAND_PEAR
--      should not, because vanilla gives it no bark dye at all.
--
-- Run with the world loaded, after the module has booted.
-- =====================================================================

local CODE = 'BARK_DYE_MAT'

local function find_mat(plant, id)
    for _, mat in ipairs(plant.material) do
        if mat.id == id then return mat end
    end
    return nil
end

local function carries_code(mat)
    local rp = mat.reaction_product
    for i = 0, #rp.id - 1 do
        if rp.id[i].value == CODE then return true end
    end
    return false
end

-- ---- 1. the coal host ----
local host = nil
for _, plant in ipairs(df.global.world.raws.plants.all) do
    if plant.id == 'MAKING_FUEL_COAL_HOST' then host = plant break end
end
if host then
    local keys = {}
    for _, mat in ipairs(host.material) do table.insert(keys, mat.id) end
    print('COAL_HOST: PRESENT, materials: ' .. table.concat(keys, ', '))
else
    print('COAL_HOST: ABSENT. The plants payload is not in RAM this')
    print('session, which is the cinder warning flood. Check the boot')
    print('log for "no plants file" or "PLANT INJECTION", or grep the')
    print('installed engine for inject_plants.')
end
print('')

-- ---- 2. the bark dye push ----
local with_dye, with_code = 0, 0
local watch = { PEACH = true, SAND_PEAR = true }
for _, plant in ipairs(df.global.world.raws.plants.all) do
    local wood = find_mat(plant, 'WOOD')
    local dye  = find_mat(plant, 'BARK_DYE')
    if dye then with_dye = with_dye + 1 end
    local coded = wood and carries_code(wood) or false
    if coded then with_code = with_code + 1 end
    if watch[plant.id] then
        print(('%-10s bark dye material: %-5s  wood carries %s: %s')
              :format(plant.id, tostring(dye ~= nil), CODE, tostring(coded)))
    end
end
print('')
print(('plants defining BARK_DYE: %d, WOOD materials carrying %s: %d')
      :format(with_dye, CODE, with_code))
print('')
print('Healthy push: the two counts match and PEACH reads true/true.')
print('SAND_PEAR reading false/false is correct, not a failure: no')
print('vanilla bark dye exists for it, so its bark grinds nothing.')
print('Counts at zero with dye materials present means the push never')
print('ran or its material lookup failed; check the boot log for the')
print('"Bark Dye push" line and its count.')
