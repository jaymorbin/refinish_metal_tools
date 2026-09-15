--@ module = true
-- refinish-dump-raws.lua
local args = {...}
local target_code = args[1] or "MOUNTAIN"

local file = io.open(dfhack.getDFPath() .. "/refinish_permission_dump_" .. target_code .. ".txt", "w")
file:write("DUMPING EXACT PATH: df.global.world.raws.entities.all for " .. target_code .. "\n")
file:write("======================================================================\n\n")

local found_ent = nil
for _, ent in ipairs(df.global.world.raws.entities.all) do
    if ent.code == target_code then
        found_ent = ent
        break
    end
end

if not found_ent then
    file:write("Could not find entity code: " .. target_code)
    file:close()
    print("Done. Entity not found.")
    return
end

if found_ent.raws then
    file:write("SUCCESS: .raws field found!\n")
    file:write("--------------------------------------------------\n")
    for i, str_ptr in ipairs(found_ent.raws) do
        -- THE FIX: Forcefully read the .value property of the userdata pointer
        local val = str_ptr and str_ptr.value or "[NULL POINTER]"
        file:write(tostring(i) .. ": " .. val .. "\n")
    end
else
    file:write("RESULT: .raws is nil on this object.\n")
end

file:close()
print("Dump complete. Check refinish_permission_dump_" .. target_code .. ".txt in your main DF folder.")