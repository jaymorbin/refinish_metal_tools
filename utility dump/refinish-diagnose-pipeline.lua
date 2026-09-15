-- refinish-diagnose-pipeline.lua
local out = {}
table.insert(out, "=== REFINISH STEEL PIPELINE DIAGNOSTIC ===")

table.insert(out, "\n1. THE BOOT CACHE (_G.refinish_known_metals_cache):")
if _G.refinish_known_metals_cache then
    if _G.refinish_known_metals_cache["PURPLE_GOLD"] then
        table.insert(out, "   -> [PASS] PURPLE_GOLD is successfully registered in the known metals cache.")
    else
        table.insert(out, "   -> [FAIL] PURPLE_GOLD is MISSING from the boot cache. (The refinish-boot fix did not execute or failed).")
    end
else
    table.insert(out, "   -> [FAIL] Boot cache does not exist in memory.")
end

table.insert(out, "\n2. THE BLUEPRINT (_G.refinish_blueprint):")
if _G.refinish_blueprint and _G.refinish_blueprint.categories then
    if _G.refinish_blueprint.categories["REFINISH_STEEL_CAT_BASE_PURPLE_GOLD"] then
        table.insert(out, "   -> [PASS] PURPLE_GOLD categories successfully generated in the blueprint.")
    else
        table.insert(out, "   -> [FAIL] PURPLE_GOLD categories are MISSING from the blueprint.")
    end
else
     table.insert(out, "   -> [FAIL] Blueprint does not exist in memory.")
end

table.insert(out, "\n3. THE ENTITY INDEXER (Player Civ Permissions):")
local civ = df.historical_entity.find(df.global.plotinfo.civ_id)
if civ and civ.entity_raw then
    local found_reaction = false
    for _, pid in ipairs(civ.entity_raw.workshops.permitted_reaction_id) do
        local rxn = df.global.world.raws.reactions.reactions[pid]
        if rxn and string.find(rxn.code, "REFINISH_STEEL_RXN_.*PURPLE_GOLD") then
            found_reaction = true
            break
        end
    end
    if found_reaction then
        table.insert(out, "   -> [PASS] PURPLE_GOLD finishes are explicitly permitted to the player UI.")
    else
        table.insert(out, "   -> [FAIL] PURPLE_GOLD finishes are NOT permitted. The indexer blocked them.")
    end
end

for _, line in ipairs(out) do print(line) end