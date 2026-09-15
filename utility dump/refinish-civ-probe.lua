--@ module = true
-- refinish-probe-civs.lua
-- Read-only diagnostic tool to dump live civ resource and permission data.

local debug_file = io.open(dfhack.getDFPath() .. "/refinish_probe_civs.txt", "w")
if not debug_file then
    print("Failed to open debug file.")
    return
end

local function dprint(msg)
    debug_file:write(msg .. "\n")
end

dprint("==================================================")
dprint("REFINISH STEEL: CIVILIZATION RAM PROBE")
dprint("==================================================")

local inorganics = df.global.world.raws.inorganics.all
local reactions = df.global.world.raws.reactions.reactions

for civ_idx, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        dprint(string.format("\n--- CIV ID: %d | CLASS: %s ---", civ.id, civ.entity_raw.code))
        
        -- 1. Check Local Instance Resources (What this specific civ spawned with)
        dprint("LOCAL RESOURCES (civ.resources.metals):")
        if civ.resources and civ.resources.metals then
            local metal_count = 0
            for _, mat_idx in ipairs(civ.resources.metals) do
                if mat_idx >= 0 and mat_idx < #inorganics then
                    dprint("  - " .. inorganics[mat_idx].id)
                    metal_count = metal_count + 1
                end
            end
            if metal_count == 0 then dprint("  (Empty)") end
        else
            dprint("  (No resources table)")
        end

        -- 2. Check Global Class Permissions (What the entire race shares)
        dprint("GLOBAL PERMISSIONS (civ.entity_raw.workshops.permitted_reaction_id):")
        local permitted = civ.entity_raw.workshops.permitted_reaction_id
        local rxn_count = 0
        for _, pid in ipairs(permitted) do
            if pid >= 0 and pid < #reactions then
                local rxn = reactions[pid]
                if string.find(rxn.code, "REFINISH_STEEL_") or string.find(rxn.code, "MAKING") or rxn.code == "IRON_BLOOM_PROCESS" then
                    dprint("  - " .. rxn.code)
                    rxn_count = rxn_count + 1
                end
            end
        end
        if rxn_count == 0 then dprint("  (No relevant reactions found)") end
    end
end

debug_file:close()
print("Probe complete. Check refinish_probe_civs.txt in your main DF folder.")