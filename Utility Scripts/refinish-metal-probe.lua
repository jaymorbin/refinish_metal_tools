local file = io.open("refinish_metal_flags_probe.txt", "w")
if not file then return end

file:write("=== COMPLETE METAL FLAGS DUMP ===\n\n")

local inorganics = df.global.world.raws.inorganics.all
local targets = {
    ["STEEL"] = true,
    ["GOLD"] = true,
    ["COPPER"] = true,
    ["PIG_IRON"] = true
}

for i, mat in ipairs(inorganics) do
    if targets[mat.id] then
        file:write(string.format("--- %s (Index: %d) ---\n", mat.id, i))
        
        -- Dump ALL Inorganic Flags (mat.flags)
        file:write("INORGANIC FLAGS (mat.flags):\n")
        for k, v in pairs(mat.flags) do
            file:write(string.format("  - %-30s : %s\n", tostring(k), tostring(v)))
        end

        -- Dump ALL Material Flags (mat.material.flags)
        file:write("\nMATERIAL FLAGS (mat.material.flags):\n")
        for k, v in pairs(mat.material.flags) do
            file:write(string.format("  - %-30s : %s\n", tostring(k), tostring(v)))
        end
        
        file:write("\n==================================\n\n")
    end
end

file:close()
print("Refinish Steel: Complete flag dump finished. Check refinish_metal_flags_probe.txt")