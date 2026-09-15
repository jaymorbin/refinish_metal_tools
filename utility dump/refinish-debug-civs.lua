-- refinish-debug-civs.lua
-- Hardened Diagnostic Probe
local function safe_id(obj) return obj and obj.id or "UNKNOWN" end

print("\n==========================================")
print("REFINISH STEEL: CIVILIZATION TECH X-RAY")
print("==========================================\n")

local eval_env = dfhack.script_environment('refinish-eval-reaction')
local evaluated_rxns = eval_env.get_metal_making_reactions(false)
local inorgs = df.global.world.raws.inorganics.all
local rxns = df.global.world.raws.reactions.reactions

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        local race_code = civ.entity_raw.code or "UNKNOWN"
        print("CIV: " .. race_code .. " (ID: " .. civ.id .. ")")
        
        -- 1. Check Mood Tech (Grinder Gates)
        local has_forge = false
        local permitted_jobs = civ.entity_raw.jobs.permitted_job
        if permitted_jobs then
            if permitted_jobs[df.job_type.StrangeMoodForge] or permitted_jobs[df.job_type.StrangeMoodMagmaForge] then 
                has_forge = true 
            end
        end
        print("  Forge Tech: " .. tostring(has_forge))

        if has_forge then
            -- 2. Check Native Metals (Source A)
            local native = {}
            if civ.resources and civ.resources.metals then
                for _, m_idx in ipairs(civ.resources.metals) do
                    if inorgs[m_idx] then table.insert(native, inorgs[m_idx].id) end
                end
            end
            print("  Native Metals: " .. (#native > 0 and table.concat(native, ", ") or "NONE"))

            -- 3. Check Evaluated Alloys (Source B)
            local alloys = {}
            local permitted_rxns = civ.entity_raw.workshops.permitted_reaction_id
            for _, pid in ipairs(permitted_rxns) do
                if evaluated_rxns[pid] then
                    local rxn = rxns[pid]
                    if rxn then
                        -- Identify which metal this reaction actually produces
                        local products = {}
                        if rxn.products then
                            for _, prod in ipairs(rxn.products) do
                                if df.reaction_product_itemst:is_instance(prod) then
                                    if prod.item_type == 0 and prod.mat_type == 0 and inorgs[prod.mat_index] then
                                        table.insert(alloys, inorgs[prod.mat_index].id .. " (" .. rxn.code .. ")")
                                    end
                                end
                            end
                        end
                    end
                end
            end
            print("  Custom Alloys: " .. (#alloys > 0 and table.concat(alloys, ", ") or "NONE"))
        end
        print("------------------------------------------")
    end
end
print("==========================================")