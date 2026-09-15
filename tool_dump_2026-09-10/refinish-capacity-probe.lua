-- refinish-capacity-probe.lua
-- Reports capacity and volume for every container-capable item in
-- the fort, grouped by type and subtype. Read-only.

local seen = {}

for _, it in ipairs(df.global.world.items.all) do
    local ok = pcall(function()
        local cap = dfhack.items.getCapacity(it)
        if cap and cap > 0 then
            -- Key by type plus subtype so each distinct container
            -- reports once rather than per instance.
            local tname = df.item_type[it:getType()] or '?'
            local sub = ''
            pcall(function()
                local st = it.subtype
                if st then sub = ':' .. tostring(st.id) end
            end)
            local key = tname .. sub
            if not seen[key] then
                seen[key] = { cap = cap, vol = it:getVolume(), n = 0 }
            end
            seen[key].n = seen[key].n + 1
        end
    end)
end

local keys = {}
for k in pairs(seen) do table.insert(keys, k) end
table.sort(keys)

print(string.format("%-40s %10s %10s %6s", "CONTAINER", "CAPACITY", "VOLUME", "COUNT"))
for _, k in ipairs(keys) do
    local e = seen[k]
    print(string.format("%-40s %10d %10d %6d", k, e.cap, e.vol, e.n))
end
if #keys == 0 then
    print("No containers found. Make a barrel or pot first.")
end