-- refinish-forensics.lua
-- Deep diagnostic probe for Reaction Reagents and Products

local function dump_reagent(i, r)
    local type_name = df.item_type[r.item_type] or "UNKNOWN"
    print(string.format("  REAGENT [%d] - Code: %s", i, tostring(r.code)))
    print(string.format("    Item Type: %s (%d) | Subtype: %d", type_name, r.item_type, r.item_subtype))
    print(string.format("    Mat Type: %d | Mat Index: %d", r.mat_type, r.mat_index))
    print(string.format("    Qty: %d | Min Dimension: %d", r.quantity, r.min_dimension))
    
    if r.reaction_class and r.reaction_class ~= "" then
        print(string.format("    Reaction Class: '%s'", r.reaction_class))
    end
    
    if r.contains and #r.contains > 0 then
        local c_str = ""
        for _, c_idx in ipairs(r.contains) do c_str = c_str .. tostring(c_idx) .. " " end
        print(string.format("    Contains Links To Reagent(s): [%s]", c_str))
    end
    
    local flags_str = ""
    for k, v in pairs(r.flags) do
        if v then flags_str = flags_str .. tostring(k) .. " " end
    end
    if flags_str ~= "" then print(string.format("    Flags: %s", flags_str)) end
end

local function dump_product(i, p)
    local type_name = df.item_type[p.item_type] or "UNKNOWN"
    print(string.format("  PRODUCT [%d]", i))
    print(string.format("    Item Type: %s (%d) | Subtype: %d", type_name, p.item_type, p.item_subtype))
    print(string.format("    Mat Type: %d | Mat Index: %d", p.mat_type, p.mat_index))
    print(string.format("    Count: %d | Product Dimension: %d", p.count, p.product_dimension))
    
    if p.product_to_container and p.product_to_container ~= "" then
        print(string.format("    Product To Container: '%s'", p.product_to_container))
    end
end

local steel_rxn, plaster_rxn
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    if rxn.code == "STEEL_MAKING" then steel_rxn = rxn end
    if rxn.code == "MAKE_PLASTER_POWDER" then plaster_rxn = rxn end
    if steel_rxn and plaster_rxn then break end
end

if not steel_rxn or not plaster_rxn then
    print("FORENSICS ERROR: Could not find base templates. Are you in a vanilla world?")
    return
end

print("==================================================")
print("DEEP FORENSICS: " .. steel_rxn.code)
print("--------------------------------------------------")
for i, r in ipairs(steel_rxn.reagents) do dump_reagent(i - 1, r) end
print("- - - - - - - - - - - - - - - - - - - - - - - - - ")
for i, p in ipairs(steel_rxn.products) do dump_product(i - 1, p) end

print("==================================================")
print("DEEP FORENSICS: " .. plaster_rxn.code)
print("--------------------------------------------------")
for i, r in ipairs(plaster_rxn.reagents) do dump_reagent(i - 1, r) end
print("- - - - - - - - - - - - - - - - - - - - - - - - - ")
for i, p in ipairs(plaster_rxn.products) do dump_product(i - 1, p) end
print("==================================================")