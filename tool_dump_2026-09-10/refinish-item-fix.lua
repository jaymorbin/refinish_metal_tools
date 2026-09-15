-- ==========================================
-- REFINISH-ITEM-FIX
-- ==========================================
-- Patches items created by dfhack.items.createItem() so they
-- match the state of naturally-created items (e.g. from the
-- CollectSand job). createItem() leaves items in a skeletal
-- state — thermal properties zeroed, flags incomplete, weight
-- missing, bag material wrong, no cloth improvements.
--
-- This script fixes all known discrepancies between created
-- items and real ones, based on side-by-side inspection of:
--   item 1507 (real bag)    vs  item 1530 (created bag)
--   item 1529 (real powder) vs  item 1531 (created powder)
--
-- USAGE:
--   refinish-item-fix --bag <id> --powder <id> [<id> ...]
--
-- The --bag item gets: correct cloth material, cloth/thread
-- improvements, thermal props, flags, weight, cached_index fix.
-- Each --powder item gets: thermal props, flags, weight.
--
-- This is a diagnostic/testing tool for the sand multiplier
-- system. Once the fixes are validated, the logic will move
-- into the onJobCompleted handler for CollectSand events.
-- ==========================================

-- ==========================================
-- MATERIAL THERMAL LOOKUP
-- ==========================================
-- DF stores thermal properties on each item as a cache of the
-- material's heat data. createItem() doesn't populate this
-- cache. This function reads the material definition and copies
-- all six thermal fields onto the item.
--
-- The fields on item correspond to material.heat.* fields:
--   item.spec_heat       ← material.heat.spec_heat
--   item.heatdam_point   ← material.heat.heatdam_point
--   item.colddam_point   ← material.heat.colddam_point
--   item.ignite_point    ← material.heat.ignite_point
--   item.melting_point   ← material.heat.melting_point
--   item.boiling_point   ← material.heat.boiling_point
--   item.fixed_temp      ← material.heat.mat_fixed_temp
-- ==========================================
local function apply_thermal_from_material(item, mat_type, mat_index)
    -- For inorganic materials (mat_type 0), the material def
    -- lives at world.raws.inorganics.all[mat_index].material
    local mat_info = dfhack.matinfo.decode(mat_type, mat_index)
    if not mat_info then
        qerror("Cannot decode material: mat_type=" .. mat_type .. " mat_index=" .. mat_index)
    end

    -- mat_info.material is the df.material struct that holds
    -- all physical/thermal/combat properties for this material.
    local heat = mat_info.material.heat

    item.spec_heat     = heat.spec_heat
    item.heatdam_point = heat.heatdam_point
    item.colddam_point = heat.colddam_point
    item.ignite_point  = heat.ignite_point
    item.melting_point = heat.melting_point
    item.boiling_point = heat.boiling_point
    item.fixed_temp    = heat.mat_fixed_temp
end

-- ==========================================
-- ITEM FLAGS FIX
-- ==========================================
-- flags[28] and flags[29] are both true on every real item but
-- false on created items. These appear to be temperature-system
-- initialization flags — real items have temp_updated_frame set
-- to a valid frame number, while created items have -1.
--
-- Without these flags, DF likely skips the item during
-- temperature processing and possibly during display/rendering
-- of container contents.
--
-- We set both flags and initialize temp_updated_frame to the
-- current frame counter so DF's temperature system picks them
-- up on the next tick.
-- ==========================================
local function apply_flags_and_temp(item)
    item.flags[28] = true
    item.flags[29] = true
    item.temp_updated_frame = df.global.world.frame_counter
end

