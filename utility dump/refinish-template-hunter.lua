-- refinish-test-hunter.lua
-- Standalone Drop Script: Tests dynamic template acquisition and synthesis

print("==================================================")
print("TESTING HUNTER-SEEKER PROTOCOL")
print("==================================================")

local reactions_array = df.global.world.raws.reactions.reactions
local t_bar_r, t_powder_r, t_bag_r, t_bar_p

-- 1. THE HUNTER
for _, rxn in ipairs(reactions_array) do
    if not string.find(rxn.code, "REFINISH_STEEL_") then
        for _, r in ipairs(rxn.reagents) do
            if not t_bar_r and r.item_type == df.item_type.BAR then
                t_bar_r = r
            elseif not t_powder_r and r.item_type == 70 and r.flags.IN_CONTAINER then
                t_powder_r = r
            elseif not t_bag_r and r.item_type == 31 and r.flags.PRESERVE_REAGENT then
                t_bag_r = r
            end
        end
        for _, p in ipairs(rxn.products) do
            if not t_bar_p and p.item_type == df.item_type.BAR then
                t_bar_p = p
            end
        end
    end
    if t_bar_r and t_powder_r and t_bag_r and t_bar_p then break end
end

-- Verify Acquisition
if not (t_bar_r and t_powder_r and t_bag_r and t_bar_p) then
    print("FAILED TO ACQUIRE ALL TEMPLATES:")
    print("  Bar Reagent: " .. tostring(t_bar_r ~= nil))
    print("  Powder Reagent: " .. tostring(t_powder_r ~= nil))
    print("  Bag Reagent: " .. tostring(t_bag_r ~= nil))
    print("  Bar Product: " .. tostring(t_bar_p ~= nil))
    return
end

print("SUCCESS: All genetic templates acquired natively.")
print("Synthesizing Virtual Template...")

-- 2. THE SYNTHESIS
local template_rxn = df.reaction:new()
template_rxn.code = "VIRTUAL_REFINISH_TEMPLATE"
template_rxn.name = "virtual refinish template"

-- Reagent 0: Input Bar (Forced to Qty 450)
local r_steel = df.reaction_reagent_itemst:new()
r_steel:assign(t_bar_r) 
r_steel.code = "steel_bar"
r_steel.quantity = 450 
r_steel.min_dimension = -1 
r_steel.mat_type = 0
r_steel.mat_index = 0 -- (Just using 0 for the test printout)
r_steel.reaction_class = ""
template_rxn.reagents:insert('#', r_steel)

-- Reagent 1: Dust (Forced to Qty 150)
local r_dust = df.reaction_reagent_itemst:new()
r_dust:assign(t_powder_r) 
r_dust.code = "dust"
r_dust.quantity = 150 
r_dust.min_dimension = -1 
r_dust.mat_type = 0
r_dust.mat_index = -1 
r_dust.reaction_class = ""
template_rxn.reagents:insert('#', r_dust)

-- Reagent 2: Bag (Contains Reagent 1, Empty = False)
local r_bag = df.reaction_reagent_itemst:new()
r_bag:assign(t_bag_r) 
r_bag.code = "dust_bag"
r_bag.flags1.empty = false
r_bag.contains:resize(0)
r_bag.contains:insert('#', 1) 
template_rxn.reagents:insert('#', r_bag)

-- Product 0: Output Bar (Forced to Count 3, Dim 150)
local p_bar = df.reaction_product_itemst:new()
p_bar:assign(t_bar_p)
p_bar.count = 3 
p_bar.product_dimension = 150 
p_bar.mat_type = 0
p_bar.mat_index = -1 
template_rxn.products:insert('#', p_bar)

-- 3. THE FORENSIC DUMP
print("==================================================")
print("VIRTUAL TEMPLATE FORENSICS")
print("--------------------------------------------------")

for i, r in ipairs(template_rxn.reagents) do
    local type_name = df.item_type[r.item_type] or "UNKNOWN"
    print(string.format("  REAGENT [%d] - Code: %s", i - 1, tostring(r.code)))
    print(string.format("    Item Type: %s (%d)", type_name, r.item_type))
    print(string.format("    Qty: %d | Min Dimension: %d", r.quantity, r.min_dimension))
    
    if r.contains and #r.contains > 0 then
        local c_str = ""
        for _, c_idx in ipairs(r.contains) do c_str = c_str .. tostring(c_idx) .. " " end
        print(string.format("    Contains Links To Reagent(s): [%s]", c_str))
    end
    
    local flags_str = ""
    for k, v in pairs(r.flags) do if v then flags_str = flags_str .. tostring(k) .. " " end end
    if flags_str ~= "" then print(string.format("    Flags: %s", flags_str)) end
    
    local flags1_str = ""
    for k, v in pairs(r.flags1) do if v then flags1_str = flags1_str .. tostring(k) .. " " end end
    if flags1_str ~= "" then print(string.format("    Flags1: %s", flags1_str)) end
end

print("- - - - - - - - - - - - - - - - - - - - - - - - - ")
for i, p in ipairs(template_rxn.products) do
    local type_name = df.item_type[p.item_type] or "UNKNOWN"
    print(string.format("  PRODUCT [%d]", i - 1))
    print(string.format("    Item Type: %s (%d)", type_name, p.item_type))
    print(string.format("    Count: %d | Product Dimension: %d", p.count, p.product_dimension))
end
print("==================================================")

-- Clean up isolated memory
template_rxn:delete()