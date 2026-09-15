-- refinish-read-reaction.lua
-- Hardcoded analysis tool using strictly mapped DFHack paths, protected against C++ binding crashes, outputting full paths.

local args = {...}
local target_code = args[1]

if not target_code then
    qerror("Usage: refinish-reaction-analysis <REACTION_CODE>")
end

local reaction = nil
for _, r in ipairs(df.global.world.raws.reactions.reactions) do
    if r.code == target_code then
        reaction = r
        break
    end
end

if not reaction then
    qerror("Reaction not found: " .. target_code)
end

local timestamp = os.date("%Y%m%d_%H%M%S")
local filename = string.format("%s_%d_%s.txt", reaction.code, reaction.index, timestamp)
local file = io.open(filename, "w")

if not file then
    qerror("Failed to open file for writing: " .. filename)
end

local function w(indent, str) 
    file:write(string.rep("\t", indent) .. str .. "\n") 
end

local function s(func)
    local ok, val = pcall(func)
    return (ok and val ~= nil) and tostring(val) or "UNBOUND_OR_NIL"
end

local function safe_iterate(indent, full_path, func)
    local ok, vec = pcall(func)
    if ok and (type(vec) == "userdata" or type(vec) == "table") then
        local count = 0
        for i, v in ipairs(vec) do
            local str_val = "UNREADABLE"
            if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
                str_val = tostring(v)
            else
                local ok_val, val = pcall(function() return v.value end)
                if ok_val and val ~= nil then
                    str_val = tostring(val)
                else
                    str_val = tostring(v)
                end
            end
            w(indent, full_path .. "[" .. (i-1) .. "] = " .. str_val)
            count = count + 1
        end
        if count == 0 then w(indent, full_path .. " = EMPTY") end
    else
        w(indent, full_path .. " = UNBOUND_OR_NIL")
    end
end

local bp = "df.global.world.raws.reactions.reactions[" .. reaction.index .. "]"

w(0, "=== REACTION ANALYSIS DUMP ===")
w(0, bp .. ".code = " .. s(function() return reaction.code end))
w(0, bp .. ".name = " .. s(function() return reaction.name end))
w(0, bp .. ".skill = " .. s(function() return reaction.skill end))
w(0, bp .. ".max_multiplier = " .. s(function() return reaction.max_multiplier end))
w(0, bp .. ".index = " .. s(function() return reaction.index end))
w(0, bp .. ".source_hfid = " .. s(function() return reaction.source_hfid end))
w(0, bp .. ".source_efid = " .. s(function() return reaction.source_efid end))
w(0, bp .. ".category = " .. s(function() return reaction.category end))
w(0, bp .. ".rand_range = " .. s(function() return reaction.rand_range end))
w(0, bp .. ".skill_mult = " .. s(function() return reaction.skill_mult end))
w(0, bp .. ".attr_gain = " .. s(function() return reaction.attr_gain end))
w(0, bp .. ".exp_gain = " .. s(function() return reaction.exp_gain end))
w(0, "")

w(0, "=== REACTION FLAGS ===")
w(1, bp .. ".flags.FUEL = " .. s(function() return reaction.flags.FUEL end))
w(1, bp .. ".flags.AUTOMATIC = " .. s(function() return reaction.flags.AUTOMATIC end))
w(1, bp .. ".flags.ADVENTURE_MODE_ENABLED = " .. s(function() return reaction.flags.ADVENTURE_MODE_ENABLED end))
w(1, bp .. ".flags.GENERATED = " .. s(function() return reaction.flags.GENERATED end))
w(1, bp .. ".flags.FORTRESS_MODE_ENABLED = " .. s(function() return reaction.flags.FORTRESS_MODE_ENABLED end))
w(1, bp .. ".flags.WORLDGEN_ENABLED = " .. s(function() return reaction.flags.WORLDGEN_ENABLED end))
w(0, "")

