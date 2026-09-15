-- refinish-probe-purple.lua
local out = {}
table.insert(out, "=== REFINISH STEEL DIAGNOSTIC PROBE: PURPLE GOLD ===")

local inorgs = df.global.world.raws.inorganics.all
local reactions = df.global.world.raws.reactions.reactions

-- 1. Locate Purple Gold
local pg_mat_index = -1
for i, mat in ipairs(inorgs) do
    if mat.id == "PURPLE_GOLD" then
        pg_mat_index = i
        table.insert(out, "1. PURPLE_GOLD found at inorganics index: " .. i)
        break
    end
end

if pg_mat_index == -1 then
    table.insert(out, "1. ERROR: PURPLE_GOLD not found in inorganics array.")
else
    -- 2. Trace Vanilla Reactions
    table.insert(out, "\n2. Scanning vanilla reactions for PURPLE_GOLD...")
    local found_rxn = false
    
    for _, rxn in ipairs(reactions) do
        -- Skip our own injected finishes
        if not string.find(rxn.code, "REFINISH_STEEL_") then
            local involves_pg = false
            
            -- Check if code contains PURPLE_GOLD
            if string.find(rxn.code, "PURPLE_GOLD") then involves_pg = true end
            
            -- Check products for Purple Gold bars
            for _, prod in ipairs(rxn.products) do
                if df.reaction_product_itemst:is_instance(prod) and prod.item_type == 0 and prod.mat_type == 0 and prod.mat_index == pg_mat_index then
                    involves_pg = true
                end
            end

            if involves_pg then
                found_rxn = true
                table.insert(out, "   -> Found Vanilla Reaction: " .. rxn.code)
                table.insert(out, "      - FORTRESS_MODE_ENABLED flag: " .. tostring(rxn.flags.FORTRESS_MODE_ENABLED))
                
                -- Simulate SOURCE B3's exact extraction logic
                local regex_match = string.match(rxn.code, "^([A-Z0-9_]+)_MAKING")
                if regex_match then 
                    table.insert(out, "      - Code Regex Extraction: SUCCESS (" .. regex_match .. ")")
                else
                    table.insert(out, "      - Code Regex Extraction: FAILED (Did not match ^([A-Z0-9_]+)_MAKING)")
                end
                
                local prod_match = false
                for _, prod in ipairs(rxn.products) do
                    if df.reaction_product_itemst:is_instance(prod) then
                        if prod.item_type == 0 and prod.mat_type == 0 and prod.mat_index == pg_mat_index then
                            prod_match = true
                        end
                    end
                end
                if prod_match then
                    table.insert(out, "      - Product Item Extraction: SUCCESS (Found physical bar product)")
                else
                    table.insert(out, "      - Product Item Extraction: FAILED")
                end
            end
        end
    end
    
    if not found_rxn then
        table.insert(out, "   -> ERROR: No vanilla reaction exists in this game that produces PURPLE_GOLD.")
    end
end

for _, line in ipairs(out) do print(line) end