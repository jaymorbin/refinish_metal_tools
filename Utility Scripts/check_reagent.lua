-- check_reagent.lua
-- Run this in the DFHack console while hovering over the Mason's shop

local bld = dfhack.gui.getSelectedBuilding(true)
if not bld then
    qerror("Error: Please select a workshop in the game UI first.")
end

if #bld.jobs == 0 then
    print("No jobs currently queued at this workshop.")
    return
end

-- Grab the first job in the queue (the active one)
local current_job = bld.jobs[0]
print("========================================")
print("Inspecting Active Job: " .. tostring(current_job.job_type))
print("Reaction Name (if applicable): " .. tostring(current_job.reaction_name))
print("----------------------------------------")

-- Loop through the actual items assigned to this job
local item_count = 0
for _, job_item_ref in ipairs(current_job.items) do
    local actual_item = job_item_ref.item
    
    if actual_item then
        item_count = item_count + 1
        -- Decode the material into something readable
        local mat_info = dfhack.matinfo.decode(actual_item)
        
        print(("Reagent %d:"):format(item_count))
        print(("  Item Type: %s"):format(dfhack.items.getDescription(actual_item, 0)))
        
        if mat_info then
            print(("  Decoded Material: %s"):format(mat_info:toString()))
            print(("  Mat_Type ID: %d"):format(actual_item.mat_type))
            print(("  Mat_Index ID: %d"):format(actual_item.mat_index))
        else
            print("  Material: Could not decode (Hardcoded or generic)")
        end
    end
end

if item_count == 0 then
    print("No specific items have been attached to this job yet.")
    print("Wait for a dwarf to bring the reagents to the shop!")
end
print("========================================")