w(0, "=== REAGENTS ===")
local ok_reagents, reagents = pcall(function() return reaction.reagents end)
if ok_reagents and reagents then
    for i, reagent in ipairs(reagents) do
        local rp = bp .. ".reagents[" .. (i-1) .. "]"
        w(1, "Reagent [" .. (i-1) .. "]")
        w(2, rp .. ".code = " .. s(function() return reagent.code end))
        w(2, rp .. ".quantity = " .. s(function() return reagent.quantity end))
        w(2, rp .. ".item_type = " .. s(function() return reagent.item_type end))
        w(2, rp .. ".item_subtype = " .. s(function() return reagent.item_subtype end))
        w(2, rp .. ".mat_type = " .. s(function() return reagent.mat_type end))
        w(2, rp .. ".mat_index = " .. s(function() return reagent.mat_index end))
        w(2, rp .. ".reaction_class = " .. s(function() return reagent.reaction_class end))
        w(2, rp .. ".has_material_reaction_product = " .. s(function() return reagent.has_material_reaction_product end))
        w(2, rp .. ".flags4 = " .. s(function() return reagent.flags4 end))
        w(2, rp .. ".flags5 = " .. s(function() return reagent.flags5 end))
        w(2, rp .. ".metal_ore = " .. s(function() return reagent.metal_ore end))
        w(2, rp .. ".min_dimension = " .. s(function() return reagent.min_dimension end))
        w(2, rp .. ".has_tool_use = " .. s(function() return reagent.has_tool_use end))
        w(2, rp .. ".dye_color = " .. s(function() return reagent.dye_color end))
        
        w(2, "-- Base Flags --")
        w(3, rp .. ".flags.PRESERVE_REAGENT = " .. s(function() return reagent.flags.PRESERVE_REAGENT end))
        w(3, rp .. ".flags.IN_CONTAINER = " .. s(function() return reagent.flags.IN_CONTAINER end))
        w(3, rp .. ".flags.DOES_NOT_DETERMINE_PRODUCT_AMOUNT = " .. s(function() return reagent.flags.DOES_NOT_DETERMINE_PRODUCT_AMOUNT end))

        w(2, "-- Flags1 --")
        w(3, rp .. ".flags1.improvable = " .. s(function() return reagent.flags1.improvable end))
        w(3, rp .. ".flags1.butcherable = " .. s(function() return reagent.flags1.butcherable end))
        w(3, rp .. ".flags1.millable = " .. s(function() return reagent.flags1.millable end))
        w(3, rp .. ".flags1.allow_buryable = " .. s(function() return reagent.flags1.allow_buryable end))
        w(3, rp .. ".flags1.unrotten = " .. s(function() return reagent.flags1.unrotten end))
        w(3, rp .. ".flags1.undisturbed = " .. s(function() return reagent.flags1.undisturbed end))
        w(3, rp .. ".flags1.collected = " .. s(function() return reagent.flags1.collected end))
        w(3, rp .. ".flags1.sharpenable = " .. s(function() return reagent.flags1.sharpenable end))
        w(3, rp .. ".flags1.murdered = " .. s(function() return reagent.flags1.murdered end))
        w(3, rp .. ".flags1.UNUSED_1_10 = " .. s(function() return reagent.flags1.UNUSED_1_10 end))
        w(3, rp .. ".flags1.empty = " .. s(function() return reagent.flags1.empty end))
        w(3, rp .. ".flags1.processable = " .. s(function() return reagent.flags1.processable end))
        w(3, rp .. ".flags1.UNUSED_1_13 = " .. s(function() return reagent.flags1.UNUSED_1_13 end))
        w(3, rp .. ".flags1.cookable = " .. s(function() return reagent.flags1.cookable end))
        w(3, rp .. ".flags1.extract_bearing_plant = " .. s(function() return reagent.flags1.extract_bearing_plant end))
        w(3, rp .. ".flags1.extract_bearing_fish = " .. s(function() return reagent.flags1.extract_bearing_fish end))
        w(3, rp .. ".flags1.extract_bearing_vermin = " .. s(function() return reagent.flags1.extract_bearing_vermin end))
        w(3, rp .. ".flags1.processable_to_vial = " .. s(function() return reagent.flags1.processable_to_vial end))
        w(3, rp .. ".flags1.UNUSED_1_19 = " .. s(function() return reagent.flags1.UNUSED_1_19 end))
        w(3, rp .. ".flags1.processable_to_barrel = " .. s(function() return reagent.flags1.processable_to_barrel end))
        w(3, rp .. ".flags1.solid = " .. s(function() return reagent.flags1.solid end))
        w(3, rp .. ".flags1.tameable_vermin = " .. s(function() return reagent.flags1.tameable_vermin end))
        w(3, rp .. ".flags1.nearby = " .. s(function() return reagent.flags1.nearby end))
        w(3, rp .. ".flags1.sand_bearing = " .. s(function() return reagent.flags1.sand_bearing end))
        w(3, rp .. ".flags1.glass = " .. s(function() return reagent.flags1.glass end))
        w(3, rp .. ".flags1.milk = " .. s(function() return reagent.flags1.milk end))
        w(3, rp .. ".flags1.milkable = " .. s(function() return reagent.flags1.milkable end))
        w(3, rp .. ".flags1.finished_goods = " .. s(function() return reagent.flags1.finished_goods end))
        w(3, rp .. ".flags1.ammo = " .. s(function() return reagent.flags1.ammo end))
        w(3, rp .. ".flags1.furniture = " .. s(function() return reagent.flags1.furniture end))
        w(3, rp .. ".flags1.not_bin = " .. s(function() return reagent.flags1.not_bin end))
        w(3, rp .. ".flags1.lye_bearing = " .. s(function() return reagent.flags1.lye_bearing end))

        w(2, "-- Flags2 --")
        w(3, rp .. ".flags2.dye = " .. s(function() return reagent.flags2.dye end))
        w(3, rp .. ".flags2.dyeable = " .. s(function() return reagent.flags2.dyeable end))
        w(3, rp .. ".flags2.dyed = " .. s(function() return reagent.flags2.dyed end))
        w(3, rp .. ".flags2.sewn_imageless = " .. s(function() return reagent.flags2.sewn_imageless end))
        w(3, rp .. ".flags2.glass_making = " .. s(function() return reagent.flags2.glass_making end))
        w(3, rp .. ".flags2.screw = " .. s(function() return reagent.flags2.screw end))
        w(3, rp .. ".flags2.building_material = " .. s(function() return reagent.flags2.building_material end))
        w(3, rp .. ".flags2.fire_safe = " .. s(function() return reagent.flags2.fire_safe end))
        w(3, rp .. ".flags2.magma_safe = " .. s(function() return reagent.flags2.magma_safe end))
        w(3, rp .. ".flags2.deep_material = " .. s(function() return reagent.flags2.deep_material end))
        w(3, rp .. ".flags2.melt_designated = " .. s(function() return reagent.flags2.melt_designated end))
        w(3, rp .. ".flags2.non_economic = " .. s(function() return reagent.flags2.non_economic end))
        w(3, rp .. ".flags2.allow_melt_dump = " .. s(function() return reagent.flags2.allow_melt_dump end))
        w(3, rp .. ".flags2.allow_artifact = " .. s(function() return reagent.flags2.allow_artifact end))
        w(3, rp .. ".flags2.plant = " .. s(function() return reagent.flags2.plant end))
        w(3, rp .. ".flags2.silk = " .. s(function() return reagent.flags2.silk end))
        w(3, rp .. ".flags2.leather = " .. s(function() return reagent.flags2.leather end))
        w(3, rp .. ".flags2.bone = " .. s(function() return reagent.flags2.bone end))
        w(3, rp .. ".flags2.shell = " .. s(function() return reagent.flags2.shell end))
        w(3, rp .. ".flags2.totemable = " .. s(function() return reagent.flags2.totemable end))
        w(3, rp .. ".flags2.horn = " .. s(function() return reagent.flags2.horn end))
        w(3, rp .. ".flags2.pearl = " .. s(function() return reagent.flags2.pearl end))
        w(3, rp .. ".flags2.plaster_containing = " .. s(function() return reagent.flags2.plaster_containing end))
        w(3, rp .. ".flags2.UNUSED_24 = " .. s(function() return reagent.flags2.UNUSED_24 end))
        w(3, rp .. ".flags2.soap = " .. s(function() return reagent.flags2.soap end))
        w(3, rp .. ".flags2.body_part = " .. s(function() return reagent.flags2.body_part end))
        w(3, rp .. ".flags2.ivory_tooth = " .. s(function() return reagent.flags2.ivory_tooth end))
        w(3, rp .. ".flags2.lye_milk_free = " .. s(function() return reagent.flags2.lye_milk_free end))
        w(3, rp .. ".flags2.blunt = " .. s(function() return reagent.flags2.blunt end))
        w(3, rp .. ".flags2.unengraved = " .. s(function() return reagent.flags2.unengraved end))
        w(3, rp .. ".flags2.hair_wool = " .. s(function() return reagent.flags2.hair_wool end))
        w(3, rp .. ".flags2.yarn = " .. s(function() return reagent.flags2.yarn end))

        w(2, "-- Flags3 --")
        w(3, rp .. ".flags3.unimproved = " .. s(function() return reagent.flags3.unimproved end))
        w(3, rp .. ".flags3.any_raw_material = " .. s(function() return reagent.flags3.any_raw_material end))
        w(3, rp .. ".flags3.non_absorbent = " .. s(function() return reagent.flags3.non_absorbent end))
        w(3, rp .. ".flags3.non_pressed = " .. s(function() return reagent.flags3.non_pressed end))
        w(3, rp .. ".flags3.allow_liquid_powder = " .. s(function() return reagent.flags3.allow_liquid_powder end))
        w(3, rp .. ".flags3.any_craft = " .. s(function() return reagent.flags3.any_craft end))
        w(3, rp .. ".flags3.hard = " .. s(function() return reagent.flags3.hard end))
        w(3, rp .. ".flags3.food_storage = " .. s(function() return reagent.flags3.food_storage end))
        w(3, rp .. ".flags3.metal = " .. s(function() return reagent.flags3.metal end))
        w(3, rp .. ".flags3.sand = " .. s(function() return reagent.flags3.sand end))
        w(3, rp .. ".flags3.can_use_location_reserved = " .. s(function() return reagent.flags3.can_use_location_reserved end))
        w(3, rp .. ".flags3.written_on = " .. s(function() return reagent.flags3.written_on end))
        w(3, rp .. ".flags3.edged = " .. s(function() return reagent.flags3.edged end))
        w(3, rp .. ".flags3.on_ground = " .. s(function() return reagent.flags3.on_ground end))
        w(3, rp .. ".flags3.divine = " .. s(function() return reagent.flags3.divine end))
        w(3, rp .. ".flags3.crafted_artifact = " .. s(function() return reagent.flags3.crafted_artifact end))
        w(3, rp .. ".flags3.wood = " .. s(function() return reagent.flags3.wood end))
        w(3, rp .. ".flags3.stone = " .. s(function() return reagent.flags3.stone end))
        w(3, rp .. ".flags3.non_artifact = " .. s(function() return reagent.flags3.non_artifact end))
        w(3, rp .. ".flags3.woven = " .. s(function() return reagent.flags3.woven end))
        w(3, rp .. ".flags3.gem = " .. s(function() return reagent.flags3.gem end))
        w(3, rp .. ".flags3.empty_or_water = " .. s(function() return reagent.flags3.empty_or_water end))
        w(3, rp .. ".flags3.grown_not_crafted = " .. s(function() return reagent.flags3.grown_not_crafted end))
        
        w(2, "-- Vectors and Strings --")
        safe_iterate(3, rp .. ".contains", function() return reagent.contains end)
        safe_iterate(3, rp .. ".item_str", function() return reagent.item_str end)
        safe_iterate(3, rp .. ".material_str", function() return reagent.material_str end)
        w(3, rp .. ".metal_ore_str = " .. s(function() return reagent.metal_ore_str end))
        safe_iterate(3, rp .. ".contains_str", function() return reagent.contains_str end)
    end
