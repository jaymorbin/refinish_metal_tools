-- refinish-pixel-probe.lua
-- Three hand-packed 32x32 solid tiles via dfhack.textures.createTile,
-- grafted into the retort def's stage-3 overhang row (visible in the
-- empty space above every completed retort). Recycle heals all.
-- Tile A: opaque red, RGBA byte order.  Tile B: opaque red, RABG-ish
-- alternate order (doc's packing note is ambiguous).  Tile C: opaque
-- white.  Report per tile: SOLID BRIGHT / FADED / WRONG COLOR.

local vec = df.global.world.raws.buildings.workshop_graphics_info
local slots = 0
for i = 0, #vec - 1 do
    local g = vec[i]
    local w = 0
    pcall(function() w = g.flags.whole end)
    if math.floor(w / 2^24) % 2 == 1 and math.floor(w / 256) % 65536 == 10 then
        slots = slots + 1
    end
end
print('subtype-10 slots now present: ' .. slots)

local function solid(px)
    local t = {}
    for i = 1, 32 * 32 do t[i] = px end
    return t
end

-- order guess 1: 0xRRGGBBAA ; guess 2: 0xRRBBGGAA (doc says "RBGA")
local A = solid(0xFF0000FF)   -- red if RRGGBBAA
local B = solid(0xFF0000FF + 0)  -- placeholder, replaced below
B = solid(0xFF00FF00 // 0x100 * 0x100 + 0xFF) -- red if RRBBGGAA -> 0xFF00??; simpler: pure by-order test below
B = solid(0x00FF00FF)   -- green if RRGGBBAA, tells order by which color shows
local C = solid(0xFFFFFFFF)  -- white in any order

local hA = dfhack.textures.createTile(A, 32, 32, false)
local hB = dfhack.textures.createTile(B, 32, 32, false)
local hC = dfhack.textures.createTile(C, 32, 32, false)

local d
for _, x in ipairs(df.global.world.raws.buildings.all) do
    if x.code == 'MAKING_FUEL_RETORT' then d = x end
end
if not d then print('no retort def') return end

d.graphics_normal[3][0][0] = dfhack.textures.getTexposByHandle(hA)
d.graphics_normal[3][1][0] = dfhack.textures.getTexposByHandle(hB)
d.graphics_normal[3][2][0] = dfhack.textures.getTexposByHandle(hC)
print('three tiles written above the retort: report each as SOLID BRIGHT / FADED / and which colors you see')