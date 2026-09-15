-- refinish-icon-hunt.lua
-- ==========================================
-- VALUE HUNT: generic custom workshop icon
-- ==========================================
-- The generic menu icon is BUILDING_ICONS cell (0,0), texpos
-- 125105 in this world. Anything STORING a reference to it must
-- hold that integer. This walks the plausible UI and raws roots
-- and prints the full path of every field equal to it.
--
--   refinish-icon-hunt [depth]     default 7
--
-- The texture registry itself is excluded (the page trivially
-- contains its own value), as are the giant world vectors that
-- cannot hold UI state.
-- ==========================================

local args = {...}
local MAX_DEPTH  = tonumber(args[1]) or 7
local MAX_VISITS = 400000
local MAX_HITS   = 40

-- ---- resolve the target from the page, never hardcoded ----
local target = nil
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'BUILDING_ICONS' then
        target = p.texpos[0]
        break
    end
end
if not target or target == 0 then
    print("Could not resolve BUILDING_ICONS (0,0).")
    return
end
print(string.format("hunting texpos %d (BUILDING_ICONS 0,0)", target))

-- ---- walk ----
local visited, visits, hits = {}, 0, 0

-- Vectors of raw world data can be enormous; cap elements per
-- container so one item vector cannot eat the whole budget.
local MAX_ELEMS = 4000

local SKIP = {
    texture = true, items = true, units = true, map = true,
    map_extras = true, vision = true, world_data = true,
    history = true, artifacts = true, nemesis = true,
}

local function walk(node, path, depth)
    if depth > MAX_DEPTH or hits >= MAX_HITS or visits >= MAX_VISITS then return end
    local t = type(node)
    if t ~= 'userdata' and t ~= 'table' then return end

    local id = nil
    pcall(function() id = tostring(node) end)
    if not id or visited[id] then return end
    visited[id] = true
    visits = visits + 1

    -- pairs pass for structs
    local keys = {}
    pcall(function()
        for k in pairs(node) do
            table.insert(keys, k)
            if #keys > 600 then break end
        end
    end)

    for _, k in ipairs(keys) do
        if hits >= MAX_HITS or visits >= MAX_VISITS then return end
        if not SKIP[k] then
            local ok, v = pcall(function() return node[k] end)
            if ok then
                if type(v) == 'number' then
                    if v == target then
                        hits = hits + 1
                        print("  HIT " .. path .. '.' .. tostring(k))
                    end
                elseif type(v) == 'userdata' or type(v) == 'table' then
                    walk(v, path .. '.' .. tostring(k), depth + 1)
                end
            end
        end
    end

    -- index pass for vectors
    local len = 0
    pcall(function() len = #node end)
    if len and len > 0 then
        local cap = math.min(len, MAX_ELEMS)
        for i = 0, cap - 1 do
            if hits >= MAX_HITS or visits >= MAX_VISITS then return end
            local ok, v = pcall(function() return node[i] end)
            if ok then
                if type(v) == 'number' then
                    if v == target then
                        hits = hits + 1
                        print(string.format("  HIT %s[%d]", path, i))
                    end
                elseif type(v) == 'userdata' or type(v) == 'table' then
                    walk(v, string.format("%s[%d]", path, i), depth + 1)
                end
            end
        end
    end
end

local roots = {
    { 'game',      function() return df.global.game end },
    { 'buildreq',  function() return df.global.buildreq end },
    { 'gview',     function() return df.global.gview end },
    { 'plotinfo',  function() return df.global.plotinfo end },
    { 'raws.buildings', function() return df.global.world.raws.buildings end },
}

for _, r in ipairs(roots) do
    local ok, node = pcall(r[2])
    if ok and node then
        print(string.format("---- %s ----", r[1]))
        walk(node, r[1], 1)
    end
    if hits >= MAX_HITS or visits >= MAX_VISITS then break end
end

print(string.format("done. %d hit(s), %d node(s) visited.", hits, visits))