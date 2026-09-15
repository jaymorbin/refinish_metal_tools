-- refinish-probe-missing-reactions.lua

local args = {...}
local target_id = args[1]

if not target_id then
    print("Error: Please provide a metal ID to search for.")
    print("Usage: refinish-probe-missing-reactions <METAL_ID> (e.g., refinish-probe-missing-reactions THORIUM)")
    return
end

target_id = string.upper(target_id)
print("\n==========================================")
print("REFINISH STEEL: MISSING METAL PROBE")
print("Searching for any reaction producing: " .. target_id)
print("==========================================\n")

local rxns = df.global.world.raws.reactions.reactions
local inorgs = df.global.world.raws.inorganics.all
local found_count = 0

for i, rxn in ipairs(rxns) do
    local is_match = false
    
    -- 1. Check strict product indices safely
    if rxn.products then
        for _, prod in ipairs(rxn.products) do
            -- SAFEGUARD: Prevent crash on item_improvementst subclasses
            if df.reaction_product_itemst:is_instance(prod) then
                if prod.item_type == 0 and prod.mat_type == 0 and prod.mat_index >= 0 and prod.mat_index < #inorgs then
                    if inorgs[prod.mat_index].id == target_id then
                        is_match = true
                        break
                    end
                end
            end
        end
    end
    
    -- 2. Check raw strings for dynamic targets (like GET_MATERIAL_PRODUCT)
    if not is_match and rxn.raw_strings then
        for _, raw_str_obj in ipairs(rxn.raw_strings) do
            if raw_str_obj.value and string.find(raw_str_obj.value, target_id) then
                is_match = true
                break
            end
        end
    end

    if is_match then
        found_count = found_count + 1
        print("FOUND MATCH IN REACTION: " .. rxn.code)
        print("  Index: " .. i)
        print("  Skill ID: " .. tostring(rxn.skill))
        
        if rxn.building and rxn.building.type then
            local b_types = {}
            for _, t in ipairs(rxn.building.type) do table.insert(b_types, tostring(t)) end
            print("  Building Types: " .. table.concat(b_types, ", "))
        else
            print("  Building Types: NONE")
        end
        print("------------------------------------------")
    end
end

if found_count == 0 then
    print("RESULT: No reactions found in the game that produce " .. target_id)
    print("The mod author likely defined the material but provided no way to craft it.")
end
print("\n==========================================")