-- ==========================================
-- WEIGHT CALCULATION
-- ==========================================
-- Real items have weight computed from their material's density
-- and the item's volume/dimension. createItem() leaves weight
-- at 0/0. Without weight, DF may skip the item in hauling,
-- stockpile, and container-display logic.
--
-- For powder: weight comes from the powder material's density
-- and the item's dimension. The exact formula DF uses internally
-- isn't publicly documented, but from inspection:
--   real sand powder (dim=150, density=1710) → weight 1.26000
--   real bag (cloth, density ~?) → weight 1.27000
--
-- Since the exact formula is unclear, we use a practical approach:
-- call dfhack.items.getWeight if available, or compute from
-- the material density. For now, we use the observed values from
-- real items as reference and compute proportionally.
--
-- density * dimension / SOME_CONSTANT = weight
-- 1710 * 150 / X = 1.26 → X ≈ 203571
-- This is approximate. The safe approach is to just copy the
-- weight from a known-good item of the same material+dimension,
-- or use DF's internal weight recalculation if we can trigger it.
-- ==========================================
local function apply_weight_from_density(item, mat_type, mat_index)
    local mat_info = dfhack.matinfo.decode(mat_type, mat_index)
    if not mat_info then return end

    local density = mat_info.material.solid_density

    -- For powders with a dimension field, weight scales with
    -- dimension. The constant 203571 was derived from observed
    -- real sand powder: density 1710 * dimension 150 / 203571 ≈ 1.26
    -- This is an approximation — if DF recalculates on next tick,
    -- having a nonzero weight is better than zero regardless.
    --
    -- NOTE: DF struct field access throws an error (not nil) if
    -- the field doesn't exist on that item type. Bags don't have
    -- .dimension — only powders do. We use pcall to safely check.
    local has_dim, dim_val = pcall(function() return item.dimension end)
    if has_dim and dim_val and dim_val > 0 then
        local raw_weight = (density * dim_val) / 203571
        item.weight.whole = math.floor(raw_weight)
        item.weight.fraction = math.floor((raw_weight - math.floor(raw_weight)) * 1000000)
    else
        -- For non-powder items (bags), use a simpler estimate.
        -- Real empty bag weight was 1.27000 — bags are light.
        -- Better to have any nonzero weight than zero.
        item.weight.whole = 1
        item.weight.fraction = 0
    end
end

-- ==========================================
-- BAG CLOTH MATERIAL FIX
-- ==========================================
-- createItem() for bags uses the creator unit's race index as
-- mat_type (e.g. 573 for dwarf), producing a bag "made of dwarf".
-- Real bags have mat_type=0 (inorganic) with a plant fiber cloth
-- mat_index — but that's misleading. Bags in DF are actually
-- made from cloth, which is a creature or plant product.
--
-- The real bag (1507) had mat_type=0, mat_index=284. This points
-- to whatever plant fiber was used to weave it. We need to find
-- a valid cloth material to assign.
--
-- APPROACH: Find the same mat_type/mat_index as the real bag's
-- source material. For testing, we'll use the real bag (item 1507)
-- as the reference — but in production, we'd find any available
-- cloth bag in the game world and copy its material.
-- ==========================================
local function find_cloth_bag_material()
    -- Search existing bags for one with a valid cloth material.
    -- Valid bags have mat_type=0 and a nonzero mat_index, with
    -- improvements (cloth + thread) present.
    for _, item in ipairs(df.global.world.items.all) do
        if df.item_bagst:is_instance(item)
            and item.mat_type == 0
            and #item.improvements > 0
        then
            return item.mat_type, item.mat_index, item
        end
    end
    return nil, nil, nil
end

