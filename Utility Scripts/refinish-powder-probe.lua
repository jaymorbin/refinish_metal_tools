-- refinish-powder-probe.lua
-- Scans all vanilla reactions for a native POWDER_MISC reagent to map its true structure

local found = 0
print("==================================================")
print("PROBING FOR NATIVE POWDER_MISC REAGENTS")
print("==================================================")

for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    for i, r in ipairs(rxn.reagents) do
        if r.item_type == 70 then -- 70 is POWDER_MISC
            found = found + 1
            print(string.format("REACTION: %s | REAGENT [%d] (Code: %s)", rxn.code, i - 1, tostring(r.code)))
            print(string.format("  Item Type: %d | Subtype: %d", r.item_type, r.item_subtype))
            print(string.format("  Mat Type: %d | Mat Index: %d", r.mat_type, r.mat_index))
            print(string.format("  Qty: %d | Min Dimension: %d", r.quantity, r.min_dimension))
            
            if r.reaction_class and r.reaction_class ~= "" then
                print(string.format("  Reaction Class: '%s'", r.reaction_class))
            end
            
            local flags_str = ""
            for k, v in pairs(r.flags) do if v then flags_str = flags_str .. tostring(k) .. " " end end
            if flags_str ~= "" then print(string.format("  Flags: %s", flags_str)) end
            
            local flags1_str = ""
            for k, v in pairs(r.flags1) do if v then flags1_str = flags1_str .. tostring(k) .. " " end end
            if flags1_str ~= "" then print(string.format("  Flags1: %s", flags1_str)) end
            
            local flags2_str = ""
            for k, v in pairs(r.flags2) do if v then flags2_str = flags2_str .. tostring(k) .. " " end end
            if flags2_str ~= "" then print(string.format("  Flags2: %s", flags2_str)) end
            
            print("- - - - - - - - - - - - - - - - - - - - - - - - - ")
        end
    end
end

if found == 0 then
    print("CRITICAL: No native POWDER_MISC reagents found in any loaded reaction.")
end
print("==================================================")