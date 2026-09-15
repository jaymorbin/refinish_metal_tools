--@ module = true
-- refinish-diag-entity.lua
-- Diagnostic probe to isolate the disconnect between evaluators and civ permissions.

local bases_env = dfhack.script_environment('refinish-bases')
local eval_env = dfhack.script_environment('refinish-eval-reaction')

print("\n=== REFINISH STEEL: DIAGNOSTIC PROBE START ===")

-- 1. Check valid bases map
local valid_metals_list = bases_env.get_valid_bases(false, false)
local valid_metal_indices = {}
for _, mat in ipairs(valid_metals_list) do
    valid_metal_indices[mat.index] = mat.id
end
print("Loaded " .. #valid_metals_list .. " valid base metals.")

-- 2. Check evaluator map
local evaluated_rxns = eval_env.get_metal_making_reactions(false)
local eval_count = 0
for k,v in pairs(evaluated_rxns) do eval_count = eval_count + 1 end
print("Evaluator identified " .. eval_count .. " metal-making reactions globally.")

-- 3. Probe the player civ
local player_civ = df.historical_entity.find(df.global.plotinfo.civ_id)
if not player_civ or not player_civ.entity_raw then
    print("ERROR: Could not find player civ entity_raw.")
    return
end

local permitted = player_civ.entity_raw.workshops.permitted_reaction_id
print("Player civ has " .. #permitted .. " permitted reactions.")

print("\n--- SCANNING CIV FORGE REACTIONS ---")
local found_metals = 0
for _, pid in ipairs(permitted) do
    local rxn = df.global.world.raws.reactions.reactions[pid]
    if rxn then
        -- Only print reactions that the engine flagged as permitted, 
        -- AND either the evaluator caught it OR it looks like vanilla metal making
        local eval_data = evaluated_rxns[pid]
        if eval_data or string.find(rxn.code, "MAKING") then
            local base_id = "NONE"
            local status = "MISMATCH"
            
            if eval_data then
                base_id = valid_metal_indices[eval_data.mat_index] or ("INVALID_BASE_IDX_" .. tostring(eval_data.mat_index))
                if valid_metal_indices[eval_data.mat_index] then 
                    status = "SUCCESS" 
                    found_metals = found_metals + 1 
                end
            else
                status = "EVAL_MISSED"
            end

            print(string.format("PID: %4d | Code: %-25s | Eval Score: %3s | Target MatIdx: %4s | Base Resolved: %s | Status: %s", 
                pid, 
                rxn.code, 
                eval_data and eval_data.score or "N/A", 
                eval_data and eval_data.mat_index or "N/A",
                base_id,
                status
            ))
        end
    end
end

print("\nTotal successfully resolved metals for player civ: " .. found_metals)
print("=== REFINISH STEEL: DIAGNOSTIC PROBE END ===\n")

return _ENV