-- refinish-furnace-probe.lua  (replace prior version)
-- ==========================================
-- ADAPTIVE FURNACE GRAPHICS CENSUS
-- ==========================================
-- Prior censuses trusted declared or #-reported bounds and were
-- blind twice. This one descends g.texpos ADAPTIVELY: at each
-- level, if elements are arrays, recurse; if numbers, census.
-- Reports the discovered shape, counts nonzero, and flags values
-- matching the KNOWN vanilla furnace art set (WORKSHOPS page rows
-- 72-79, per graphics_workshops.txt FURNACE_WOOD block).
--
--   refinish-furnace-probe            census
--   refinish-furnace-probe mark       overwrite first cells w/ donor
--   refinish-furnace-probe revert     undo marks
-- ==========================================

local args = {...}
local mode = args[1] or 'census'
_G.refinish_furnace_probe_undo = _G.refinish_furnace_probe_undo or {}

-- ---- target set: WORKSHOPS rows 72-79, all columns ----
local ws = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'WORKSHOPS' then ws = p break end
end
if not ws then print('WORKSHOPS page missing') return end

local furnace_art = {}
for r = 72, 79 do
    for c = 0, ws.page_dim_x - 1 do
        local v = ws.texpos[r * ws.page_dim_x + c]
        if v and v ~= 0 then
            furnace_art[v] = string.format('(%d,%d)', c, r)
        end
    end
end
local donor = ws.texpos[62 * ws.page_dim_x + 1]  -- soap maker center
print('donor:', donor)

-- ---- adaptive walker ----
local function census(node, path, out, depth)
    if depth > 5 then return end
    local n = 0
    pcall(function() n = #node end)
    if not n or n == 0 then return end
    -- classify first element
    local first = nil
    pcall(function() first = node[0] end)
    if type(first) == 'number' then
        for i = 0, n - 1 do
            local ok, v = pcall(function() return node[i] end)
            if ok and type(v) == 'number' and v ~= 0 then
                table.insert(out, {
                    path = string.format('%s[%d]', path, i),
                    node = node, idx = i, v = v,
                })
            end
        end
    else
        for i = 0, n - 1 do
            local ok, child = pcall(function() return node[i] end)
            if ok and child ~= nil then
                census(child, string.format('%s[%d]', path, i), out, depth + 1)
            end
        end
    end
end

-- ---- survey every entry, not only is_furnace ----
local vec = df.global.world.raws.buildings.workshop_graphics_info
for i = 0, #vec - 1 do
    local g = vec[i]
    local isf, sub = false, -1
    pcall(function() isf = g.flags.is_furnace end)
    pcall(function() sub = g.flags.subtype end)

    -- discovered shape: lengths down the first spine
    local shape, node = {}, g.texpos
    for _ = 1, 4 do
        local n = 0
        pcall(function() n = #node end)
        if not n or n == 0 then break end
        table.insert(shape, n)
        local nxt = nil
        pcall(function() nxt = node[0] end)
        if type(nxt) ~= 'userdata' and type(nxt) ~= 'table' then break end
        node = nxt
    end

    local cells = {}
    census(g.texpos, 'texpos', cells, 1)

    local matches = 0
    for _, c in ipairs(cells) do
        if furnace_art[c.v] then matches = matches + 1 end
    end

    print(string.format(
        'entry %2d  is_furnace=%s subtype=%-3d shape=[%s] nonzero=%d furnace_art_matches=%d',
        i, tostring(isf), sub, table.concat(shape, ']['), #cells, matches))
    for n = 1, math.min(#cells, 6) do
        local c = cells[n]
        print(string.format('    %s = %d %s', c.path, c.v,
            furnace_art[c.v] and ('MATCH ' .. furnace_art[c.v]) or ''))
    end

    if mode == 'mark' and isf then
        for n = 1, math.min(#cells, 6) do
            local c = cells[n]
            table.insert(_G.refinish_furnace_probe_undo,
                { node = c.node, idx = c.idx, old = c.v })
            c.node[c.idx] = donor
        end
        if #cells > 0 then print('    MARKED first cells with donor') end
    end
end

if mode == 'revert' then
    local n = 0
    for _, u in ipairs(_G.refinish_furnace_probe_undo) do
        pcall(function() u.node[u.idx] = u.old n = n + 1 end)
    end
    _G.refinish_furnace_probe_undo = {}
    print(string.format('reverted %d cell(s).', n))
elseif mode == 'mark' then
    print('LOOK AT BUILT WOOD FURNACE / KILN. Then: refinish-furnace-probe revert')
end