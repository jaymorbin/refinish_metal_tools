-- refinish-probe-deep.lua
-- PROBE FIRST: Deep Structural Verification of C++ Reaction Shapes

print("==================================================")
print("REFINISH STEEL DIAGNOSTIC: DEEP STRUCTURAL PROBE")
print("==================================================")

local reactions = df.global.world.raws.reactions.reactions
local safe_bar_shells = {}
local safe_powder_shells = {}

for _, rxn in ipairs(reactions) do
    local ok, err = pcall(function()
        local has_item_reagent = false
        local produces_bar = false
        local produces_powder = false
        local has_container_logic = false

        -- 1. DEEP REAGENT CHECK: Verify we have actual physical items
        for _, rgt in ipairs(rxn.reagents) do
            if df.reaction_reagent_itemst:is_instance(rgt) then
                has_item_reagent = true
                -- Look for native container flags (bags, boxes, etc)
                if rgt.flags1.empty or rgt.flags.IN_CONTAINER then
                    has_container_logic = true
                end
            end
        end

        -- 2. DEEP PRODUCT CHECK: Verify the exact engine output type
        if has_item_reagent then
            for _, prod in ipairs(rxn.products) do
                if df.reaction_product_itemst:is_instance(prod) then
                    -- Is it a physical BAR?
                    if prod.item_type == df.item_type.BAR then
                        produces_bar = true
                    -- Is it a physical POWDER?
                    elseif prod.item_type == df.item_type.POWDER_MISC then
                        produces_powder = true
                        -- Does the engine natively route this into a container?
                        if prod.product_to_container and prod.product_to_container ~= "" then
                            has_container_logic = true
                        end
                    end
                end
            end
        end

        -- 3. CATEGORIZE
        if produces_bar then
            table.insert(safe_bar_shells, rxn.code)
        end
        if produces_powder and has_container_logic then
            table.insert(safe_powder_shells, rxn.code)
        end
    end)

    if not ok then
        -- Silent catch: If a mod's reaction is malformed, we just ignore it
        -- rather than spamming the user's console.
    end
end

print("\n--- STRUCTURALLY VERIFIED BAR SHELLS: " .. #safe_bar_shells .. " ---")
for i = 1, #safe_bar_shells do 
    print(i .. ". " .. safe_bar_shells[i]) 
end

print("\n--- STRUCTURALLY VERIFIED POWDER/BAG SHELLS: " .. #safe_powder_shells .. " ---")
for i = 1, #safe_powder_shells do 
    print(i .. ". " .. safe_powder_shells[i]) 
end
print("==================================================")