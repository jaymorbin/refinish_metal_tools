-- refinish-menu-icon-probe.lua
-- ==========================================
-- BUILD MENU ICON HUNT
-- ==========================================
-- list_icon_texpos drives the workshop's own panel icon, proven by
-- overwriting SOAP_MAKER's and watching the panel change while the
-- build menu did not. So the menu holds its icon somewhere else.
--
-- Strategy: every cell of the BUILDING_ICONS page has a known
-- texpos. Anything caching a menu icon must hold one of those
-- numbers. So rather than guess field names, walk the interface
-- structures and flag any integer that lands in that set, plus any
-- field whose NAME looks icon shaped.
--
-- RUN WITH THE BUILD MENU OPEN on the workshop list. The DFHack
-- console is a separate window, so the menu can stay up.
--
--   refinish-menu-icon-probe [depth]
-- ==========================================

local args = {...}
local MAX_DEPTH = tonumber(args[1]) or 4
local MAX_HITS  = 120

-- ---- BUILDING_ICONS texpos set ----
local icon_set, icon_cell = {}, {}
local page_found = false
for _, p in ipairs(df.global.texture.page) do
    if tostring(p.token) == 'BUILDING_ICONS' then
        page_found = true
        for i = 0, #p.texpos - 1 do
            local v = p.texpos[i]
            if v and v ~= 0 then
                icon_set[v] = true
                icon_cell[v] = string.format("col %d row %d",
                    i % p.page_dim_x, math.floor(i / p.page_dim_x))
            end
        end
        break
    end
end

if not page_found then
    print("BUILDING_ICONS page not loaded. Cannot scan.")
    return
end

local n = 0
for _ in pairs(icon_set) do n = n + 1 end
print(string.format("BUILDING_ICONS: %d distinct texpos values to match against.", n))

-- ---- WALK ----
local hits, visited = 0, {}

local function looks_iconish(name)
    local l = string.lower(tostring(name))
    return l:find('icon') or l:find('texpos') or l:find('tex')
end

local function walk(node, path, depth)
    if depth > MAX_DEPTH or hits >= MAX_HITS then return end
    if type(node) ~= 'userdata' and type(node) ~= 'table' then return end

    local id = tostring(node)
    if visited[id] then return end
    visited[id] = true

    -- Field iteration differs between struct wrappers and vectors,
    -- so try both shapes and ignore whichever throws.
    local keys = {}
    pcall(function()
        for k, _ in pairs(node) do table.insert(keys, k) end
    end)
    if #keys == 0 then
        pcall(function()
            local len = #node
            if len and len > 0 and len < 500 then
                for i = 0, len - 1 do table.insert(keys, i) end
            end
        end)
    end

    for _, k in ipairs(keys) do
        if hits >= MAX_HITS then return end
        local ok, v = pcall(function() return node[k] end)
        if ok then
            local p2 = path .. '.' .. tostring(k)
            if type(v) == 'number' then
                if icon_set[v] then
                    hits = hits + 1
                    print(string.format("  MATCH %s = %d  (%s)",
                        p2, v, icon_cell[v] or '?'))
                elseif looks_iconish(k) and v ~= 0 then
                    hits = hits + 1
                    print(string.format("  named %s = %d", p2, v))
                end
            elseif type(v) == 'userdata' or type(v) == 'table' then
                walk(v, p2, depth + 1)
            end
        end
    end
end

-- ---- ROOTS ----
-- build_selector is the likely home; main_interface is the wider
-- net if it is not. Each root is guarded so a missing structure
-- name reports instead of throwing.
local roots = {
    { 'build_selector', function() return df.global.game.main_interface.build_selector end },
    { 'main_interface', function() return df.global.game.main_interface end },
}

for _, r in ipairs(roots) do
    local ok, node = pcall(r[2])
    if ok and node then
        print(string.format("---- scanning %s (depth %d) ----", r[1], MAX_DEPTH))
        walk(node, r[1], 1)
    else
        print(string.format("---- %s not reachable ----", r[1]))
    end
    if hits >= MAX_HITS then
        print("  (hit cap reached)")
        break
    end
end

print(string.format("Done. %d candidate(s).", hits))