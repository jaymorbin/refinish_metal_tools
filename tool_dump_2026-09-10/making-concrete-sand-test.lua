-- making-concrete-sand-test.lua
-- ==========================================
-- SAND MULTIPLIER END-TO-END TEST
-- ==========================================
-- Starts the onJobCompleted hook with full diagnostic logging.
-- Collect sand at the mason, then check sand_test_log.txt
-- in your DF folder.
--
-- Usage: making-concrete-sand-test
-- ==========================================

local eventful = require('plugins.eventful')
local LOG_PATH = 'sand_test_log.txt'
local CALLBACK_KEY = 'sand_multiply_test'
local COLLECT_SAND_JOB = 24

local log_file = io.open(LOG_PATH, 'w')
if not log_file then
    print("ERROR: Cannot open " .. LOG_PATH)
    return
end

local function log(msg)
    log_file:write("[" .. df.global.world.frame_counter .. "] " .. msg .. "\n")
    log_file:flush()
end

log("Sand multiplier test started")

eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 0)
eventful.onJobCompleted[CALLBACK_KEY] = function(job)
    log("Job completed: type=" .. job.job_type)

    if job.job_type ~= COLLECT_SAND_JOB then return end
    log("CollectSand job detected, id=" .. job.id)

    -- Find bag
    local bag = nil
    for i = 0, #job.items - 1 do
        local item = job.items[i].item
        if item then
            log("  job.items[" .. i .. "] type=" .. item:getType() .. " id=" .. item.id)
            if item:getType() == df.item_type.BAG then
                bag = item
            end
        else
            log("  job.items[" .. i .. "] nil")
        end
    end

    if not bag then
        log("ERROR: No bag found in job items")
        return
    end
    log("Bag found: id=" .. bag.id)

    -- Find original sand
    local contents = dfhack.items.getContainedItems(bag)
    log("Bag contents: " .. #contents .. " items")

    local original = nil
    for _, c in ipairs(contents) do
        log("  content id=" .. c.id .. " type=" .. c:getType() .. " mat=" .. c.mat_type .. ":" .. c.mat_index)
        if c:getType() == df.item_type.POWDER_MISC and c.mat_type == 0 then
            local mat = df.global.world.raws.inorganics.all[c.mat_index]
            if mat and mat.flags.SOIL_SAND then
                original = c
                log("  -> This is sand: " .. mat.id)
            end
        end
    end

    if not original then
        log("ERROR: No sand powder found in bag")
        return
    end

    if #contents >= 4 then
        log("SKIP: Bag already has " .. #contents .. " items, no multiply needed")
        return
    end

    -- Find unit
    local unit = nil
    for _, u in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(u) and dfhack.units.isAlive(u) then
            unit = u
            break
        end
    end
    if not unit then
        log("ERROR: No citizen unit found")
        return
    end
    log("Unit found: id=" .. unit.id)

    -- Create 3 extra sand
    local created = 0
    for i = 1, 3 do
        log("Creating item " .. i .. "...")

        local ok, result = pcall(dfhack.items.createItem,
            unit, df.item_type.POWDER_MISC, -1,
            original.mat_type, original.mat_index)

        if not ok then
            log("ERROR: createItem failed: " .. tostring(result))
        elseif not result or not result[1] then
            log("ERROR: createItem returned nil or empty table")
        else
            local ni = result[1]
            log("  Created id=" .. ni.id .. " removed=" .. tostring(ni.flags.removed) .. " gc=" .. tostring(ni.flags.garbage_collect))

            -- Fix death flags
            ni.flags.removed = false
            ni.flags.garbage_collect = false
            ni.flags.on_ground = false
            ni.flags.in_inventory = true

            -- Copy thermal properties
            ni.flags.temps_computed = true
            ni.flags.weight_computed = true
            ni.boiling_point = original.boiling_point
            ni.colddam_point = original.colddam_point
            ni.fixed_temp = original.fixed_temp
            ni.heatdam_point = original.heatdam_point
            ni.ignite_point = original.ignite_point
            ni.melting_point = original.melting_point
            ni.spec_heat = original.spec_heat
            ni.temperature.whole = original.temperature.whole
            ni.temperature.fraction = original.temperature.fraction
            ni.temp_updated_frame = original.temp_updated_frame
            ni.weight.whole = original.weight.whole
            ni.weight.fraction = original.weight.fraction
            ni.dimension = original.dimension
            ni.age = original.age

            -- Set contained position
            ni.pos.x = -30000
            ni.pos.y = -30000
            ni.pos.z = -30000

            -- Build containment refs
            local ref_in = df.general_ref_contained_in_itemst:new()
            ref_in.item_id = bag.id
            ni.general_refs:insert('#', ref_in)

            local ref_has = df.general_ref_contains_itemst:new()
            ref_has.item_id = ni.id
            bag.general_refs:insert('#', ref_has)

            log("  Linked into bag. ni.removed=" .. tostring(ni.flags.removed) .. " ni.gc=" .. tostring(ni.flags.garbage_collect) .. " ni.in_inv=" .. tostring(ni.flags.in_inventory))

            created = created + 1
        end
    end

    -- Verify
    local final_contents = dfhack.items.getContainedItems(bag)
    log("DONE: Created " .. created .. " items. Bag now has " .. #final_contents .. " items.")
    for _, c in ipairs(final_contents) do
        log("  final: id=" .. c.id .. " removed=" .. tostring(c.flags.removed) .. " gc=" .. tostring(c.flags.garbage_collect))
    end
end

print("Sand multiply test active. Collect sand, then check " .. LOG_PATH)