-- ==========================================
-- BAG IMPROVEMENTS
-- ==========================================
-- Real bags have two improvements that describe their fabric:
--   [0] itemimprovement_clothst  — the woven cloth material
--   [1] itemimprovement_threadst — the thread material + dye info
--
-- Both share the same mat_type/mat_index as the bag itself.
-- Without these, DF can't describe the bag ("pigtail fiber bag")
-- and may not render its contents in the UI.
--
-- We clone these from a reference bag found in the game world.
-- ==========================================
local function apply_bag_improvements(bag, ref_bag)
    -- Clear any existing (incorrect) improvements
    bag.improvements:resize(0)

    for i = 0, #ref_bag.improvements - 1 do
        local src = ref_bag.improvements[i]

        -- Determine the improvement type and create a matching one.
        -- We can't just :assign() across types — we need to create
        -- the right subclass first, then copy fields.
        if df.itemimprovement_clothst:is_instance(src) then
            local imp = df.itemimprovement_clothst:new()
            imp.mat_type = bag.mat_type
            imp.mat_index = bag.mat_index
            imp.maker = -1
            imp.masterpiece_event = -1
            imp.quality = 0
            imp.skill_rating = 0
            imp.age_counter = 0
            bag.improvements:insert('#', imp)

        elseif df.itemimprovement_threadst:is_instance(src) then
            local imp = df.itemimprovement_threadst:new()
            imp.mat_type = bag.mat_type
            imp.mat_index = bag.mat_index
            imp.maker = -1
            imp.masterpiece_event = -1
            imp.quality = 0
            imp.skill_rating = 0
            imp.age_counter = 0
            -- The dye sub-struct needs to exist but can be empty
            -- (no dye applied). :new() should initialize it, but
            -- we explicitly set the "no dye" sentinel values.
            imp.dye.mat_type = -1
            imp.dye.mat_index = -1
            imp.dye.dyer = -1
            imp.dye.quality = 0
            imp.dye.skill_rating = 0
            imp.dye.age_counter = 0
            bag.improvements:insert('#', imp)
        end
    end
end

-- ==========================================
-- CACHED_INDEX FIX
-- ==========================================
-- general_refs on created items have cached_index = -1. Real
-- items have valid cached indices that point into the global
-- items vector. This is a lookup optimization cache that DF
-- uses for fast item-by-id resolution.
--
-- We can fix this by finding the item's position in the global
-- items.all vector and writing that index.
-- ==========================================
local function fix_cached_indices(item)
    -- For each general_ref on this item, if it has a cached_index
    -- field, find the target item's position in world.items.all
    for i = 0, #item.general_refs - 1 do
        local ref = item.general_refs[i]
        -- Both contains_itemst and contained_in_itemst have
        -- item_id and cached_index fields.
        if ref.cached_index == -1 and ref.item_id >= 0 then
            -- Linear scan to find the target item's vector index.
            -- This is O(n) but only runs once per fix operation.
            for idx, candidate in ipairs(df.global.world.items.all) do
                if candidate.id == ref.item_id then
                    ref.cached_index = idx
                    break
                end
            end
        end
    end
end

-- ==========================================
-- MAIN: PARSE ARGS AND APPLY FIXES
-- ==========================================
-- Manual arg parsing, same pattern as the rest of the RM tools.
-- Walks the {...} table looking for --bag and --powder flags,
-- captures the value immediately following each flag.
--
-- USAGE:
--   refinish-item-fix --bag 1530 --powder 1531,1532,1533,1534
-- ==========================================
local raw_args = {...}
local parsed = {}    -- will hold parsed.bag and parsed.powder

local i = 1
while i <= #raw_args do
    local arg = raw_args[i]
    if arg == "--bag" and raw_args[i + 1] then
        parsed.bag = raw_args[i + 1]
        i = i + 2
    elseif arg == "--powder" and raw_args[i + 1] then
        parsed.powder = raw_args[i + 1]
        i = i + 2
    else
        qerror("Unknown or incomplete argument: " .. tostring(arg))
    end
end

if not parsed.bag and not parsed.powder then
    print("Usage: refinish-item-fix --bag <id> --powder <id>[,<id>,...]")
    print("")
    print("Fixes malformed items created by dfhack.items.createItem().")
    print("Patches thermal properties, flags, weight, and bag material")
    print("to match naturally-created items.")
    print("")
    print("Options:")
    print("  --bag <id>            Bag item to fix (also gets material + improvements)")
    print("  --powder <id>[,...]   Powder item(s) to fix (comma-separated)")
    return
end

