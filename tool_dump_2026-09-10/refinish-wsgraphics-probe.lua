-- refinish-wsgraphics-probe.lua  (replace prior version)
-- ==========================================
-- flags is a PACKED RECORD: color_index bits 0-7, subtype bits
-- 8-23, then is_furnace / is_tradedepot / planned_only /
-- second_frame. Each entry is one hardcoded workshop subtype's
-- art. subtype 23 = Custom would be the shared record for every
-- custom workshop.
--
-- Census bounds are probed, not assumed, and each cell read is
-- guarded individually so one bad index cannot blank an entry.
-- ==========================================

local icon_page = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'BUILDING_ICONS' then icon_page = p break end
end
if not icon_page then print("BUILDING_ICONS page not found.") return end

local icon_set = {}
for i = 0, #icon_page.texpos - 1 do
    local v = icon_page.texpos[i]
    if v and v ~= 0 then
        icon_set[v] = string.format("(%d,%d)", i % icon_page.page_dim_x,
            math.floor(i / icon_page.page_dim_x))
    end
end
local generic = icon_page.texpos[0]
print(string.format("generic custom icon texpos: %d", generic))

local vec = df.global.world.raws.buildings.workshop_graphics_info
print(string.format("---- %d entries ----", #vec))

for i = 0, #vec - 1 do
    local g = vec[i]

    local color, sub = -1, -1
    pcall(function() color = g.flags.color_index end)
    pcall(function() sub = g.flags.subtype end)
    local bools = {}
    for _, name in ipairs({ 'is_furnace', 'is_tradedepot', 'planned_only', 'second_frame' }) do
        pcall(function() if g.flags[name] then table.insert(bools, name) end end)
    end

    -- Probe real dimensions off the wrapper itself.
    local outer = 0
    pcall(function() outer = #g.texpos end)
    local inner = 0
    pcall(function() inner = #g.texpos[0] end)

    local nonzero, minv, maxv, hits = 0, nil, nil, {}
    for a = 0, outer - 1 do
        for b = 0, inner - 1 do
            local ok, v = pcall(function() return g.texpos[a][b] end)
            if ok and type(v) == 'number' and v ~= 0 then
                nonzero = nonzero + 1
                if not minv or v < minv then minv = v end
                if not maxv or v > maxv then maxv = v end
                if icon_set[v] then
                    table.insert(hits, string.format("[%d][%d]=%d %s%s",
                        a, b, v, icon_set[v], v == generic and " <-- GENERIC" or ""))
                end
            end
        end
    end

    print(string.format(
        "entry %2d  subtype=%-3d color=%-3d %s  grid=%dx%d nonzero=%d range=%s..%s",
        i, sub, color, table.concat(bools, ','),
        outer, inner, nonzero, tostring(minv), tostring(maxv)))
    for _, h in ipairs(hits) do print("      ICON HIT " .. h) end
end