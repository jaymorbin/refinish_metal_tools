-- ==========================================
-- REFINISH STEEL: DIAGNOSTIC PROBE
-- Purpose: Safely track the data path of a known modded metal
-- to find exactly where the UI extraction fails.
-- ==========================================

local function run_probe()
    print("\n==========================================")
    print("REFINISH STEEL: UI EXTRACTION PROBE")
    print("==========================================")

    if not dfhack.isMapLoaded() then
        print("Error: Map not loaded.")
        return
    end

    local player_civ = df.historical_entity.find(df.global.plotinfo.civ_id)
    if not player_civ or not player_civ.entity_raw then
        print("Error: Could not find player civilization raw data.")
        return
    end

    local permitted_rxns = player_civ.entity_raw.workshops.permitted_reaction_id
    local rxns = df.global.world.raws.reactions.reactions
    local inorgs = df.global.world.raws.inorganics.all

    -- 1. Check if the Modded Reaction is even in the Civ's Permitted List
    print("\n--- PHASE 1: PERMITTED REACTION CHECK ---")
    local target_code = "AKIMRIL_MAKING"
    local target_index = -1
    local is_permitted = false

    for i, rxn in ipairs(rxns) do
        if rxn.code == target_code then
            target_index = i
            break
        end
    end

    if target_index == -1 then
        print("FAILED: Could not find reaction " .. target_code .. " in global array.")
        return
    else
        print("FOUND: " .. target_code .. " is at Index " .. target_index)
    end

    for _, pid in ipairs(permitted_rxns) do
        if pid == target_index then
            is_permitted = true
            break
        end
    end

    print("Is " .. target_code .. " permitted for this civilization?: " .. tostring(is_permitted))

    -- 2. Simulate the UI Panel's Extraction Logic
    if is_permitted then
        print("\n--- PHASE 2: UI EXTRACTION SIMULATION ---")
        local rxn = rxns[target_index]
        
        print("Checking Products...")
        if rxn.products then
            for i, prod in ipairs(rxn.products) do
                print(string.format("  Product [%d]: item_type=%d, mat_type=%d, mat_index=%d", 
                    i, prod.item_type, prod.mat_type, prod.mat_index))
                if prod.mat_index >= 0 and prod.mat_index < #inorgs then
                    print("  -> Resolves to Inorganic ID: " .. inorgs[prod.mat_index].id)
                else
                    print("  -> CANNOT RESOLVE: mat_index is out of bounds or -1")
                end
            end
        else
            print("  No products found.")
        end

        print("Checking Legacy Regex Fallback...")
        local code_match = string.match(rxn.code, "^([A-Z0-9_]+)_MAKING")
        if code_match then
            print("  -> Regex matched ID: " .. code_match)
        else
            print("  -> Regex failed.")
        end
    end

    print("\n==========================================")
end

run_probe()