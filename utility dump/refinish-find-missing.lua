--@ module = true
-- refinish-find-missing.lua
local target_civ = "MOUNTAIN"

print("==================================================")
print("HUNTING MISSING METALS FOR: " .. target_civ)
print("==================================================")

local civ = nil
for _, ent in ipairs(df.global.world.raws.entities.all) do
    if ent.code == target_civ then civ = ent; break end
end

if not civ then
    print("Could not find entity " .. target_civ)
    return
end

local permitted = {}
if civ.workshops and civ.workshops.permitted_reaction_id then
    for _, pid in ipairs(civ.workshops.permitted_reaction_id) do
        permitted[pid] = true
    end
end

local inorgs = df.global.world.raws.inorganics.all
local missing_count = 0

for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    -- If they don't have explicit permission AND it's not globally enabled
    if not permitted[rxn.index] and not (rxn.flags and rxn.flags.FORTRESS_MODE_ENABLED) then
        
        -- Ignore our own mod's reactions
        if not string.find(rxn.code, "REFINISH_STEEL_") then
            local makes_bar = false
            local out_metal = "UNKNOWN"
            
            -- Check parsed products
            if rxn.products then
                for _, prod in ipairs(rxn.products) do
                    if df.reaction_product_itemst:is_instance(prod) and prod.item_type == df.item_type.BAR then
                        makes_bar = true
                        if prod.mat_type == 0 and prod.mat_index >= 0 and prod.mat_index < #inorgs then
                            out_metal = inorgs[prod.mat_index].id
                        end
                    end
                end
            end
            
            -- Check raw strings as a fallback
            if not makes_bar and rxn.raw_strings then
                for _, str_ptr in ipairs(rxn.raw_strings) do
                    local val = str_ptr and str_ptr.value or ""
                    local match = string.match(val, "PRODUCT:.-:BAR:.-:INORGANIC:([^%]]+)")
                    if not match then match = string.match(val, "PRODUCT:.-:BAR:.-:METAL:([^%]]+)") end
                    
                    if match then
                        makes_bar = true
                        out_metal = match
                    end
                end
            end
            
            if makes_bar then
                missing_count = missing_count + 1
                print(string.format("[MISSING] Metal: %-15s | Reaction: %s", out_metal, rxn.code))
            end
        end
    end
end

print("--------------------------------------------------")
if missing_count == 0 then
    print("No missing bar-producing reactions found. If a metal is missing, it might not be produced as a BAR.")
else
    print("Total blind spots found: " .. missing_count)
end
print("==================================================")