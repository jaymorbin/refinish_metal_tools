--@ module = true
-- refinish-probe-reaction.lua
local args = {...}
local target_code = args[1] or "PURPLE_GOLD_MAKING"

print("==================================================")
print("PROBING REACTION: " .. target_code)
print("==================================================")

local found = false
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    if rxn.code == target_code then
        found = true
        print("MATCH FOUND. Reading engine flags...")
        
        -- Check the AUTOMATIC flag
        local is_auto = rxn.flags and rxn.flags.AUTOMATIC
        print(" -> [AUTOMATIC] tag present: " .. tostring(is_auto))
        
        -- List the workshops it belongs to
        print(" -> Assigned Buildings:")
        if rxn.building and rxn.building.type then
            for i, b_type in ipairs(rxn.building.type) do
                local b_custom = rxn.building.custom[i]
                print(string.format("      Type: %d | Custom ID: %d", b_type, b_custom))
            end
        else
            print("      (None assigned)")
        end
        break
    end
end

if not found then
    print("ERROR: Reaction '" .. target_code .. "' does not exist in the raw arrays.")
end
print("==================================================")