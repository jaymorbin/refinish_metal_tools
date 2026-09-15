-- making-concrete-sand-diagnose-v2.lua
-- ==========================================
-- SAND BAG DISPLAY: SEQUENCE REPRODUCTION TEST
-- ==========================================
-- Attempts to reproduce the exact sequence from the working
-- console session where 4 sand displayed in a collect-sand bag.
--
-- The working session had a specific sequence on item 1122:
--   1. moveToContainer was called (it appeared to fail — bag
--      still showed 1 item — but it may have changed internal
--      state on the bag or item)
--   2. Manual containment refs were built on top
--   3. The item survived and displayed
--   4. Subsequent items created with manual refs only also displayed
--
-- HYPOTHESIS: moveToContainer modifies some internal state on
-- the bag (or the item) that manual refs alone don't set. Even
-- though it "fails" (doesn't complete containment), it primes
-- something that makes DF's renderer recognize the bag contents.
--
-- This script tests three approaches on the same bag:
--   Item 1: moveToContainer first, then manual refs (the 1122 path)
--   Item 2: manual refs only (the loop path)
--   Item 3: manual refs only (the loop path)
--
-- After running, check the bag view. If item 1's approach works
-- but 2/3 don't, the moveToContainer call is the trigger. If all
-- three work, the moveToContainer primed the bag for all of them.
--
-- USAGE:
--   1. Collect sand at the mason
--   2. Run: making-concrete-sand-diagnose-v2
--   3. Check the bag in the stockpile/building content view
--   4. Check sand_diag_v2.txt in your DF folder for the log
-- ==========================================

local LOG_FILE = "sand_diag_v2.txt"
local log_lines = {}

local function log(msg)
    local frame = df.global.cur_year_tick
    local line = string.format("[%d] %s", frame, msg)
    table.insert(log_lines, line)
    print(line)
end

local function flush_log()
    local f = io.open(LOG_FILE, "w")
    if f then
        f:write(table.concat(log_lines, "\n") .. "\n")
        f:close()
    end
end

-- ==========================================
-- FIND THE SAND BAG
-- ==========================================
local sand_bag = nil
local original_sand = nil

for _, item in ipairs(df.global.world.items.all) do
    if item:getType() == df.item_type.BAG then
        local contents = dfhack.items.getContainedItems(item)
        for _, c in ipairs(contents) do
            if c:getType() == df.item_type.POWDER_MISC
               and c.mat_type == 0 then
                local mat = df.global.world.raws.inorganics.all[c.mat_index]
                if mat and mat.flags.SOIL_SAND then
                    sand_bag = item
                    original_sand = c
                    break
                end
            end
        end
        if sand_bag then break end
    end
end

if not sand_bag or not original_sand then
    print("ERROR: No sand bag found. Collect sand first.")
    return
end

log("Sand bag found: id=" .. sand_bag.id)
log("Original sand: id=" .. original_sand.id
    .. " mat=" .. original_sand.mat_type .. ":" .. original_sand.mat_index
    .. " dim=" .. original_sand.dimension)
log("Bag contents before: " .. #dfhack.items.getContainedItems(sand_bag))

-- ==========================================
-- FIND A UNIT FOR ITEM CREATION
-- ==========================================
local unit = nil
for _, u in ipairs(df.global.world.units.active) do
    if dfhack.units.isCitizen(u) and dfhack.units.isAlive(u) then
        unit = u
        break
    end
end

if not unit then
    print("ERROR: No citizen found for item creation.")
    return
end

-- ==========================================
-- HELPER: Copy all material properties from original
-- ==========================================
local function copy_props(ni, o)
    ni.boiling_point      = o.boiling_point
    ni.colddam_point       = o.colddam_point
    ni.fixed_temp          = o.fixed_temp
    ni.heatdam_point       = o.heatdam_point
    ni.ignite_point        = o.ignite_point
    ni.melting_point       = o.melting_point
    ni.spec_heat           = o.spec_heat
    ni.temperature.whole   = o.temperature.whole
    ni.temperature.fraction = o.temperature.fraction
    ni.temp_updated_frame  = o.temp_updated_frame
    ni.weight.whole        = o.weight.whole
    ni.weight.fraction     = o.weight.fraction
    ni.dimension           = o.dimension
    ni.age                 = o.age
    ni.flags.temps_computed  = true
    ni.flags.weight_computed = true
end

-- ==========================================
-- HELPER: Build manual containment refs
-- ==========================================
local function build_refs(ni, bag)
    ni.flags.on_ground = false
    ni.flags.in_inventory = true
    ni.pos.x = -30000
    ni.pos.y = -30000
    ni.pos.z = -30000

    local ref_in = df.general_ref_contained_in_itemst:new()
    ref_in.item_id = bag.id
    ni.general_refs:insert('#', ref_in)

    local ref_has = df.general_ref_contains_itemst:new()
    ref_has.item_id = ni.id
    bag.general_refs:insert('#', ref_has)
end

-- ==========================================
-- ITEM 1: moveToContainer first, then manual refs
-- This is the exact path item 1122 took in the working session.
-- moveToContainer may prime bag state even though it "fails."
-- ==========================================
log("--- ITEM 1: moveToContainer + manual refs ---")

local result1 = dfhack.items.createItem(
    unit, df.item_type.POWDER_MISC, -1,
    original_sand.mat_type, original_sand.mat_index
)
local ni1 = result1[1]
log("Created id=" .. ni1.id .. " removed=" .. tostring(ni1.flags.removed)
    .. " gc=" .. tostring(ni1.flags.garbage_collect))

-- Clear death flags BEFORE moveToContainer attempt
ni1.flags.removed = false
ni1.flags.garbage_collect = false

-- Copy material properties BEFORE moveToContainer attempt
copy_props(ni1, original_sand)

-- Call moveToContainer — this is expected to "fail" (bag contents
-- won't increase) but it may change internal bag/item state that
-- we need for display to work.
local mtc_ok, mtc_err = pcall(dfhack.items.moveToContainer, ni1, sand_bag)
log("moveToContainer returned: ok=" .. tostring(mtc_ok)
    .. " err=" .. tostring(mtc_err))
log("Bag contents after moveToContainer: "
    .. #dfhack.items.getContainedItems(sand_bag))

-- Now check what moveToContainer did to the item's state
log("After moveToContainer — ni1 flags:"
    .. " removed=" .. tostring(ni1.flags.removed)
    .. " gc=" .. tostring(ni1.flags.garbage_collect)
    .. " on_ground=" .. tostring(ni1.flags.on_ground)
    .. " in_inventory=" .. tostring(ni1.flags.in_inventory)
    .. " in_building=" .. tostring(ni1.flags.in_building))
log("After moveToContainer — ni1 pos: "
    .. ni1.pos.x .. "," .. ni1.pos.y .. "," .. ni1.pos.z)
log("After moveToContainer — ni1 general_refs: " .. #ni1.general_refs)
for i = 0, #ni1.general_refs - 1 do
    log("  ref[" .. i .. "] " .. tostring(ni1.general_refs[i]._type)
        .. " item_id=" .. tostring(ni1.general_refs[i].item_id))
end

-- Check what moveToContainer did to the BAG's state
log("After moveToContainer — bag general_refs: " .. #sand_bag.general_refs)
for i = 0, #sand_bag.general_refs - 1 do
    log("  ref[" .. i .. "] " .. tostring(sand_bag.general_refs[i]._type)
        .. " item_id=" .. tostring(sand_bag.general_refs[i].item_id))
end

-- Now build manual refs on top (the step that completed the linkage
-- in the working session)
build_refs(ni1, sand_bag)
log("After manual refs — bag contents: "
    .. #dfhack.items.getContainedItems(sand_bag))

-- ==========================================
-- ITEMS 2 & 3: manual refs only (no moveToContainer)
-- This is the path the loop items took in the working session.
-- ==========================================
for i = 2, 3 do
    log("--- ITEM " .. i .. ": manual refs only ---")

    local result = dfhack.items.createItem(
        unit, df.item_type.POWDER_MISC, -1,
        original_sand.mat_type, original_sand.mat_index
    )
    local ni = result[1]
    log("Created id=" .. ni.id)

    ni.flags.removed = false
    ni.flags.garbage_collect = false
    copy_props(ni, original_sand)
    build_refs(ni, sand_bag)

    log("Bag contents now: " .. #dfhack.items.getContainedItems(sand_bag))
end

-- ==========================================
-- FINAL STATE DUMP
-- ==========================================
log("========== FINAL STATE ==========")
log("Bag " .. sand_bag.id .. " contents: "
    .. #dfhack.items.getContainedItems(sand_bag))

local contents = dfhack.items.getContainedItems(sand_bag)
for _, c in ipairs(contents) do
    log("  id=" .. c.id
        .. " dim=" .. c.dimension
        .. " removed=" .. tostring(c.flags.removed)
        .. " gc=" .. tostring(c.flags.garbage_collect)
        .. " in_inv=" .. tostring(c.flags.in_inventory)
        .. " on_ground=" .. tostring(c.flags.on_ground)
        .. " temps=" .. tostring(c.flags.temps_computed)
        .. " weight=" .. tostring(c.flags.weight_computed)
        .. " spec_heat=" .. c.spec_heat)
end

log("Bag flags:"
    .. " container=" .. tostring(sand_bag.flags.container)
    .. " on_ground=" .. tostring(sand_bag.flags.on_ground)
    .. " in_building=" .. tostring(sand_bag.flags.in_building))

flush_log()
print("")
print("=== DONE ===")
print("Log written to " .. LOG_FILE)
print("Now check the bag view — click away, click back.")
print("If items show: moveToContainer primes bag state.")
print("If not: the trigger is something else entirely.")
