-- refinish-furnace-entry-probe.lua
-- ==========================================
-- Creates a workshop_graphics_info entry for CUSTOM furnaces,
-- cloned from the wood furnace entry's flag shape, grid filled
-- from the cached retort png, stage-major, main art only.
-- Renderer reads per frame: if keying works, the already-built
-- bare retort gains art THE MOMENT this runs. No rebuild needed.
--   refinish-furnace-entry-probe <subtype_value>
-- Run once with 7 (furnace_type.Custom). If bare, retry with the
-- retort's def id (2) — the subtype=10 mystery pairs suggest the
-- field may hold ids, not furnace_type, for customs.
-- ==========================================
local args = {...}
local KEY = tonumber(args[1]) or 7

local path = nil
for k in pairs(_G.refinish_texture_cache or {}) do
    if k:find('retort%.png$') then path = k end
end
if not path then print('retort.png not in texture cache; recycle first') return end
local entry = _G.refinish_texture_cache[path]

local vec = df.global.world.raws.buildings.workshop_graphics_info
local template = nil
for i = 0, #vec - 1 do
    local g = vec[i]
    local isf = false
    pcall(function() isf = g.flags.is_furnace end)
    local sub = -1
    pcall(function() sub = g.flags.subtype end)
    if isf and sub == 0 then template = g break end   -- wood furnace
end
if not template then print('wood furnace template entry not found') return end

local g = df.workshop_graphics_infost:new()
local ok_w = pcall(function()
    g.flags.whole = template.flags.whole
end)
if not ok_w then
    pcall(function() g.flags.is_furnace = true end)
end
-- rekey subtype bits via named field; falls back to reporting
local ok_s = pcall(function() g.flags.subtype = KEY end)
print(string.format('flags copied=%s subtype_set=%s key=%d',
    tostring(ok_w), tostring(ok_s), KEY))

-- fill: stage-major, main art only (sheet cols (3-s)*3 .. +2)
local written = 0
for s = 0, 3 do
    for x = 0, 2 do
        for y = 0, 3 do
            local c = (3 - s) * 3 + x
            local h = entry.handles[y * 24 + c + 1]
            local v = h and dfhack.textures.getTexposByHandle(h)
            if v and v > 0 then
                g.texpos[s][x][y] = v
                written = written + 1
            end
        end
    end
end
vec:insert('#', g)
print(string.format('entry inserted at %d, %d cells. LOOK AT THE BUILT RETORT NOW.',
    #vec - 1, written))