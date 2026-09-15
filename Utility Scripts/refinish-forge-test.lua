-- refinish-forge-test.lua
-- Prototype 4: Reaction and Entity Injection (v50 Plotinfo Fix)

print("==================================================")
print("REFINISH STEEL: INITIATING FORGE UI INJECTION")
print("==================================================")

local utils = require('utils')

-- 1. FIND THE TARGET MATERIAL INDEX
local target_mat_index = -1
for i, mat in ipairs(df.global.world.raws.inorganics.all) do
    if mat.id == "REFINISHED_STEEL_SCARLET_V40_TEST" then
        target_mat_index = i
        break
    end
end

if target_mat_index == -1 then
    print("ERROR: Scarlet Steel not found. Run refinish-inject-test first.")
    return
end

-- 2. FIND A TEMPLATE REACTION
local template_reaction = nil
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    if rxn.code == "RED_COLOUR_STEEL_REFINISH" then
        template_reaction = rxn
        break
    end
end

if not template_reaction then
    print("ERROR: Template reaction not found. Ensure RED_COLOUR_STEEL_REFINISH is loaded.")
    return
end

-- 3. CLONE AND MUTATE THE REACTION
local clone_rxn = df.reaction:new()
utils.assign(clone_rxn, template_reaction)

local new_rxn_code = "REFINISH_STEEL_SCARLET_V40_TEST_RXN"
clone_rxn.code = new_rxn_code
clone_rxn.name = "make scarlet steel (test)"

-- Rewire the product to point to our injected material index
if clone_rxn.products and #clone_rxn.products > 0 then
    for _, prod in ipairs(clone_rxn.products) do
        if prod.item_type == df.item_type.BAR then
            prod.mat_type = 0 -- 0 is Inorganic
            prod.mat_index = target_mat_index
        end
    end
end

-- Inject the cloned reaction into the global list
local reactions_array = df.global.world.raws.reactions.reactions
reactions_array:insert('#', clone_rxn)

-- Give the new reaction its proper ID (its exact position in the array)
local new_rxn_index = #reactions_array - 1
clone_rxn.index = new_rxn_index

print("Reaction Injected: " .. new_rxn_code .. " at Index " .. new_rxn_index)

-- 4. ENTITY INJECTION (The UI Unlock)
-- FIXED: Using plotinfo instead of ui for v50 compatibility
local player_civ = df.historical_entity.find(df.global.plotinfo.civ_id)

if player_civ and player_civ.entity_raw then
    local ok, err = pcall(function()
        -- Inject the integer ID directly into the civilization's permitted workshop list
        player_civ.entity_raw.workshops.permitted_reaction_id:insert('#', new_rxn_index)
    end)
    
    if ok then
        print("Entity Updated: Permitted reaction added to player civilization.")
    else
        print("Entity Update Failed: " .. tostring(err))
    end
else
    print("ERROR: Could not find player civilization raw data.")
end

print("--------------------------------------------------")
print("SUCCESS: Forge UI sequence complete.")
print("==================================================")