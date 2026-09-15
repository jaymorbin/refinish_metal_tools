-- refinish-probe-v2.lua
-- PROBE FIRST: Deep Structural Verification (Filtered for Inorganics & Metals)

print("==================================================")
print("REFINISH STEEL DIAGNOSTIC: INORGANIC STRUCTURAL PROBE")
print("==================================================")

local reactions = df.global.world.raws.reactions.reactions
local inorganics = df.global.world.raws.inorganics.all
local safe_bar_shells = {}
local safe_powder_shells = {}

for _, rxn in ipairs(reactions) do
    local ok, err = pcall(function()
        local has_item_reagent = false
        local produces_metal_bar = false
        local produces_inorganic_powder = false
        local has_container_logic = false

        -- 1. DEEP REAGENT CHECK
        for _, rgt in ipairs(rxn.reagents) do
            if df.reaction_reagent_itemst:is_instance(rgt) then
                has_item_reagent = true
                if rgt.flags1.empty or rgt.flags.IN_CONTAINER then
                    has_container_logic = true
                end
            end
        end

        -- 2. DEEP PRODUCT CHECK
        if has_item_reagent then
            for _, prod in ipairs(rxn.products) do
                if df.reaction_product_itemst:is_instance(prod) then
                    
                    -- FILTER A: METAL BARS ONLY
                    if prod.item_type == df.item_type.BAR and prod.mat_type == 0 then
                        -- Verify the engine actually considers this inorganic a metal
                        if prod.mat_index >= 0 and prod.mat_index < #inorganics then
                            local inorg_mat = inorganics[prod.mat_index]
                            if inorg_mat and inorg_mat.material.flags.IS_METAL then
                                produces_metal_bar = true
                            end
                        end
                        
                    -- FILTER B: INORGANIC POWDERS ONLY
                    elseif prod.item_type == df.item_type.POWDER_MISC and prod.mat_type == 0 then
                        produces_inorganic_powder = true
                        if prod.product_to_container and prod.product_to_container ~= "" then
                            has_container_logic = true
                        end
                    end
                end
            end
        end

        -- 3. CATEGORIZE
        if produces_metal_bar then
            table.insert(safe_bar_shells, rxn.code)
        end
        if produces_inorganic_powder and has_container_logic then
            table.insert(safe_powder_shells, rxn.code)
        end
    end)
end

print("\n--- VERIFIED INORGANIC METAL BAR SHELLS: " .. #safe_bar_shells .. " ---")
for i = 1, #safe_bar_shells do 
    print(i .. ". " .. safe_bar_shells[i]) 
end

print("\n--- VERIFIED INORGANIC POWDER/BAG SHELLS: " .. #safe_powder_shells .. " ---")
for i = 1, #safe_powder_shells do 
    print(i .. ". " .. safe_powder_shells[i]) 
end
print("==================================================")