-- ---- FIND REFERENCE BAG FOR CLOTH MATERIAL ----
-- We need a real bag in the game world to copy cloth material
-- and improvements from. If none exists, we can still fix
-- thermal/flags/weight but the bag material stays wrong.
local ref_mat_type, ref_mat_index, ref_bag = find_cloth_bag_material()
if not ref_bag then
    print("[WARNING] No valid cloth bag found in game world.")
    print("  Bag material and improvements cannot be fixed.")
    print("  Thermal properties, flags, and weight will still be patched.")
end

-- ---- FIX BAG ----
if parsed.bag then
    local bag_id = tonumber(parsed.bag)
    if not bag_id then
        qerror("--bag must be a numeric item id")
    end

    local bag = df.item.find(bag_id)
    if not bag then
        qerror("No item found with id " .. bag_id)
    end
    if not df.item_bagst:is_instance(bag) then
        qerror("Item " .. bag_id .. " is not a bag")
    end

    print("Fixing bag item " .. bag_id .. "...")

    -- Fix cloth material (replace creature race with real cloth)
    if ref_bag then
        bag.mat_type = ref_mat_type
        bag.mat_index = ref_mat_index
        print("  Material: " .. bag.mat_type .. ":" .. bag.mat_index ..
              " (copied from reference bag " .. ref_bag.id .. ")")

        -- Apply cloth + thread improvements
        apply_bag_improvements(bag, ref_bag)
        print("  Improvements: " .. #bag.improvements .. " applied")
    end

    -- Fix thermal properties from the bag's (now corrected) material
    apply_thermal_from_material(bag, bag.mat_type, bag.mat_index)
    print("  Thermal: spec_heat=" .. bag.spec_heat ..
          " melting=" .. bag.melting_point ..
          " boiling=" .. bag.boiling_point)

    -- Fix temperature-system flags
    apply_flags_and_temp(bag)
    print("  Flags: [28]=true [29]=true temp_frame=" .. bag.temp_updated_frame)

    -- Fix weight
    apply_weight_from_density(bag, bag.mat_type, bag.mat_index)
    print("  Weight: " .. bag.weight.whole .. "." ..
          string.format("%06d", bag.weight.fraction))

    -- Fix cached indices on general_refs
    fix_cached_indices(bag)
    print("  Cached indices: fixed")
end

-- ---- FIX POWDER(S) ----
if parsed.powder then
    -- Support comma-separated list of powder ids
    local powder_ids = {}
    for id_str in parsed.powder:gmatch("[^,]+") do
        local id = tonumber(id_str)
        if not id then
            qerror("--powder ids must be numeric: '" .. id_str .. "'")
        end
        table.insert(powder_ids, id)
    end

    for _, powder_id in ipairs(powder_ids) do
        local powder = df.item.find(powder_id)
        if not powder then
            print("[WARNING] No item found with id " .. powder_id .. ", skipping")
        else
            print("Fixing powder item " .. powder_id .. "...")

            -- Fix thermal properties from the powder's own material
            apply_thermal_from_material(powder, powder.mat_type, powder.mat_index)
            print("  Thermal: spec_heat=" .. powder.spec_heat ..
                  " melting=" .. powder.melting_point ..
                  " boiling=" .. powder.boiling_point)

            -- Fix temperature-system flags
            apply_flags_and_temp(powder)
            print("  Flags: [28]=true [29]=true temp_frame=" .. powder.temp_updated_frame)

            -- Fix weight
            apply_weight_from_density(powder, powder.mat_type, powder.mat_index)
            print("  Weight: " .. powder.weight.whole .. "." ..
                  string.format("%06d", powder.weight.fraction))

            -- Fix cached indices on general_refs
            fix_cached_indices(powder)
            print("  Cached indices: fixed")
        end
    end
end

print("")
print("Done. Check bag contents in-game to verify display works.")
print("If contents still don't show, the remaining issue is likely")
print("the weight formula or a flag we haven't identified yet.")