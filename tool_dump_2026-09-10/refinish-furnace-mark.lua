-- refinish-furnace-mark.lua
-- Marks ALL nonzero cells (every stage) of is_furnace entries in
-- workshop_graphics_info with the donor tile, so any read of this
-- vector by any furnace render state becomes visible.
--   refinish-furnace-mark          mark
--   refinish-furnace-mark revert   restore
local args = {...}
_G.refinish_fmark_undo = _G.refinish_fmark_undo or {}

if args[1] == 'revert' then
    local n = 0
    for _, u in ipairs(_G.refinish_fmark_undo) do
        pcall(function() u.node[u.idx] = u.old n = n + 1 end)
    end
    _G.refinish_fmark_undo = {}
    print(string.format('reverted %d cell(s).', n))
    return
end

local ws = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'WORKSHOPS' then ws = p break end
end
local donor = ws.texpos[62 * ws.page_dim_x + 1]

local marked = 0
for i = 0, #df.global.world.raws.buildings.workshop_graphics_info - 1 do
    local g = df.global.world.raws.buildings.workshop_graphics_info[i]
    local isf = false
    pcall(function() isf = g.flags.is_furnace end)
    if isf then
        for s = 0, 3 do
            for x = 0, 30 do
                for y = 0, 31 do
                    local ok, v = pcall(function() return g.texpos[s][x][y] end)
                    if ok and type(v) == 'number' and v ~= 0 then
                        table.insert(_G.refinish_fmark_undo,
                            { node = g.texpos[s][x], idx = y, old = v })
                        g.texpos[s][x][y] = donor
                        marked = marked + 1
                    end
                end
            end
        end
    end
end
print(string.format('marked %d cell(s). LOOK: built wood furnace, built kiln.', marked))
print('then: refinish-furnace-mark revert')