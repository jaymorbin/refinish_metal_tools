-- ==========================================
-- THE UNIVERSAL SCRUBBER (LIFO TEARDOWN)
-- ==========================================
print("Refinish Steel: Initiating deep memory scrub...")

local function scrub_injected_data()
    -- 1. IDENTIFY TARGETS
    -- We must catalog the integer IDs of our custom reactions first, 
    -- so we know exactly what to delete from the civilization UI.
    local rxn_ids_to_remove = {}
    local reactions_array = df.global.world.raws.reactions.reactions
    
    for i = #reactions_array - 1, 0, -1 do
        local rxn = reactions_array[i]
        -- Catch any reaction code that contains our signature
        if string.find(rxn.code, "REFINISH_STEEL") then
            rxn_ids_to_remove[rxn.index] = true
        end
    end

    -- 2. SCRUB THE ENTITY (UI Menu)
    local player_civ = df.historical_entity.find(df.global.plotinfo.civ_id)
    if player_civ and player_civ.entity_raw then
        local permitted = player_civ.entity_raw.workshops.permitted_reaction_id
        -- Iterate backwards!
        for i = #permitted - 1, 0, -1 do
            if rxn_ids_to_remove[permitted[i]] then
                permitted:erase(i)
            end
        end
        print("Refinish Steel: Smelter UI restored to vanilla.")
    end

    -- 3. SCRUB THE REACTIONS ARRAY (RAM)
    local scrubbed_rxns = 0
    for i = #reactions_array - 1, 0, -1 do
        local rxn = reactions_array[i]
        if string.find(rxn.code, "REFINISH_STEEL") then
            rxn:delete() -- Free the C++ memory allocation
            reactions_array:erase(i) -- Remove the pointer from the global vector
            scrubbed_rxns = scrubbed_rxns + 1
        end
    end
    if scrubbed_rxns > 0 then
        print("Refinish Steel: Excised " .. scrubbed_rxns .. " injected reactions from memory.")
    end

    -- 4. SCRUB THE MATERIALS ARRAY (RAM)
    local inorganics = df.global.world.raws.inorganics.all
    local scrubbed_mats = 0
    for i = #inorganics - 1, 0, -1 do
        local mat = inorganics[i]
        if string.find(mat.id, "REFINISHED_STEEL") then
            mat:delete() -- Free the C++ memory allocation
            inorganics:erase(i) -- Remove the pointer from the global vector
            scrubbed_mats = scrubbed_mats + 1
        end
    end
    if scrubbed_mats > 0 then
        print("Refinish Steel: Excised " .. scrubbed_mats .. " injected materials from memory.")
    end
end

local ok, err = pcall(scrub_injected_data)
if not ok then
    print("Refinish Steel CRITICAL ERROR during scrub: " .. tostring(err))
else
    print("Refinish Steel: Memory scrub complete. State is 100% Vanilla.")
end