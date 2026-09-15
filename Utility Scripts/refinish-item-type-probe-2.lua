local utils = require('utils')
local file = io.open("refinish_item_type_probe-2.txt", "w")
if not file then return end

file:write("=== UNFILTERED ENGINE JOB PROBE ===\n\n")

local count = 0
for _, job in utils.listpairs(df.global.world.jobs.list) do
    count = count + 1
    local j_type_str = tostring(df.job_type[job.job_type]) or "UNKNOWN"
    
    file:write(string.format("--- Job ID: %d | Type: %s ---\n", job.id, j_type_str))
    
    if #job.job_items > 0 then
        file:write("JOB ITEM FILTERS:\n")
        for i, j_item in ipairs(job.job_items) do
            local i_type_str = "ANY"
            if j_item.item_type ~= -1 then 
                i_type_str = tostring(df.item_type[j_item.item_type]) 
            end
            
            file:write(string.format("  Filter #%d -> Req Type: %s | Mat Type: %d | Mat Index: %d\n", i, i_type_str, j_item.mat_type, j_item.mat_index))
            
            file:write("    Flags:\n")
            local flags_found = false
            for k,v in pairs(j_item.flags1) do if v then file:write("      * flags1." .. k .. "\n"); flags_found = true end end
            for k,v in pairs(j_item.flags2) do if v then file:write("      * flags2." .. k .. "\n"); flags_found = true end end
            for k,v in pairs(j_item.flags3) do if v then file:write("      * flags3." .. k .. "\n"); flags_found = true end end
            
            if not flags_found then file:write("      * (None)\n") end
        end
    else
        file:write("  (No item filters attached to this job)\n")
    end
    file:write("\n")
end

file:write(string.format("Total jobs probed: %d\n", count))
file:close()
print("Refinish Steel: Unfiltered job probe complete. Check refinish_item_type_probe.txt")