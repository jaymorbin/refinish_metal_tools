-- refinish-template-fill.lua
local vec = df.global.world.raws.buildings.workshop_graphics_info
local path for k in pairs(_G.refinish_texture_cache or {}) do if k:find('retort%.png$') then path = k end end
if not path then print('recycle first; retort.png not cached') return end
local tex = _G.refinish_texture_cache[path]
local t for i = 0, #vec - 1 do local g = vec[i]
    local w = 0 pcall(function() w = g.flags.whole end)
    if math.floor(w / 2^24) % 2 == 1 and math.floor(w / 256) % 65536 == 10 and w % 256 == 116 then t = g end
end
if not t then
    t = df.workshop_graphics_infost:new()
    t.flags.whole = 0x01000a74
    vec:insert('#', t)
    print('created 116 template for subtype 10')
end
local n = 0
for s = 0, 3 do for x = 0, 2 do for y = 0, 3 do
    local h = tex.handles[y * 24 + (3 - s) * 3 + x + 1]
    local v = h and dfhack.textures.getTexposByHandle(h)
    if v and v > 0 then t.texpos[s][x][y] = v n = n + 1 end
end end end
print('template filled: ' .. n .. ' cells. Deconstruct and rebuild ONE retort.')