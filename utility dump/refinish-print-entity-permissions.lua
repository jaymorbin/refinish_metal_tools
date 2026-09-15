--@ module = true
-- refinish-dump-entity.lua
local args = {...}
local target_civ = args[1] or "MOUNTAIN"

print("Scanning engine memory for entity: " .. target_civ)
local file = io.open(dfhack.getDFPath() .. "/refinish_dump_" .. target_civ .. ".txt", "w")

local found = false
for _, ent in ipairs(df.global.world.raws.entities.all) do
    if ent.code == target_civ then
        found = true
        file:write("ENTITY CODE: " .. ent.code .. "\n")
        file:write("==================================================\n")
        file:write("EXPLICIT PERMITTED REACTIONS (Parsed by Engine):\n")
        file:write("==================================================\n")
        
        if ent.workshops and ent.workshops.permitted_reaction_id then
            local rxn_list = ent.workshops.permitted_reaction_id
            for _, rxn_id in ipairs(rxn_list) do
                local rxn = df.global.world.raws.reactions.reactions[rxn_id]
                if rxn then
                    file:write(" - " .. rxn.code .. "\n")
                else
                    file:write(" - [UNKNOWN REACTION ID: " .. tostring(rxn_id) .. "]\n")
                end
            end
            file:write("\nTOTAL REACTIONS: " .. tostring(#rxn_list) .. "\n")
        else
            file:write("No permitted reactions found.\n")
        end
        break
    end
end

if not found then
    file:write("Entity code '" .. target_civ .. "' not found in raws.")
end

file:close()
print("Dump complete. Check refinish_dump_" .. target_civ .. ".txt in your main DF folder.")