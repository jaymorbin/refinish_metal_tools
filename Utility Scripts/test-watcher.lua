local utils = require('utils')

print("========================================")
print("--- REFINISH WATCHER DIAGNOSTIC ---")
print("========================================")

local found_job = false

for _, job in utils.listpairs(df.global.world.jobs.list) do
    if job.job_type == df.job_type.CustomReaction then
        local r_name = job.reaction_name
        
        if string.find(r_name, "REFINISH_STEEL_RXN_LUA_GRIND_") then
            found_job = true
            print("DETECTED MOD JOB: " .. r_name)
            
            local item_count = 0
            for i, job_item_ref in ipairs(job.items) do
                local actual_item = job_item_ref.item
                if actual_item then
                    item_count = item_count + 1
                    local itype = actual_item:getType()
                    local mat_idx = actual_item:getMaterialIndex()
                    local desc = dfhack.items.getDescription(actual_item, 0)
                    
                    print(("  -> [Item %d]: Type = %d (%s)"):format(i, itype, desc))
                    
                    local mat_info = dfhack.matinfo.decode(actual_item)
                    if mat_info and mat_info.inorganic then
                        print("     -> DECODED INORGANIC ID: " .. mat_info.inorganic.id)
                    else
                        print("     -> [!] No decoded inorganic ID found. Mat_Index: " .. mat_idx)
                    end
                end
            end
            
            if item_count == 0 then
                print("  -> Physical items attached: 0 (Dwarf hasn't picked up items yet)")
            end
            print("----------------------------------------")
        end
    end
end

if not found_job then
    print("CRITICAL: No generic Refinish Steel jobs detected!")
end
print("========================================")