-- refinish-workshop-probe.lua
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    if rxn.code == "STEEL_MAKING" then
        print("STEEL_MAKING WORKSHOP LINKS:")
        for i=0, #rxn.building.type-1 do
            print(string.format("  Link %d - Type: %d | Subtype: %d", i+1, rxn.building.type[i], rxn.building.subtype[i]))
        end
        break
    end
end