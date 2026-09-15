--@ module = true
-- ==========================================
-- REFINISH STEEL: INORGANIC DATA READER
-- Purpose: Exhaustively extracts and organizes live C++ memory paths 
-- for a specific inorganic material based strictly on verified paths.
-- ==========================================

local function find_inorganic(target)
    local inorganics = df.global.world.raws.inorganics.all
    if type(target) == "number" then
        return inorganics[target], target
    end
    if type(target) == "string" then
        local num_target = tonumber(target)
        if num_target and inorganics[num_target] then
            return inorganics[num_target], num_target
        end
        for i, mat in ipairs(inorganics) do
            if mat.id == target then
                return mat, i
            end
        end
    end
    return nil, nil
end

-- Safely copy a string vector
local function copy_string_vector(vec)
    local res = {}
    if vec then
        for i, v in ipairs(vec) do
            if v and v.value then table.insert(res, v.value)
            elseif type(v) == "string" then table.insert(res, v) end
        end
    end
    return res
end

-- Safely copy a numerical vector
local function copy_num_vector(vec)
    local res = {}
    if vec then
        for i, v in ipairs(vec) do table.insert(res, v) end
    end
    return res
end

function get_inorganic_data(target)
    local mat, mat_idx = find_inorganic(target)
    if not mat then return nil end

    local data = {
        id = mat.id,
        index = mat_idx,
        str = copy_string_vector(mat.str),
        source_hfid = mat.source_hfid,
        source_enid = mat.source_enid,
        times_used_land = mat.times_used_land,
        times_used_ocean = mat.times_used_ocean,
        flags = {},
        metal_ore = {},
        thread_metal = {},
        economic_uses = copy_num_vector(mat.economic_uses),
        environment_spec = {},
        environment = {},
        material = {
            heat = {},
            state_color = {},
            state_name = {},
            state_adj = {},
            strength = { yield = {}, fracture = {}, strain_at_yield = {} },
            flags = {},
            meat_name = {},
            block_name = {},
            reaction_product = {},
            hardens_with_water = {},
            reaction_class = {},
            basic_color = {},
            build_color = {},
            tile_color = {},
            mat_rgb = {},
            syndrome = {},
            sphere = {},
            food_mat_index = {},
            state_color_str = {}
        }
    }

    -- OUTER INORGANIC FLAGS
    if mat.flags then
        data.flags = {
            LAVA = mat.flags.LAVA, GENERATED = mat.flags.GENERATED, CAN_OCCUR_ON_SURFACE = mat.flags.CAN_OCCUR_ON_SURFACE,
            SEDIMENTARY = mat.flags.SEDIMENTARY, SEDIMENTARY_OCEAN_SHALLOW = mat.flags.SEDIMENTARY_OCEAN_SHALLOW,
            IGNEOUS_EXTRUSIVE = mat.flags.IGNEOUS_EXTRUSIVE, METAMORPHIC = mat.flags.METAMORPHIC,
            DEEP_SURFACE = mat.flags.DEEP_SURFACE, METAL_ORE = mat.flags.METAL_ORE, AQUIFER = mat.flags.AQUIFER,
            SOIL_ANY = mat.flags.SOIL_ANY, SOIL_OCEAN = mat.flags.SOIL_OCEAN, SOIL_SAND = mat.flags.SOIL_SAND,
            SEDIMENTARY_OCEAN_DEEP = mat.flags.SEDIMENTARY_OCEAN_DEEP, THREAD_METAL = mat.flags.THREAD_METAL,
            SPECIAL = mat.flags.SPECIAL, SOIL = mat.flags.SOIL, DEEP_SPECIAL = mat.flags.DEEP_SPECIAL,
            DIVINE = mat.flags.DIVINE, MYTHICAL = mat.flags.MYTHICAL, MYTHICAL_REMNANT = mat.flags.MYTHICAL_REMNANT,
            MYTHICAL_SUBSTANCE = mat.flags.MYTHICAL_SUBSTANCE, UNUSED_03_08 = mat.flags.UNUSED_03_08,
            UNUSED_04_01 = mat.flags.UNUSED_04_01, WAFERS = mat.flags.WAFERS
        }
    end

    -- OUTER STRUCTS
    if mat.metal_ore then
        data.metal_ore.str = copy_string_vector(mat.metal_ore.str)
        data.metal_ore.mat_index = copy_num_vector(mat.metal_ore.mat_index)
        data.metal_ore.probability = copy_num_vector(mat.metal_ore.probability)
    end
    if mat.thread_metal then
        data.thread_metal.str = copy_string_vector(mat.thread_metal.str)
        data.thread_metal.mat_index = copy_num_vector(mat.thread_metal.mat_index)
        data.thread_metal.probability = copy_num_vector(mat.thread_metal.probability)
    end
    if mat.environment_spec then
        data.environment_spec.str = copy_string_vector(mat.environment_spec.str)
        data.environment_spec.mat_index = copy_num_vector(mat.environment_spec.mat_index)
        data.environment_spec.inclusion_type = copy_num_vector(mat.environment_spec.inclusion_type)
        data.environment_spec.probability = copy_num_vector(mat.environment_spec.probability)
    end
    if mat.environment then
        data.environment.location = copy_num_vector(mat.environment.location)
        data.environment.type = copy_num_vector(mat.environment.type)
        data.environment.probability = copy_num_vector(mat.environment.probability)
    end

    -- INNER MATERIAL DATA
    if mat.material then
        local m = mat.material
        data.material.id = m.id
        data.material.gem_name1 = m.gem_name1
        data.material.gem_name2 = m.gem_name2
        data.material.stone_name = m.stone_name
        
        if m.heat then
            data.material.heat.spec_heat = m.heat.spec_heat
            data.material.heat.heatdam_point = m.heat.heatdam_point
            data.material.heat.colddam_point = m.heat.colddam_point
            data.material.heat.ignite_point = m.heat.ignite_point
            data.material.heat.melting_point = m.heat.melting_point
            data.material.heat.boiling_point = m.heat.boiling_point
            data.material.heat.mat_fixed_temp = m.heat.mat_fixed_temp
        end

        data.material.solid_density = m.solid_density
        data.material.liquid_density = m.liquid_density
        data.material.molar_mass = m.molar_mass

        if m.state_color then
            data.material.state_color = { Solid = m.state_color.Solid, Liquid = m.state_color.Liquid, Gas = m.state_color.Gas, Powder = m.state_color.Powder, Paste = m.state_color.Paste, Pressed = m.state_color.Pressed }
        end
        if m.state_name then
            data.material.state_name = { Solid = m.state_name.Solid, Liquid = m.state_name.Liquid, Gas = m.state_name.Gas, Powder = m.state_name.Powder, Paste = m.state_name.Paste, Pressed = m.state_name.Pressed }
        end
        if m.state_adj then
            data.material.state_adj = { Solid = m.state_adj.Solid, Liquid = m.state_adj.Liquid, Gas = m.state_adj.Gas, Powder = m.state_adj.Powder, Paste = m.state_adj.Paste, Pressed = m.state_adj.Pressed }
        end

        if m.strength then
            data.material.strength.absorption = m.strength.absorption
            data.material.strength.max_edge = m.strength.max_edge
            if m.strength.yield then
                data.material.strength.yield = { BENDING = m.strength.yield.BENDING, SHEAR = m.strength.yield.SHEAR, TORSION = m.strength.yield.TORSION, IMPACT = m.strength.yield.IMPACT, TENSILE = m.strength.yield.TENSILE, COMPRESSIVE = m.strength.yield.COMPRESSIVE }
            end
            if m.strength.fracture then
                data.material.strength.fracture = { BENDING = m.strength.fracture.BENDING, SHEAR = m.strength.fracture.SHEAR, TORSION = m.strength.fracture.TORSION, IMPACT = m.strength.fracture.IMPACT, TENSILE = m.strength.fracture.TENSILE, COMPRESSIVE = m.strength.fracture.COMPRESSIVE }
            end
            if m.strength.strain_at_yield then
                data.material.strength.strain_at_yield = { BENDING = m.strength.strain_at_yield.BENDING, SHEAR = m.strength.strain_at_yield.SHEAR, TORSION = m.strength.strain_at_yield.TORSION, IMPACT = m.strength.strain_at_yield.IMPACT, TENSILE = m.strength.strain_at_yield.TENSILE, COMPRESSIVE = m.strength.strain_at_yield.COMPRESSIVE }
            end
        end

        data.material.material_value = m.material_value

        if m.flags then
            data.material.flags = {
                BONE = m.flags.BONE, MEAT = m.flags.MEAT, EDIBLE_VERMIN = m.flags.EDIBLE_VERMIN, EDIBLE_RAW = m.flags.EDIBLE_RAW,
                EDIBLE_COOKED = m.flags.EDIBLE_COOKED, ALCOHOL = m.flags.ALCOHOL, ITEMS_METAL = m.flags.ITEMS_METAL,
                ITEMS_BARRED = m.flags.ITEMS_BARRED, ITEMS_SCALED = m.flags.ITEMS_SCALED, ITEMS_LEATHER = m.flags.ITEMS_LEATHER,
                ITEMS_SOFT = m.flags.ITEMS_SOFT, ITEMS_HARD = m.flags.ITEMS_HARD, IMPLIES_ANIMAL_KILL = m.flags.IMPLIES_ANIMAL_KILL,
                ALCOHOL_PLANT = m.flags.ALCOHOL_PLANT, ALCOHOL_CREATURE = m.flags.ALCOHOL_CREATURE, CHEESE_PLANT = m.flags.CHEESE_PLANT,
                CHEESE_CREATURE = m.flags.CHEESE_CREATURE, POWDER_MISC_PLANT = m.flags.POWDER_MISC_PLANT, POWDER_MISC_CREATURE = m.flags.POWDER_MISC_CREATURE,
                STOCKPILE_GLOB = m.flags.STOCKPILE_GLOB, LIQUID_MISC_PLANT = m.flags.LIQUID_MISC_PLANT, LIQUID_MISC_CREATURE = m.flags.LIQUID_MISC_CREATURE,
                LIQUID_MISC_OTHER = m.flags.LIQUID_MISC_OTHER, WOOD = m.flags.WOOD, THREAD_PLANT = m.flags.THREAD_PLANT,
                TOOTH = m.flags.TOOTH, HORN = m.flags.HORN, PEARL = m.flags.PEARL, SHELL = m.flags.SHELL, LEATHER = m.flags.LEATHER,
                SILK = m.flags.SILK, SOAP = m.flags.SOAP, ROTS = m.flags.ROTS, IS_DYE = m.flags.IS_DYE, POWDER_MISC = m.flags.POWDER_MISC,
                LIQUID_MISC = m.flags.LIQUID_MISC, STRUCTURAL_PLANT_MAT = m.flags.STRUCTURAL_PLANT_MAT, SEED_MAT = m.flags.SEED_MAT,
                STOCKPILE_PLANT_GROWTH = m.flags.STOCKPILE_PLANT_GROWTH, CHEESE = m.flags.CHEESE, ENTERS_BLOOD = m.flags.ENTERS_BLOOD,
                BLOOD_MAP_DESCRIPTOR = m.flags.BLOOD_MAP_DESCRIPTOR, ICHOR_MAP_DESCRIPTOR = m.flags.ICHOR_MAP_DESCRIPTOR, GOO_MAP_DESCRIPTOR = m.flags.GOO_MAP_DESCRIPTOR,
                SLIME_MAP_DESCRIPTOR = m.flags.SLIME_MAP_DESCRIPTOR, PUS_MAP_DESCRIPTOR = m.flags.PUS_MAP_DESCRIPTOR, GENERATES_MIASMA = m.flags.GENERATES_MIASMA,
                IS_METAL = m.flags.IS_METAL, IS_GEM = m.flags.IS_GEM, IS_GLASS = m.flags.IS_GLASS, CRYSTAL_GLASSABLE = m.flags.CRYSTAL_GLASSABLE,
                ITEMS_WEAPON = m.flags.ITEMS_WEAPON, ITEMS_WEAPON_RANGED = m.flags.ITEMS_WEAPON_RANGED, ITEMS_ANVIL = m.flags.ITEMS_ANVIL,
                ITEMS_AMMO = m.flags.ITEMS_AMMO, ITEMS_DIGGER = m.flags.ITEMS_DIGGER, ITEMS_ARMOR = m.flags.ITEMS_ARMOR,
                ITEMS_DELICATE = m.flags.ITEMS_DELICATE, ITEMS_SIEGE_ENGINE = m.flags.ITEMS_SIEGE_ENGINE, ITEMS_QUERN = m.flags.ITEMS_QUERN,
                IS_STONE = m.flags.IS_STONE, UNDIGGABLE = m.flags.UNDIGGABLE, YARN = m.flags.YARN, STOCKPILE_GLOB_PASTE = m.flags.STOCKPILE_GLOB_PASTE,
                STOCKPILE_GLOB_PRESSED = m.flags.STOCKPILE_GLOB_PRESSED, DISPLAY_UNGLAZED = m.flags.DISPLAY_UNGLAZED, DO_NOT_CLEAN_GLOB = m.flags.DO_NOT_CLEAN_GLOB,
                NO_STONE_STOCKPILE = m.flags.NO_STONE_STOCKPILE, STOCKPILE_THREAD_METAL = m.flags.STOCKPILE_THREAD_METAL, SWEAT_MAP_DESCRIPTOR = m.flags.SWEAT_MAP_DESCRIPTOR,
                TEARS_MAP_DESCRIPTOR = m.flags.TEARS_MAP_DESCRIPTOR, SPIT_MAP_DESCRIPTOR = m.flags.SPIT_MAP_DESCRIPTOR, EVAPORATES = m.flags.EVAPORATES,
                STOCKPILE_PLANT = m.flags.STOCKPILE_PLANT, IS_CERAMIC = m.flags.IS_CERAMIC, CARTILAGE = m.flags.CARTILAGE,
                FEATHER = m.flags.FEATHER, SCALE = m.flags.SCALE, HAIR = m.flags.HAIR, NERVOUS_TISSUE = m.flags.NERVOUS_TISSUE,
                HOOF = m.flags.HOOF, CHITIN = m.flags.CHITIN, ANTLER = m.flags.ANTLER
            }
        end

        data.material.extract_storage = m.extract_storage
        data.material.butcher_special_type = m.butcher_special_type
        data.material.butcher_special_subtype = m.butcher_special_subtype
        data.material.meat_organ = m.meat_organ
        
        -- Misc Vectors
        if m.meat_name then for i=0,2 do data.material.meat_name[i] = m.meat_name[i] end end
        if m.block_name then for i=0,1 do data.material.block_name[i] = m.block_name[i] end end
        
        -- Reaction Product Struct
        if m.reaction_product then
            data.material.reaction_product.id = copy_string_vector(m.reaction_product.id)
            data.material.reaction_product.item_type = copy_num_vector(m.reaction_product.item_type)
            data.material.reaction_product.item_subtype = copy_num_vector(m.reaction_product.item_subtype)
            if m.reaction_product.material then
                data.material.reaction_product.material = {
                    mat_type = copy_num_vector(m.reaction_product.material.mat_type),
                    mat_index = copy_num_vector(m.reaction_product.material.mat_index)
                }
            end
        end

        -- Hardens with water
        if m.hardens_with_water then
            data.material.hardens_with_water.mat_type = m.hardens_with_water.mat_type
            data.material.hardens_with_water.mat_index = m.hardens_with_water.mat_index
        end

        data.material.reaction_class = copy_string_vector(m.reaction_class)
        data.material.tile = m.tile
        data.material.item_symbol = m.item_symbol

        if m.basic_color then data.material.basic_color = {m.basic_color[0], m.basic_color[1]} end
        if m.build_color then data.material.build_color = {m.build_color[0], m.build_color[1], m.build_color[2]} end
        if m.tile_color then data.material.tile_color = {m.tile_color[0], m.tile_color[1], m.tile_color[2]} end
        if m.mat_rgb then data.material.mat_rgb = {m.mat_rgb[0], m.mat_rgb[1], m.mat_rgb[2]} end
        
        data.material.powder_dye = m.powder_dye
        data.material.temp_diet_info = m.temp_diet_info
        data.material.soap_level = m.soap_level
        data.material.prefix = m.prefix
        
        if m.syndrome and m.syndrome.syndrome then data.material.syndrome = copy_num_vector(m.syndrome.syndrome) end
        data.material.sphere = copy_num_vector(m.sphere)

        if m.food_mat_index then
            data.material.food_mat_index = {
                Meat = m.food_mat_index.Meat, Fish = m.food_mat_index.Fish, UnpreparedFish = m.food_mat_index.UnpreparedFish, Eggs = m.food_mat_index.Eggs, Plants = m.food_mat_index.Plants, PlantDrink = m.food_mat_index.PlantDrink, CreatureDrink = m.food_mat_index.CreatureDrink, PlantCheese = m.food_mat_index.PlantCheese, CreatureCheese = m.food_mat_index.CreatureCheese, Seed = m.food_mat_index.Seed, PlantGrowth = m.food_mat_index.PlantGrowth, PlantPowder = m.food_mat_index.PlantPowder, CreaturePowder = m.food_mat_index.CreaturePowder, Glob = m.food_mat_index.Glob, PlantLiquid = m.food_mat_index.PlantLiquid, CreatureLiquid = m.food_mat_index.CreatureLiquid, MiscLiquid = m.food_mat_index.MiscLiquid, Leather = m.food_mat_index.Leather, Silk = m.food_mat_index.Silk, PlantFiber = m.food_mat_index.PlantFiber, Bone = m.food_mat_index.Bone, Shell = m.food_mat_index.Shell, Wood = m.food_mat_index.Wood, Horn = m.food_mat_index.Horn, Pearl = m.food_mat_index.Pearl, Tooth = m.food_mat_index.Tooth, EdibleCheese = m.food_mat_index.EdibleCheese, AnyDrink = m.food_mat_index.AnyDrink, EdiblePlant = m.food_mat_index.EdiblePlant, CookableLiquid = m.food_mat_index.CookableLiquid, CookablePowder = m.food_mat_index.CookablePowder, CookableSeed = m.food_mat_index.CookableSeed, CookablePlantGrowth = m.food_mat_index.CookablePlantGrowth, Paste = m.food_mat_index.Paste, Pressed = m.food_mat_index.Pressed, Yarn = m.food_mat_index.Yarn, MetalThread = m.food_mat_index.MetalThread, Paper = m.food_mat_index.Paper, Parchment = m.food_mat_index.Parchment
            }
        end

        data.material.powder_dye_str = m.powder_dye_str
        if m.state_color_str then
            data.material.state_color_str = { Solid = m.state_color_str.Solid, Liquid = m.state_color_str.Liquid, Gas = m.state_color_str.Gas, Powder = m.state_color_str.Powder, Paste = m.state_color_str.Paste, Pressed = m.state_color_str.Pressed }
        end

        data.material.wood_texpos = m.wood_texpos
        data.material.boulder_texpos1 = m.boulder_texpos1
        data.material.boulder_texpos2 = m.boulder_texpos2
        data.material.rough_texpos1 = m.rough_texpos1
        data.material.rough_texpos2 = m.rough_texpos2
        data.material.bar_texpos = m.bar_texpos
        data.material.cheese_texpos1 = m.cheese_texpos1
        data.material.cheese_texpos2 = m.cheese_texpos2
        data.material.texflag = m.texflag
    end

    return data
