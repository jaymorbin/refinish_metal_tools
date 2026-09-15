local utils = require('utils')
local file = io.open("refinish_item_type_probe.txt", "w")
if not file then return end

file:write("=== ENGINE CONSTRUCTION JOB PROBE ===\n\n")

local jobs_found = 0
for _, job in utils.listpairs(df.global.world.jobs.list) do
    if job.job_type == df.job_type.ConstructBuilding then
        jobs_found = jobs_found + 1
        file:write(string.format("--- Construction Job ID: %d ---\n", job.id))
        
        file:write("JOB ITEM FILTERS (What the engine explicitly requires to build this):\n")
        for i, j_item in ipairs(job.job_items) do
            file:write(string.format("  Filter #%d:\n", i))
            
            -- Look at exactly what Item Type the engine asks for
            local i_type_str = "ANY"
            if j_item.item_type ~= -1 then 
                i_type_str = tostring(df.item_type[j_item.item_type]) 
            end
            file:write(string.format("    - Required Item Type: %s\n", i_type_str))
            
            file:write(string.format("    - Required Mat Type: %d\n", j_item.mat_type))
            file:write(string.format("    - Required Mat Index: %d\n", j_item.mat_index))
            
            -- Dump the specific engine filter flags (This is where 'building_material' usually hides)
            file:write("    - Active Filter Flags:\n")
            local flags_found = false
            for k,v in pairs(j_item.flags1) do if v then file:write("      * flags1." .. k .. "\n"); flags_found = true end end
            for k,v in pairs(j_item.flags2) do if v then file:write("      * flags2." .. k .. "\n"); flags_found = true end end
            for k,v in pairs(j_item.flags3) do if v then file:write("      * flags3." .. k .. "\n"); flags_found = true end end
            
            if not flags_found then file:write("      * (None)\n") end
        end
        file:write("\n")
    end
end

file:write(string.format("Total construction jobs probed: %d\n", jobs_found))
file:close()
print("Refinish Steel: Item Type Probe complete. Check refinish_item_type_probe.txt")