-- refinish-probe.lua
local out = {}
table.insert(out, "=== REFINISH STEEL DIAGNOSTIC PROBE ===")

-- 1. Check if the categories physically exist in RAM
local categories_found = 0
for _, cat in ipairs(df.global.world.raws.reactions.reaction_categories) do
    if string.find(cat.id, "REFINISH_STEEL_CAT_BASE_") then
        categories_found = categories_found + 1
    end
end
table.insert(out, "1. Injected Categories found in RAM: " .. categories_found)

-- 2. Check the cultural UI bypass flags on our injected reactions
local civ = df.historical_entity.find(df.global.plotinfo.civ_id)
local permitted_rs_reactions = 0
local fm_flagged = 0

for _, pid in ipairs(civ.entity_raw.workshops.permitted_reaction_id) do
    local rxn = df.global.world.raws.reactions.reactions[pid]
    if rxn and string.find(rxn.code, "REFINISH_STEEL_RXN_") then
        permitted_rs_reactions = permitted_rs_reactions + 1
        -- Check if the reaction has the flag required to bypass the cultural filter
        if rxn.flags.FORTRESS_MODE_ENABLED then
            fm_flagged = fm_flagged + 1
        end
    end
end
table.insert(out, "2. Refinish Reactions permitted to Civ: " .. permitted_rs_reactions)
table.insert(out, "3. Permitted Reactions with UI Bypass Flag: " .. fm_flagged)

for _, line in ipairs(out) do
    print(line)
end