end
w(0, "")

w(0, "=== PRODUCTS ===")
local ok_products, products = pcall(function() return reaction.products end)
if ok_products and products then
    for i, product in ipairs(products) do
        local pp = bp .. ".products[" .. (i-1) .. "]"
        w(1, "Product [" .. (i-1) .. "]")
        w(2, pp .. ".product_token = " .. s(function() return product.product_token end))
        w(2, pp .. ".product_to_container = " .. s(function() return product.product_to_container end))
        w(2, pp .. ".item_type = " .. s(function() return product.item_type end))
        w(2, pp .. ".item.subtype = " .. s(function() return product.item.subtype end))
        w(2, pp .. ".mat_type = " .. s(function() return product.mat_type end))
        w(2, pp .. ".mat_index = " .. s(function() return product.mat_index end))
        w(2, pp .. ".probability = " .. s(function() return product.probability end))
        w(2, pp .. ".count = " .. s(function() return product.count end))
        w(2, pp .. ".product_dimension = " .. s(function() return product.product_dimension end))
        
        w(2, "-- Product Flags --")
        w(3, pp .. ".flags.GET_MATERIAL_SAME = " .. s(function() return product.flags.GET_MATERIAL_SAME end))
        w(3, pp .. ".flags.GET_MATERIAL_PRODUCT = " .. s(function() return product.flags.GET_MATERIAL_PRODUCT end))
        w(3, pp .. ".flags.FORCE_EDGE = " .. s(function() return product.flags.FORCE_EDGE end))
        w(3, pp .. ".flags.PASTE = " .. s(function() return product.flags.PASTE end))
        w(3, pp .. ".flags.PRESSED = " .. s(function() return product.flags.PRESSED end))
        w(3, pp .. ".flags.CRAFTS = " .. s(function() return product.flags.CRAFTS end))
        w(3, pp .. ".flags.USE_FULL_REACTION_PRODUCT_CLASS = " .. s(function() return product.flags.USE_FULL_REACTION_PRODUCT_CLASS end))
        w(3, pp .. ".flags.USE_REAGENT_ITEM = " .. s(function() return product.flags.USE_REAGENT_ITEM end))
        w(3, pp .. ".flags.TRANSFER_ARTIFACT_STATUS = " .. s(function() return product.flags.TRANSFER_ARTIFACT_STATUS end))
        
        w(2, "-- Get Material --")
        w(3, pp .. ".get_material.reagent_code = " .. s(function() return product.get_material.reagent_code end))
        w(3, pp .. ".get_material.product_code = " .. s(function() return product.get_material.product_code end))

        safe_iterate(3, pp .. ".item_str", function() return product.item_str end)
        safe_iterate(3, pp .. ".material_str", function() return product.material_str end)
    end
end
w(0, "")

w(0, "=== BUILDING ===")
local bld_p = bp .. ".building"
safe_iterate(1, bld_p .. ".token", function() return reaction.building.token end)
safe_iterate(1, bld_p .. ".temp_job_key", function() return reaction.building.temp_job_key end)
safe_iterate(1, bld_p .. ".type", function() return reaction.building.type end)
safe_iterate(1, bld_p .. ".subtype", function() return reaction.building.subtype end)
safe_iterate(1, bld_p .. ".custom", function() return reaction.building.custom end)
safe_iterate(1, bld_p .. ".hotkey", function() return reaction.building.hotkey end)
w(0, "")

w(0, "=== RAW STRINGS & DESCRIPTIONS ===")
safe_iterate(1, bp .. ".raw_strings", function() return reaction.raw_strings end)
safe_iterate(1, bp .. ".descriptions", function() return reaction.descriptions end)

file:close()
print("Analysis complete. Full paths dumped to " .. filename)