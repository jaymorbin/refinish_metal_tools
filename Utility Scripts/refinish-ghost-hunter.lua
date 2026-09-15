-- refinish-ghost-hunter.lua
local json = require('json')

local file = io.open("refinish_ghost_hunter_log.txt", "w")
if not file then
    print("Failed to open ghost hunter log file.")
    return
end

file:write("=== REFINISH STEEL GHOST HUNTER DIAGNOSTIC ===\n\n")

-- 1. Check Persistent Payload
file:write("--- 1. PERSISTENT PAYLOAD CHECK ---\n")
local payload = dfhack.persistent.getSiteData("REFINISH_STEEL_PAYLOAD")
if not payload or payload == "" then
    file:write("Payload is EMPTY.\n")
else
    local ok, parsed = pcall(json.decode, payload)
    if ok and parsed then
        file:write(string.format("Payload decoded successfully.\n"))
        file:write(string.format("Payload Site ID: %s\n", tostring(parsed.site_id)))
        file:write(string.format("Payload World Name: %s\n", tostring(parsed.world_name)))
        
        local i_count = parsed.items and #parsed.items or 0
        local b_count = parsed.buildings and #parsed.buildings or 0
        local c_count = parsed.constructions and #parsed.constructions or 0
        
        file:write(string.format("\nStored Items: %d\n", i_count))
        if i_count > 0 then
            for _, v in ipairs(parsed.items) do 
                file:write(string.format("  - Item ID: %s | Mat: %s\n", tostring(v.id), tostring(v.mat))) 
            end
        end
        
        file:write(string.format("\nStored Buildings: %d\n", b_count))
        if b_count > 0 then
            for _, v in ipairs(parsed.buildings) do 
                file:write(string.format("  - Bld ID: %s | Mat: %s\n", tostring(v.id), tostring(v.mat))) 
            end
        end
        
        file:write(string.format("\nStored Constructions: %d\n", c_count))
        if c_count > 0 then
            for _, v in ipairs(parsed.constructions) do 
                file:write(string.format("  - Cons XYZ: [%s, %s, %s] | Mat: %s\n", tostring(v.x), tostring(v.y), tostring(v.z), tostring(v.mat))) 
            end
        end
    else
        file:write("Payload exists but failed to decode.\n")
    end
end

-- 2. Active Map Scan
file:write("\n--- 2. ACTIVE MAP SCAN ---\n")
local inorganics = df.global.world.raws.inorganics.all

file:write("Scanning df.global.world.items.all...\n")
local map_items = 0
for _, item in ipairs(df.global.world.items.all) do
    local ok, m_idx = pcall(function() return item.mat_index end)
    if ok and type(m_idx) == 'number' and m_idx >= 0 and m_idx < #inorganics then
        local mat_id = inorganics[m_idx].id
        if string.find(mat_id, "REFINISH_STEEL_") then
            map_items = map_items + 1
            local pos = item.pos
            local item_type_str = tostring(df.item_type[item:getType()])
            file:write(string.format("  Found Item ID: %s | Type: %s | Mat: %s | Pos: [%d, %d, %d]\n", tostring(item.id), item_type_str, mat_id, pos.x, pos.y, pos.z))
        end
    end
end
file:write(string.format("Total active modded items on map: %d\n", map_items))

file:write("\nScanning df.global.world.buildings.all...\n")
local map_blds = 0
for _, bld in ipairs(df.global.world.buildings.all) do
    local ok, m_idx = pcall(function() return bld.mat_index end)
    if ok and type(m_idx) == 'number' and m_idx >= 0 and m_idx < #inorganics then
        local mat_id = inorganics[m_idx].id
        if string.find(mat_id, "REFINISH_STEEL_") then
            map_blds = map_blds + 1
            file:write(string.format("  Found Bld ID: %s | Mat: %s\n", tostring(bld.id), mat_id))
        end
    end
end
file:write(string.format("Total active modded buildings on map: %d\n", map_blds))

file:close()
print("Refinish Steel: Ghost hunter diagnostic complete. Check refinish_ghost_hunter_log.txt")