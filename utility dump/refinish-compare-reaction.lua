-- refinish-reaction-compare.lua
-- Hardcoded analysis tool to compare ANY number of reactions using strictly mapped DFHack paths, with smart raw string parsing.

local args = {...}

if #args < 2 then
    qerror("Usage: refinish-reaction-compare <REACTION_CODE_1> <REACTION_CODE_2> ... <REACTION_CODE_N>")
end

local reactions = {}
local codes_found = {}

-- Find all requested reactions
for _, r in ipairs(df.global.world.raws.reactions.reactions) do
    for _, target in ipairs(args) do
        if r.code == target and not codes_found[target] then
            table.insert(reactions, r)
            codes_found[target] = true
        end
    end
end

-- Verify we found everything
for _, target in ipairs(args) do
    if not codes_found[target] then
        qerror("Reaction not found: " .. target)
    end
end

local timestamp = os.date("%Y%m%d_%H%M%S")
local filename = string.format("compare_multiple_%d_reactions_%s.txt", #reactions, timestamp)
local file = io.open(filename, "w")

if not file then
    qerror("Failed to open file for writing: " .. filename)
end

local function w(indent, str) 
    file:write(string.rep("\t", indent) .. str .. "\n") 
end

-- Extraction logic safely stores values into a dictionary using relative paths
local function extract_reaction(reaction)
    local data = {}
    
    local function store(path, func)
        local ok, val = pcall(func)
        data[path] = (ok and val ~= nil) and tostring(val) or "UNBOUND_OR_NIL"
    end

    local function safe_iterate(path, func)
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
                data[path .. "[" .. (i-1) .. "]"] = str_val
                count = count + 1
            end
            if count == 0 then data[path] = "EMPTY" end
        else
            data[path] = "UNBOUND_OR_NIL"
        end
    end

    -- Smart string parser for Dwarf Fortress raw tags
    local function safe_string_parse(path, func)
        local ok, vec = pcall(func)
        if ok and (type(vec) == "userdata" or type(vec) == "table") then
            local tag_counts = {}
            local total = 0
            for i, v in ipairs(vec) do
                local str_val = nil
                if type(v) == "string" then 
                    str_val = v
                elseif type(v) == "userdata" or type(v) == "table" then
                    pcall(function() str_val = tostring(v.value) end)
                end
                
                if str_val then
                    total = total + 1
                    -- Strip outer brackets if present
                    local inner = str_val:match("^%[(.*)%]$") or str_val
                    
                    local parts = {}
                    for part in string.gmatch(inner, "([^:]+)") do
                        table.insert(parts, part)
                    end
                    
                    if #parts > 0 then
                        local tag_type = parts[1]
                        tag_counts[tag_type] = (tag_counts[tag_type] or 0) + 1
                        local tag_idx = tag_counts[tag_type] - 1
                        
                        local base_path = path .. "." .. tag_type .. "[" .. tag_idx .. "]"
                        data[base_path .. ".full"] = str_val
                        data[base_path .. ".arg_count"] = tostring(#parts - 1)
                        
                        for j = 2, #parts do
                            data[base_path .. ".arg[" .. (j-2) .. "]"] = parts[j]
                        end
                    end
                end
            end
            data[path .. ".total_count"] = tostring(total)
            for tag, count in pairs(tag_counts) do
                data[path .. "." .. tag .. "_count"] = tostring(count)
            end
        else
            data[path .. ".total_count"] = "UNBOUND_OR_NIL"
        end
    end

    store(".code", function() return reaction.code end)
    store(".name", function() return reaction.name end)
    store(".skill", function() return reaction.skill end)
    store(".max_multiplier", function() return reaction.max_multiplier end)
    store(".index", function() return reaction.index end)
    store(".source_hfid", function() return reaction.source_hfid end)
    store(".source_efid", function() return reaction.source_efid end)
    store(".category", function() return reaction.category end)
    store(".rand_range", function() return reaction.rand_range end)
    store(".skill_mult", function() return reaction.skill_mult end)
    store(".attr_gain", function() return reaction.attr_gain end)
    store(".exp_gain", function() return reaction.exp_gain end)

    store(".flags.FUEL", function() return reaction.flags.FUEL end)
    store(".flags.AUTOMATIC", function() return reaction.flags.AUTOMATIC end)
    store(".flags.ADVENTURE_MODE_ENABLED", function() return reaction.flags.ADVENTURE_MODE_ENABLED end)
    store(".flags.GENERATED", function() return reaction.flags.GENERATED end)
    store(".flags.FORTRESS_MODE_ENABLED", function() return reaction.flags.FORTRESS_MODE_ENABLED end)
    store(".flags.WORLDGEN_ENABLED", function() return reaction.flags.WORLDGEN_ENABLED end)

    local ok_reagents, reagents = pcall(function() return reaction.reagents end)
    if ok_reagents and reagents and type(reagents) == "userdata" then
        store(".reagents.count", function() return #reagents end)
        for i, reagent in ipairs(reagents) do
            local rp = ".reagents[" .. (i-1) .. "]"
            store(rp .. ".code", function() return reagent.code end)
            store(rp .. ".quantity", function() return reagent.quantity end)
            store(rp .. ".item_type", function() return reagent.item_type end)
            store(rp .. ".item_subtype", function() return reagent.item_subtype end)
            store(rp .. ".mat_type", function() return reagent.mat_type end)
            store(rp .. ".mat_index", function() return reagent.mat_index end)
            store(rp .. ".reaction_class", function() return reagent.reaction_class end)
            store(rp .. ".has_material_reaction_product", function() return reagent.has_material_reaction_product end)
            store(rp .. ".flags4", function() return reagent.flags4 end)
            store(rp .. ".flags5", function() return reagent.flags5 end)
            store(rp .. ".metal_ore", function() return reagent.metal_ore end)
            store(rp .. ".min_dimension", function() return reagent.min_dimension end)
            store(rp .. ".has_tool_use", function() return reagent.has_tool_use end)
            store(rp .. ".dye_color", function() return reagent.dye_color end)

            store(rp .. ".flags.PRESERVE_REAGENT", function() return reagent.flags.PRESERVE_REAGENT end)
            store(rp .. ".flags.IN_CONTAINER", function() return reagent.flags.IN_CONTAINER end)
            store(rp .. ".flags.DOES_NOT_DETERMINE_PRODUCT_AMOUNT", function() return reagent.flags.DOES_NOT_DETERMINE_PRODUCT_AMOUNT end)

            store(rp .. ".flags1.improvable", function() return reagent.flags1.improvable end)
            store(rp .. ".flags1.butcherable", function() return reagent.flags1.butcherable end)
            store(rp .. ".flags1.millable", function() return reagent.flags1.millable end)
            store(rp .. ".flags1.allow_buryable", function() return reagent.flags1.allow_buryable end)
            store(rp .. ".flags1.unrotten", function() return reagent.flags1.unrotten end)
            store(rp .. ".flags1.undisturbed", function() return reagent.flags1.undisturbed end)
            store(rp .. ".flags1.collected", function() return reagent.flags1.collected end)
            store(rp .. ".flags1.sharpenable", function() return reagent.flags1.sharpenable end)
            store(rp .. ".flags1.murdered", function() return reagent.flags1.murdered end)
            store(rp .. ".flags1.UNUSED_1_10", function() return reagent.flags1.UNUSED_1_10 end)
            store(rp .. ".flags1.empty", function() return reagent.flags1.empty end)
            store(rp .. ".flags1.processable", function() return reagent.flags1.processable end)
            store(rp .. ".flags1.UNUSED_1_13", function() return reagent.flags1.UNUSED_1_13 end)
            store(rp .. ".flags1.cookable", function() return reagent.flags1.cookable end)
            store(rp .. ".flags1.extract_bearing_plant", function() return reagent.flags1.extract_bearing_plant end)
            store(rp .. ".flags1.extract_bearing_fish", function() return reagent.flags1.extract_bearing_fish end)
            store(rp .. ".flags1.extract_bearing_vermin", function() return reagent.flags1.extract_bearing_vermin end)
            store(rp .. ".flags1.processable_to_vial", function() return reagent.flags1.processable_to_vial end)
            store(rp .. ".flags1.UNUSED_1_19", function() return reagent.flags1.UNUSED_1_19 end)
            store(rp .. ".flags1.processable_to_barrel", function() return reagent.flags1.processable_to_barrel end)
            store(rp .. ".flags1.solid", function() return reagent.flags1.solid end)
            store(rp .. ".flags1.tameable_vermin", function() return reagent.flags1.tameable_vermin end)
            store(rp .. ".flags1.nearby", function() return reagent.flags1.nearby end)
            store(rp .. ".flags1.sand_bearing", function() return reagent.flags1.sand_bearing end)
            store(rp .. ".flags1.glass", function() return reagent.flags1.glass end)
            store(rp .. ".flags1.milk", function() return reagent.flags1.milk end)
            store(rp .. ".flags1.milkable", function() return reagent.flags1.milkable end)
            store(rp .. ".flags1.finished_goods", function() return reagent.flags1.finished_goods end)
            store(rp .. ".flags1.ammo", function() return reagent.flags1.ammo end)
            store(rp .. ".flags1.furniture", function() return reagent.flags1.furniture end)
            store(rp .. ".flags1.not_bin", function() return reagent.flags1.not_bin end)
            store(rp .. ".flags1.lye_bearing", function() return reagent.flags1.lye_bearing end)

            store(rp .. ".flags2.dye", function() return reagent.flags2.dye end)
            store(rp .. ".flags2.dyeable", function() return reagent.flags2.dyeable end)
            store(rp .. ".flags2.dyed", function() return reagent.flags2.dyed end)
            store(rp .. ".flags2.sewn_imageless", function() return reagent.flags2.sewn_imageless end)
            store(rp .. ".flags2.glass_making", function() return reagent.flags2.glass_making end)
            store(rp .. ".flags2.screw", function() return reagent.flags2.screw end)
            store(rp .. ".flags2.building_material", function() return reagent.flags2.building_material end)
            store(rp .. ".flags2.fire_safe", function() return reagent.flags2.fire_safe end)
            store(rp .. ".flags2.magma_safe", function() return reagent.flags2.magma_safe end)
            store(rp .. ".flags2.deep_material", function() return reagent.flags2.deep_material end)
            store(rp .. ".flags2.melt_designated", function() return reagent.flags2.melt_designated end)
            store(rp .. ".flags2.non_economic", function() return reagent.flags2.non_economic end)
            store(rp .. ".flags2.allow_melt_dump", function() return reagent.flags2.allow_melt_dump end)
            store(rp .. ".flags2.allow_artifact", function() return reagent.flags2.allow_artifact end)
            store(rp .. ".flags2.plant", function() return reagent.flags2.plant end)
            store(rp .. ".flags2.silk", function() return reagent.flags2.silk end)
            store(rp .. ".flags2.leather", function() return reagent.flags2.leather end)
            store(rp .. ".flags2.bone", function() return reagent.flags2.bone end)
            store(rp .. ".flags2.shell", function() return reagent.flags2.shell end)
            store(rp .. ".flags2.totemable", function() return reagent.flags2.totemable end)
            store(rp .. ".flags2.horn", function() return reagent.flags2.horn end)
            store(rp .. ".flags2.pearl", function() return reagent.flags2.pearl end)
            store(rp .. ".flags2.plaster_containing", function() return reagent.flags2.plaster_containing end)
            store(rp .. ".flags2.UNUSED_24", function() return reagent.flags2.UNUSED_24 end)
            store(rp .. ".flags2.soap", function() return reagent.flags2.soap end)
            store(rp .. ".flags2.body_part", function() return reagent.flags2.body_part end)
            store(rp .. ".flags2.ivory_tooth", function() return reagent.flags2.ivory_tooth end)
            store(rp .. ".flags2.lye_milk_free", function() return reagent.flags2.lye_milk_free end)
            store(rp .. ".flags2.blunt", function() return reagent.flags2.blunt end)
            store(rp .. ".flags2.unengraved", function() return reagent.flags2.unengraved end)
            store(rp .. ".flags2.hair_wool", function() return reagent.flags2.hair_wool end)
            store(rp .. ".flags2.yarn", function() return reagent.flags2.yarn end)

            store(rp .. ".flags3.unimproved", function() return reagent.flags3.unimproved end)
            store(rp .. ".flags3.any_raw_material", function() return reagent.flags3.any_raw_material end)
            store(rp .. ".flags3.non_absorbent", function() return reagent.flags3.non_absorbent end)
            store(rp .. ".flags3.non_pressed", function() return reagent.flags3.non_pressed end)
            store(rp .. ".flags3.allow_liquid_powder", function() return reagent.flags3.allow_liquid_powder end)
            store(rp .. ".flags3.any_craft", function() return reagent.flags3.any_craft end)
            store(rp .. ".flags3.hard", function() return reagent.flags3.hard end)
            store(rp .. ".flags3.food_storage", function() return reagent.flags3.food_storage end)
            store(rp .. ".flags3.metal", function() return reagent.flags3.metal end)
            store(rp .. ".flags3.sand", function() return reagent.flags3.sand end)
            store(rp .. ".flags3.can_use_location_reserved", function() return reagent.flags3.can_use_location_reserved end)
            store(rp .. ".flags3.written_on", function() return reagent.flags3.written_on end)
            store(rp .. ".flags3.edged", function() return reagent.flags3.edged end)
            store(rp .. ".flags3.on_ground", function() return reagent.flags3.on_ground end)
            store(rp .. ".flags3.divine", function() return reagent.flags3.divine end)
            store(rp .. ".flags3.crafted_artifact", function() return reagent.flags3.crafted_artifact end)
            store(rp .. ".flags3.wood", function() return reagent.flags3.wood end)
            store(rp .. ".flags3.stone", function() return reagent.flags3.stone end)
            store(rp .. ".flags3.non_artifact", function() return reagent.flags3.non_artifact end)
            store(rp .. ".flags3.woven", function() return reagent.flags3.woven end)
            store(rp .. ".flags3.gem", function() return reagent.flags3.gem end)
            store(rp .. ".flags3.empty_or_water", function() return reagent.flags3.empty_or_water end)
            store(rp .. ".flags3.grown_not_crafted", function() return reagent.flags3.grown_not_crafted end)

            safe_iterate(rp .. ".contains", function() return reagent.contains end)
            safe_iterate(rp .. ".item_str", function() return reagent.item_str end)
            safe_iterate(rp .. ".material_str", function() return reagent.material_str end)
            store(rp .. ".metal_ore_str", function() return reagent.metal_ore_str end)
            safe_iterate(rp .. ".contains_str", function() return reagent.contains_str end)
        end
    else
        store(".reagents.count", function() return "UNBOUND_OR_NIL" end)
    end

    local ok_products, products = pcall(function() return reaction.products end)
    if ok_products and products and type(products) == "userdata" then
        store(".products.count", function() return #products end)
        for i, product in ipairs(products) do
            local pp = ".products[" .. (i-1) .. "]"
            store(pp .. ".product_token", function() return product.product_token end)
            store(pp .. ".product_to_container", function() return product.product_to_container end)
            store(pp .. ".item_type", function() return product.item_type end)
            store(pp .. ".item.subtype", function() return product.item.subtype end)
            store(pp .. ".mat_type", function() return product.mat_type end)
            store(pp .. ".mat_index", function() return product.mat_index end)
            store(pp .. ".probability", function() return product.probability end)
            store(pp .. ".count", function() return product.count end)
            store(pp .. ".product_dimension", function() return product.product_dimension end)

            store(pp .. ".flags.GET_MATERIAL_SAME", function() return product.flags.GET_MATERIAL_SAME end)
            store(pp .. ".flags.GET_MATERIAL_PRODUCT", function() return product.flags.GET_MATERIAL_PRODUCT end)
            store(pp .. ".flags.FORCE_EDGE", function() return product.flags.FORCE_EDGE end)
            store(pp .. ".flags.PASTE", function() return product.flags.PASTE end)
            store(pp .. ".flags.PRESSED", function() return product.flags.PRESSED end)
            store(pp .. ".flags.CRAFTS", function() return product.flags.CRAFTS end)
            store(pp .. ".flags.USE_FULL_REACTION_PRODUCT_CLASS", function() return product.flags.USE_FULL_REACTION_PRODUCT_CLASS end)
            store(pp .. ".flags.USE_REAGENT_ITEM", function() return product.flags.USE_REAGENT_ITEM end)
            store(pp .. ".flags.TRANSFER_ARTIFACT_STATUS", function() return product.flags.TRANSFER_ARTIFACT_STATUS end)

            store(pp .. ".get_material.reagent_code", function() return product.get_material.reagent_code end)
            store(pp .. ".get_material.product_code", function() return product.get_material.product_code end)

            safe_iterate(pp .. ".item_str", function() return product.item_str end)
            safe_iterate(pp .. ".material_str", function() return product.material_str end)
        end
    else
        store(".products.count", function() return "UNBOUND_OR_NIL" end)
    end

    safe_iterate(".building.token", function() return reaction.building.token end)
    safe_iterate(".building.temp_job_key", function() return reaction.building.temp_job_key end)
    safe_iterate(".building.type", function() return reaction.building.type end)
    safe_iterate(".building.subtype", function() return reaction.building.subtype end)
    safe_iterate(".building.custom", function() return reaction.building.custom end)
    safe_iterate(".building.hotkey", function() return reaction.building.hotkey end)

    safe_string_parse(".raw_strings", function() return reaction.raw_strings end)
    safe_string_parse(".descriptions", function() return reaction.descriptions end)

    return data
end

-- Process all reactions into datasets
local datasets = {}
for i, rx in ipairs(reactions) do
    datasets[i] = extract_reaction(rx)
end

-- Collect unique keys from ALL datasets
local keys = {}
local seen = {}
for _, data in ipairs(datasets) do
    for k, _ in pairs(data) do
        if not seen[k] then 
            table.insert(keys, k)
            seen[k] = true 
        end
    end
end
table.sort(keys)

local differences = {}
local similarities = {}

for _, k in ipairs(keys) do
    local first_val = datasets[1][k] or "MISSING_FROM_STRUCT"
    local all_same = true
    
    -- Check if this key holds the exact same value across every dataset
    for i = 2, #datasets do
        local val = datasets[i][k] or "MISSING_FROM_STRUCT"
        if val ~= first_val then
            all_same = false
            break
        end
    end
    
    if all_same then
        table.insert(similarities, {path = k, val = first_val})
    else
        local diff_entry = {path = k, vals = {}}
        for i = 1, #datasets do
            diff_entry.vals[i] = datasets[i][k] or "MISSING_FROM_STRUCT"
        end
        table.insert(differences, diff_entry)
    end
end

w(0, "=== REACTION COMPARISON DUMP ===")
for i, rx in ipairs(reactions) do
    w(0, string.format("Reaction %d: %s (Index: %d)", i, rx.code, rx.index))
end
w(0, "")

w(0, "=== DIFFERENCES ===")
if #differences == 0 then
    w(1, "No differences found between parsed paths.")
else
    for _, diff in ipairs(differences) do
        w(1, "Path: df.global.world.raws.reactions.reactions[<index>]" .. diff.path)
        for i, rx in ipairs(reactions) do
            w(2, string.format("[%d]%s = %s", rx.index, diff.path, diff.vals[i]))
        end
    end
end
w(0, "")

w(0, "=== SIMILARITIES ===")
if #similarities == 0 then
    w(1, "No similarities found.")
else
    for _, sim in ipairs(similarities) do
        w(1, string.format("df.global.world.raws.reactions.reactions[<index>]%s = %s", sim.path, sim.val))
    end
end

file:close()
print("Comparison complete. Dumped to " .. filename)