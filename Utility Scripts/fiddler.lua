-- fiddle.lua
local target_material = 'INORGANIC:REFINISHED_STEEL_RED'
local matinfo = dfhack.matinfo.find(target_material)

if not matinfo then
    print("Could not find material: " .. target_material)
    return
end

local m = matinfo.material

-- 4 is Red. We are forcing everything to be undeniably, aggressively Red.

-- 1. The ASCII structural color
m.build_color[0] = 4; m.build_color[1] = 4; m.build_color[2] = 4

-- 2. The ASCII item color
m.basic_color[0] = 4; m.basic_color[1] = 4

-- 3. The Graphics Engine Tile Color (Your rock wall fix)
m.tile_color[0] = 4; m.tile_color[1] = 4; m.tile_color[2] = 4

-- 4. The Graphics Engine Palette Color (0 is Solid state)
-- This is highly likely to be the culprit for pixel art.
m.state_color[0] = 87

print("Aggressively painted " .. target_material .. " RED.")