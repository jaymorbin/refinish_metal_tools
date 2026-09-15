-- refinish-probe-tech.lua
local player_civ = df.historical_entity.find(df.global.plotinfo.civ_id)
if not player_civ or not player_civ.entity_raw then
    print("Probe Error: Could not locate player civilization.")
    return
end

local inorganics = df.global.world.raws.inorganics.all
local reactions = df.global.world.raws.reactions.reactions
local tech_map = {}

print("==================================================")
print("PROBING CIVILIZATION: " .. player_civ.entity_raw.code)
print("==================================================")

-- VECTOR 1: NATIVE METALS ARRAY
if player_civ.resources and player_civ.resources.metals then
    for _, mat_idx in ipairs(player_civ.resources.metals) do
        local mat = inorganics[mat_idx]
        if mat and mat.material.flags.IS_METAL then
            tech_map[mat.id] = (tech_map[mat.id] or "") .. "[Native Metal] "
        end
    end
end

-- VECTOR 2: NATIVE MINERALS (ORES) ARRAY
if player_civ.resources and player_civ.resources.minerals then
    for _, min_idx in ipairs(player_civ.resources.minerals) do
        local mineral = inorganics[min_idx]
        if mineral and mineral.metal_ore then
            for _, ore_def in ipairs(mineral.metal_ore.mat_index) do
                local ore_metal = inorganics[ore_def]
                if ore_metal and ore_metal.material.flags.IS_METAL then
                    tech_map[ore_metal.id] = (tech_map[ore_metal.id] or "") .. "[Ore: " .. mineral.id .. "] "
                end
            end
        end
    end
end

-- VECTOR 3: PERMITTED REACTIONS (PRODUCTS)
local permitted_rxns = player_civ.entity_raw.workshops.permitted_reaction_id
for _, pid in ipairs(permitted_rxns) do
    local rxn = reactions[pid]
    if rxn then
        for _, prod in ipairs(rxn.products) do
            if df.reaction_product_itemst:is_instance(prod) and prod.item_type == df.item_type.BAR then
                if prod.mat_type == 0 then
                    local prod_mat = inorganics[prod.mat_index]
                    if prod_mat and prod_mat.material.flags.IS_METAL then
                        tech_map[prod_mat.id] = (tech_map[prod_mat.id] or "") .. "[Reaction: " .. rxn.code .. "] "
                    end
                elseif prod.mat_type ~= 0 then
                    print(string.format("  -> NOTE: Reaction %s outputs a BAR with non-zero mat_type: %d", rxn.code, prod.mat_type))
                end
            end
        end
    end
end

print("METALLURGICAL CAPABILITIES FOUND:")
local count = 0
for metal_id, sources in pairs(tech_map) do
    print(string.format(" - %s: %s", metal_id, sources))
    count = count + 1
end
print("--------------------------------------------------")
print(string.format("Total distinct metals detected: %d", count))
print("==================================================")