end

-- ==========================================
-- OUTPUT FORMATTERS (RECURSIVE)
-- ==========================================
local function serialize_table(val, name, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local lines = {}
    
    if type(val) == "table" then
        if next(val) == nil then
            table.insert(lines, indent .. name .. " = {}")
        else
            table.insert(lines, indent .. name .. " = {")
            for k, v in pairs(val) do
                table.insert(lines, serialize_table(v, tostring(k), depth + 1))
            end
            table.insert(lines, indent .. "}")
        end
    else
        table.insert(lines, indent .. name .. " = " .. tostring(val))
    end
    return table.concat(lines, "\n")
end

local function format_data_to_string(data)
    if not data then return "No data found." end
    local header = "=== INORGANIC DATA: " .. data.id .. " (Index: " .. tostring(data.index) .. ") ==="
    return header .. "\n" .. serialize_table(data, "inorganic_data", 0)
end

-- ==========================================
-- COMMAND LINE HANDLER
-- ==========================================
local args = {...}

if #args > 0 then
    local target_id = args[1]
    local mode = args[2] or "print"

    local data = get_inorganic_data(target_id)

    if not data then
        qerror("Could not find inorganic material: " .. target_id)
    end

    local output_str = format_data_to_string(data)

    if mode == "dump" then
        local filename = "refinish_dump_" .. string.lower(target_id) .. ".txt"
        local file = io.open(filename, "w")
        if file then
            file:write(output_str)
            file:close()
            print("Successfully dumped exhaustive data to: " .. filename)
        else
            qerror("Failed to write to file: " .. filename)
        end
    else
        print(output_str)
    end
end

return _ENV