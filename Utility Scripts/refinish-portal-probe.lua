--@ module = false
-- refinish-portal-probe.lua

local reactions_array = df.global.world.raws.reactions.reactions
local steel_making_rxn = nil

for _, rxn in ipairs(reactions_array) do
    if rxn.code == "STEEL_MAKING" then 
        steel_making_rxn = rxn 
        break 
    end
end

if not steel_making_rxn then
    print("PROBE FAILED: Missing STEEL_MAKING template.")
    return
end

local template_rxn = df.reaction:new()
template_rxn.code = "REFINISH_STEEL_RXN_TEST_PORTAL_V15"
template_rxn.name = "[TEST] Pure Powder Portal"
template_rxn.category = "" 

-- Port the Smelter requirement
for i, v in ipairs(steel_making_rxn.building.type) do
    template_rxn.building.type:insert('#', v)
    template_rxn.building.subtype:insert('#', steel_making_rxn.building.subtype[i])
    template_rxn.building.custom:insert('#', steel_making_rxn.building.custom[i])
end

-- 1. Reagent 0: The Powder (Built cleanly to avoid inherited boulder flags)
local r_dust = df.reaction_reagent_itemst:new()
r_dust.code = "dust"
r_dust.item_type = df.item_type.POWDER_MISC 
r_dust.mat_type = -1 
r_dust.mat_index = -1 
r_dust.quantity = 150 
r_dust.min_dimension = -1 
template_rxn.reagents:insert('#', r_dust)

-- 2. Reagent 1: The Bag (Analogue deep copy from STEEL_MAKING's flux bag)
local r_bag = df.reaction_reagent_itemst:new()
r_bag:assign(steel_making_rxn.reagents[4]) 
r_bag.code = "dust_bag"
r_bag.contains:resize(0)
r_bag.contains:insert('#', 0) -- Point this bag strictly at our Reagent 0 (the dust)
template_rxn.reagents:insert('#', r_bag)

-- 3. Products: Dummy 0-count
local p_dust = df.reaction_product_itemst:new()
p_dust.item_type = df.item_type.POWDER_MISC
p_dust.mat_type = -1
p_dust.mat_index = -1
p_dust.count = 0 
p_dust.product_dimension = 150 
p_dust.flags.GET_MATERIAL_SAME = true
p_dust.get_material.reagent_code = "dust"
template_rxn.products:insert('#', p_dust)

-- 4. Injection
template_rxn.index = #reactions_array
reactions_array:insert('#', template_rxn)

local player_civ = df.historical_entity.find(df.global.plotinfo.civ_id)
if player_civ and player_civ.entity_raw then
    local permitted = player_civ.entity_raw.workshops.permitted_reaction_id
    permitted:insert('#', template_rxn.index)
    print("PROBE SUCCESS: Injected V15 Pure Portal. Check root Smelter menu.")
else
    print("PROBE FAILED: Could not find player civ.")
end