local file = io.open("refinish_struct_probe.txt", "w")
if not file then return end

file:write("=== C++ STRUCT & COMPARISON PROBE ===\n\n")

local inorganics = df.global.world.raws.inorganics.all
local target_mat = nil
local pig_iron = nil

for _, mat in ipairs(inorganics) do
    if mat.id == "STEEL" then target_mat = mat end
    if mat.id == "PIG_IRON" then pig_iron = mat end
end

if target_mat then
    file:write("--- 1. ROOT PROPERTIES OF df.inorganic_raw ---\n")
    file:write("(Looking for any field related to building/constructions)\n")
    for k, v in pairs(target_mat) do
        file:write(string.format("  - %-25s : %s\n", tostring(k), type(v)))
    end

    file:write("\n--- 2. PROPERTIES OF df.material ---\n")
    for k, v in pairs(target_mat.material) do
        file:write(string.format("  - %-25s : %s\n", tostring(k), type(v)))
    end
end

if pig_iron then
    file:write("\n--- 3. PIG IRON CAPABILITIES (True Flags Only) ---\n")
    file:write("(Compare this to Steel to see what Pig Iron is legally allowed to do)\n")
    
    file:write("INORGANIC FLAGS:\n")
    local i_flags = false
    for k, v in pairs(pig_iron.flags) do
        if v == true then 
            file:write("  - " .. tostring(k) .. "\n") 
            i_flags = true
        end
    end
    if not i_flags then file:write("  (None)\n") end

    file:write("MATERIAL FLAGS:\n")
    local m_flags = false
    for k, v in pairs(pig_iron.material.flags) do
        if v == true then 
            file:write("  - " .. tostring(k) .. "\n") 
            m_flags = true
        end
    end
    if not m_flags then file:write("  (None)\n") end
end

file:close()
print("Refinish Steel: Struct probe complete. Check refinish_struct_probe.txt")