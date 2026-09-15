--@ module = true
-- refinish-prototype.lua

local args = {...}
local command = args[1] or "help"

-- ==========================================
-- SCRIPT LOGIC: DUMP
-- ==========================================
if command == "dump" then
    print("==================================================")
    print("PROTOTYPE: DUMPING CIVILIZATION TECH DATA TO FILE")
    print("==================================================")
    
    local file = io.open("refinish_tech_dump.txt", "w")
    if not file then print("Error: Could not create dump file.") return end

    local rxn_idx_to_code = {}
    for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
        rxn_idx_to_code[rxn.index] = rxn.code
    end

    local civ_count = 0
    for _, civ in ipairs(df.global.world.entities.all) do
        if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
            civ_count = civ_count + 1
            file:write(string.format("========================================\nCIVILIZATION ID: %d (%s)\n========================================\n", civ.id, civ.entity_raw.code))
            
            file:write("-- EXPLICIT PERMITTED REACTIONS --\n")
            local permitted_rxns = civ.entity_raw.workshops.permitted_reaction_id
            if #permitted_rxns > 0 then
                for _, pid in ipairs(permitted_rxns) do
                    local code = rxn_idx_to_code[pid] or tostring(pid)
                    file:write("  " .. code .. "\n")
                end
            else
                file:write("  [None]\n")
            end
            
            file:write("\n-- PERMITTED JOBS --\n")
            local jobs_found = 0
            for jid, is_permitted in ipairs(civ.entity_raw.jobs.permitted_job) do
                if is_permitted then
                    local j_name = df.job_type[jid] or tostring(jid)
                    file:write("  " .. j_name .. "\n")
                    jobs_found = jobs_found + 1
                end
            end
            if jobs_found == 0 then file:write("  [None]\n") end
            
            file:write("\n-- WORLD-GEN RESOURCES: METALS --\n")
            if civ.resources and civ.resources.metals then
                local metals_found = 0
                for _, mat_idx in ipairs(civ.resources.metals) do
                    local mat = df.global.world.raws.inorganics.all[mat_idx]
                    if mat then
                        file:write("  " .. mat.id .. "\n")
                        metals_found = metals_found + 1
                    end
                end
                if metals_found == 0 then file:write("  [None]\n") end
            else
                file:write("  [No Resource Array Found]\n")
            end
            
            file:write("\n\n")
        end
    end
    
    file:close()
    print(string.format("Dump complete! %d civilizations logged.", civ_count))
    return
end

-- ==========================================
-- SCRIPT LOGIC: CLEAR ALL
-- ==========================================
if command == "clear" then
    print("==================================================")
    print("PROTOTYPE: EXECUTING GLOBAL ENTITY CLEAR")
    print("==================================================")
    
    local reactions = df.global.world.raws.reactions.reactions
    local rs_ids_to_remove = {}
    
    for _, rxn in ipairs(reactions) do
        if string.find(rxn.code, "REFINISH_STEEL_") then rs_ids_to_remove[rxn.index] = true end
    end

    local total_cleared = 0
    for _, civ in ipairs(df.global.world.entities.all) do
        if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
            local permitted = civ.entity_raw.workshops.permitted_reaction_id
            local civ_cleared = 0
            for i = #permitted - 1, 0, -1 do
                if rs_ids_to_remove[permitted[i]] then
                    permitted:erase(i)
                    civ_cleared = civ_cleared + 1
                    total_cleared = total_cleared + 1
                end
            end
            if civ_cleared > 0 then
                print(string.format("  -> Cleared %d RS tags from Civ ID: %d", civ_cleared, civ.id))
            end
        end
    end
    print(string.format("Prototype: Successfully purged %d total RS tags.", total_cleared))
    return
end

