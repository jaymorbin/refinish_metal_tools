--@ module = true
-- refinish-verify-metals.lua
-- Diagnostic tool to verify if civ.resources.metals aligns with permitted reactions

local inorganics = df.global.world.raws.inorganics.all
local reactions = df.global.world.raws.reactions.reactions

-- 1. Identify which metals have native ores (Base Metals)
local has_ore = {}
for i, mat in ipairs(inorganics) do
    if mat.material.flags.IS_STONE then
        for _, ore in ipairs(mat.metal_ore.mat_index) do
            has_ore[ore] = true
        end
    end
end

-- 2. Map all custom reactions that produce a metal bar
-- metal_making_rxns[metal_index] = {rxn_index_1, rxn_index_2}
local metal_making_rxns = {}
for _, rxn in ipairs(reactions) do
    for _, prod in ipairs(rxn.products) do
        -- THE FIX: Verify this is a physical item product, not an item improvement, before reading fields
        if df.reaction_product_itemst:is_instance(prod) then
            if prod.item_type == df.item_type.BAR and prod.mat_type == 0 then
                local mat_idx = prod.mat_index
                if mat_idx >= 0 then
                    metal_making_rxns[mat_idx] = metal_making_rxns[mat_idx] or {}
                    table.insert(metal_making_rxns[mat_idx], rxn.index)
                end
            end
        end
    end
end

-- 3. Audit the Civilizations
print("==================================================")
print("REFINISH VERIFY: AUDITING CIVILIZATION METALS")
print("==================================================")

local civ_count = 0
local red_flags = 0

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        local civ_name = civ.entity_raw.code
        
        -- Get their permitted reactions as a fast lookup dictionary
        local permitted = {}
        for _, pid in ipairs(civ.entity_raw.workshops.permitted_reaction_id) do
            permitted[pid] = true
        end

        local civ_red_flags = 0

        if civ.resources and civ.resources.metals then
            for _, mat_idx in ipairs(civ.resources.metals) do
                local mat = inorganics[mat_idx]
                
                if mat then
                    -- If it doesn't have an ore, it's an alloy. It MUST have a reaction to be made.
                    if not has_ore[mat_idx] then
                        local required_rxns = metal_making_rxns[mat_idx]
                        local can_make = false
                        
                        -- Does the civ possess any of the reactions required to make this metal?
                        if required_rxns then
                            for _, rid in ipairs(required_rxns) do
                                if permitted[rid] then
                                    can_make = true
                                    break
                                end
                            end
                        else
                            -- Failsafe: If no reaction exists globally to make it, it's a divine/spoiler metal
                            can_make = true 
                        end

                        if not can_make and required_rxns then
                            if civ_red_flags == 0 then
                                print(string.format("\n[WARNING] Civ ID %d (%s) Failed Audit:", civ.id, civ_name))
                            end
                            print(string.format("  -> Possesses %s in resources, but lacks ANY permitted reaction to forge it!", mat.id))
                            civ_red_flags = civ_red_flags + 1
                            red_flags = red_flags + 1
                        end
                    end
                end
            end
        end
        civ_count = civ_count + 1
    end
end

print("\n==================================================")
if red_flags == 0 then
    print("VERIFICATION PASS: All resource metals perfectly align with permitted reactions.")
    print("The Hybrid Matrix is 100% safe to use.")
else
    print(string.format("VERIFICATION FAIL: Found %d instances where a civ possesses an alloy but no recipe.", red_flags))
end
print(string.format("Scanned %d Civilizations.", civ_count))
print("==================================================")