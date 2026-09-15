-- refinish-wsgi-fill.lua  (replace prior version)
-- ==========================================
-- Custom-range is_furnace entries (subtype > 7, DF's synthetic
-- keys past furnace_type ceiling) come in TWINS = the two draw
-- passes. Fills one with MAIN art, the other with OVERLAY art
-- from the cached retort png. Default: first twin main, second
-- overlay. 'swap' tries the other assignment. 'revert' zeroes.
--   refinish-wsgi-fill [swap|revert]
-- ==========================================
local args = {...}
local mode = args[1]
_G.refinish_wsgi_undo2 = _G.refinish_wsgi_undo2 or {}

local vec = df.global.world.raws.buildings.workshop_graphics_info

if mode == 'revert' then
    local n = 0
    for _, u in ipairs(_G.refinish_wsgi_undo2) do
        pcall(function() u.node[u.idx] = u.old n = n + 1 end)
    end
    _G.refinish_wsgi_undo2 = {}
    print(string.format('reverted %d cell(s).', n))
    return
end

local path = nil
for k in pairs(_G.refinish_texture_cache or {}) do
    if k:find('retort%.png$') then path = k end
end
if not path then print('retort.png not in texture cache') return end
local entry = _G.refinish_texture_cache[path]

-- collect custom-range furnace twins, vector order
local twins = {}
for i = 0, #vec - 1 do
    local g = vec[i]
    local isf, sub = false, -1
    pcall(function() isf = g.flags.is_furnace end)
    pcall(function() sub = g.flags.subtype end)
    if isf and sub and sub > 7 then
        table.insert(twins, { i = i, g = g, sub = sub })
    end
end
if #twins == 0 then print('no custom-range furnace entries found') return end

local function fill(g, overlay)
    -- zero everything first, recording old values
    for s = 0, 3 do for x = 0, 30 do for y = 0, 31 do
        local ok, v = pcall(function() return g.texpos[s][x][y] end)
        if ok and v ~= 0 then
            table.insert(_G.refinish_wsgi_undo2, { node = g.texpos[s][x], idx = y, old = v })
            g.texpos[s][x][y] = 0
        end
    end end end
    -- write the pass
    local shift = overlay and 12 or 0
    local wrote = 0
    for s = 0, 3 do
        for x = 0, 2 do
            for y = 0, 3 do
                local c = (3 - s) * 3 + shift + x
                local h = entry.handles[y * 24 + c + 1]
                local v = h and dfhack.textures.getTexposByHandle(h)
                if v and v > 0 then
                    table.insert(_G.refinish_wsgi_undo2, { node = g.texpos[s][x], idx = y, old = 0 })
                    g.texpos[s][x][y] = v
                    wrote = wrote + 1
                end
            end
        end
    end
    return wrote
end

for n, t in ipairs(twins) do
    local overlay
    if mode == 'swap' then
        overlay = (n % 2 == 1)   -- first twin overlay, second main
    else
        overlay = (n % 2 == 0)   -- first twin main, second overlay
    end
    local wrote = fill(t.g, overlay)
    print(string.format('entry %d (subtype %d): %s, %d cells',
        t.i, t.sub, overlay and 'OVERLAY' or 'MAIN', wrote))
end
print('LOOK AT A COMPLETED RETORT. If base-only again or junk with no base: rerun with swap.')