-- ==========================================
-- SCRIPT LOGIC: INJECT (The Mood & Matrix Evaluator)
-- ==========================================
if command == "inject" then
    print("==================================================")
    print("PROTOTYPE: EXECUTING TECH EVALUATION & INJECTION")
    print("==================================================")
    
    local reactions = df.global.world.raws.reactions.reactions
    local rxn_idx_to_code = {}
    local rs_payloads = { FINISHES = {}, STONE_GRIND = {}, GEM_GRIND = {}, METAL_GRIND = {} }

    -- 1. Categorize our payload
    for _, rxn in ipairs(reactions) do
        rxn_idx_to_code[rxn.index] = rxn.code
        if string.find(rxn.code, "REFINISH_STEEL_RXN_LUA_GRIND_COMMON") or string.find(rxn.code, "REFINISH_STEEL_RXN_LUA_GRIND_ANY") then
            table.insert(rs_payloads.STONE_GRIND, rxn.index)
        elseif string.find(rxn.code, "REFINISH_STEEL_RXN_LUA_GRIND_GEMS") then
            table.insert(rs_payloads.GEM_GRIND, rxn.index)
        elseif string.find(rxn.code, "REFINISH_STEEL_RXN_LUA_GRIND_METAL") then
            table.insert(rs_payloads.METAL_GRIND, rxn.index)
        elseif string.find(rxn.code, "REFINISH_STEEL_RXN_") then
            table.insert(rs_payloads.FINISHES, rxn.index)
        end
    end

    -- 2. Dynamically build strict Metal Reaction keys from the live world
    local valid_metal_reactions = {}
    for _, mat in ipairs(df.global.world.raws.inorganics.all) do
        if mat.material.flags.IS_METAL then
            valid_metal_reactions[mat.id .. "_MAKING"] = true
            valid_metal_reactions[mat.id .. "_MAKING2"] = true
        end
    end
    -- Catch hardcoded overhaul exceptions identified in your dump
    valid_metal_reactions["IRON_BLOOM_PROCESS"] = true 

    local civs_processed = 0

    -- 3. Sweep Entities & Evaluate Tech
    for _, civ in ipairs(df.global.world.entities.all) do
        if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
            
            -- Check Strange Mood Jobs (The Foundation)
            local has_forge_mood = false
            local has_mason_mood = false
            local has_gem_mood = false
            
            for jid, is_permitted in ipairs(civ.entity_raw.jobs.permitted_job) do
                if is_permitted then
                    if jid == df.job_type.StrangeMoodForge or jid == df.job_type.StrangeMoodMagmaForge then has_forge_mood = true end
                    if jid == df.job_type.StrangeMoodMason then has_mason_mood = true end
                    if jid == df.job_type.StrangeMoodJeweller then has_gem_mood = true end
                end
            end

            -- Check Reactions (The Verification)
            local has_steel_rxn = false
            local has_metal_rxn = false
            
            local permitted_rxns = civ.entity_raw.workshops.permitted_reaction_id
            for _, pid in ipairs(permitted_rxns) do
                local code = rxn_idx_to_code[pid]
                if code then
                    if string.find(code, "STEEL_MAKING") then 
                        has_steel_rxn = true
                        has_metal_rxn = true
                        break 
                    elseif valid_metal_reactions[code] then
                        has_metal_rxn = true
                    end
                end
            end

            -- Execute the Double-Lock Logic Gates
            local stone_tech = has_mason_mood
            local gem_tech   = has_gem_mood
            local metal_tech = (has_forge_mood and has_metal_rxn)
            local steel_tech = (has_forge_mood and has_steel_rxn)

            if stone_tech or gem_tech or metal_tech or steel_tech then
                print(string.format("Evaluating Civ ID %d (%s):", civ.id, civ.entity_raw.code))
                print(string.format("  -> Stone: %s | Gem: %s | Metal: %s | Steel: %s", tostring(stone_tech), tostring(gem_tech), tostring(metal_tech), tostring(steel_tech)))
                
                local already_permitted = {}
                for _, pid in ipairs(permitted_rxns) do already_permitted[pid] = true end
                
                local injected_count = 0
                local function inject_payload(payload_table)
                    for _, target_idx in ipairs(payload_table) do
                        if not already_permitted[target_idx] then
                            permitted_rxns:insert('#', target_idx)
                            injected_count = injected_count + 1
                        end
                    end
                end

                if steel_tech then inject_payload(rs_payloads.FINISHES) end
                if metal_tech then inject_payload(rs_payloads.METAL_GRIND) end
                if stone_tech then inject_payload(rs_payloads.STONE_GRIND) end
                if gem_tech   then inject_payload(rs_payloads.GEM_GRIND) end
                
                print(string.format("  -> Successfully injected %d Refinish Steel reactions.", injected_count))
                civs_processed = civs_processed + 1
            end
        end
    end
    print("==================================================")
    print(string.format("Prototype: Scan complete. Processed %d capable civilizations.", civs_processed))
    return
end

print("Refinish Prototype commands: 'dump', 'clear', or 'inject'")