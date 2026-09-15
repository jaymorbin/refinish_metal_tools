local utils = require('utils')

local target_original_rxn = "REFINISH_STEEL_RXN_LUA_GRIND_GEMS"
local spoofed_rxn_id = "MAKE_PLASTER_POWDER" -- We'll use this just to see if the UI updates

local found = false

for _, job in utils.listpairs(df.global.world.jobs.list) do
    if job.job_type == df.job_type.CustomReaction and job.reaction_name == target_original_rxn then
        print("Found active job: " .. job.reaction_name)
        
        -- The crucial test: overwrite the ID string on the active job
        job.reaction_name = spoofed_rxn_id
        
        print("Spoofed job ID to: " .. job.reaction_name)
        found = true
        break
    end
end

if not found then
    print("No active '" .. target_original_rxn .. "' job found.")
end