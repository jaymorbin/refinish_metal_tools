--@ module = true
-- making-fuel-job-probe.lua
-- ==========================================
-- MAKING FUEL: STALLED JOB PROBE
-- ==========================================
-- READ ONLY. This script writes nothing, injects nothing, and does not
-- touch the RM log. Run it, copy the console output, delete it later.
--
-- WHAT IT IS FOR
--
-- A job with an open filter slot is not being filled even though
-- matching corpses exist on the map. The event log only prints counts,
-- which cannot tell the difference between two very different
-- failures:
--
--   1. DF IS LOOKING AND REFUSING. The filter is wrong, or the corpses
--      carry a flag that excludes them. Evidence: free corpses exist
--      with clean flags, and the filter has a field that does not
--      match them.
--
--   2. DF HAS STOPPED LOOKING. The filter is fine and would match, but
--      the job has left its collecting phase and will never revisit
--      the slots we added afterwards. Evidence: free corpses exist,
--      the filter matches them on every field, and the job carries a
--      flag saying it considers itself past collection.
--
-- The fix for those two is not remotely the same, which is why this
-- exists instead of another guess.
--
-- USAGE
--
--   :lua reqscript('making-fuel-job-probe').probe()
--
-- Run it while a job is visibly stalled, with corpses on the map.
-- ==========================================

local MODULE_PREFIX = 'MAKING_FUEL_RXN_'


-- ==========================================
-- SAFE READERS
-- ==========================================
-- Every field below is read through pcall. Some do not exist on every
-- DF build, and a probe that throws halfway through tells you less
-- than one that prints "<absent>" and carries on.
-- ==========================================
local function get(fn, fallback)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return fallback or '<absent>'
end

-- Lists the names of every flag set true in a bitfield, which is far
-- shorter to read than the whole struct.
local function set_flags(bits)
    local out = {}
    pcall(function()
        for k, v in pairs(bits) do
            if v == true then table.insert(out, k) end
        end
    end)
    table.sort(out)
    if #out == 0 then return '<none set>' end
    return table.concat(out, ',')
end

local function enum_name(enum, value)
    local ok, n = pcall(function() return enum[value] end)
    if ok and n then return tostring(n) .. '(' .. tostring(value) .. ')' end
    return tostring(value)
end


-- ==========================================
-- FILTER DUMP
-- ==========================================
-- job.job_items.elements is what DF reads when deciding what to fetch.
--
-- vector_id is the field to look at hardest. It names which item
-- vector DF searches for this slot. A clone that inherited the wrong
-- vector_id would look correct in every other field and still never
-- match anything, and nothing printed so far would have shown it.
-- ==========================================
local function dump_filters(job)
    local els = get(function() return job.job_items.elements end, nil)
    if type(els) == 'string' or els == nil then
        print('  FILTERS: <could not read job.job_items.elements>')
        return
    end

    print(string.format('  FILTERS: %d', #els))
    for i = 0, #els - 1 do
        local ji = els[i]
        print(string.format(
            '    [%d] itype=%s isub=%s mat=%s/%s qty=%s dim=%s'
            .. ' reagent_index=%s vector_id=%s',
            i,
            enum_name(df.item_type, get(function() return ji.item_type end, -1)),
            tostring(get(function() return ji.item_subtype end)),
            tostring(get(function() return ji.mat_type end)),
            tostring(get(function() return ji.mat_index end)),
            tostring(get(function() return ji.quantity end)),
            tostring(get(function() return ji.min_dimension end)),
            tostring(get(function() return ji.reagent_index end)),
            enum_name(df.job_item_vector_id,
                get(function() return ji.vector_id end, -1))))
        print('         flags1=' .. set_flags(get(function() return ji.flags1 end, {})))
        print('         flags2=' .. set_flags(get(function() return ji.flags2 end, {})))
        print('         flags3=' .. set_flags(get(function() return ji.flags3 end, {})))
    end
end


-- ==========================================
-- ATTACHED ITEM DUMP
-- ==========================================
-- role is the field that answers whether job.items fills on claim or
-- on delivery. Hauled means a dwarf is carrying it and it has not
-- arrived; Reagent means it is here. Everything I have assumed about
-- timing rests on this and it has never actually been read.
-- ==========================================
local function dump_attached(job)
    print(string.format('  ATTACHED: %d', #job.items))
    for i, iref in ipairs(job.items) do
        local item = get(function() return iref.item end, nil)
        local desc = '?'
        if type(item) ~= 'string' and item ~= nil then
            desc = get(function()
                return dfhack.items.getDescription(item, 0)
            end, '?')
        end
        print(string.format(
            '    [%d] job_item_idx=%s role=%s  %s',
            i,
            tostring(get(function() return iref.job_item_idx end)),
            enum_name(df.job_role_type,
                get(function() return iref.role end, -1)),
            tostring(desc)))
        if type(item) ~= 'string' and item ~= nil then
            print('         item flags=' ..
                set_flags(get(function() return item.flags end, {})))
        end
    end
end


-- ==========================================
-- CORPSE CENSUS
-- ==========================================
-- Why this has to be counted rather than assumed: a corpse can be on
-- the map and still be unavailable, and a bare count has never
-- distinguished "no corpses" from "corpses nobody will fetch".
--
-- FREE means: not already claimed by a job, not forbidden, not inside
-- a container or a unit, and lying on the ground or in a building.
-- That is not the same as pathable, which this cannot test, but it is
-- the set DF considers before it tries to path.
--
-- BLOCKED corpses now report WHERE they are. Seventeen contained
-- corpses tells us the open slot has nothing to fill it with. It does
-- not tell us why, and why is the only useful part.
-- ==========================================
local function describe_location(item)
    local bits = {}

    local unit = get(function() return dfhack.items.getHolderUnit(item) end, nil)
    if type(unit) ~= 'string' and unit ~= nil then
        table.insert(bits, 'held by unit ' .. tostring(get(function()
            return dfhack.units.getReadableName(unit) end,
            get(function() return unit.id end))))
    end

    local bld = get(function() return dfhack.items.getHolderBuilding(item) end, nil)
    if type(bld) ~= 'string' and bld ~= nil then
        table.insert(bits, 'in building ' .. enum_name(df.building_type,
            get(function() return bld:getType() end, -1)))
    end

    local cont = get(function() return dfhack.items.getContainer(item) end, nil)
    if type(cont) ~= 'string' and cont ~= nil then
        table.insert(bits, 'inside item ' .. tostring(get(function()
            return dfhack.items.getDescription(cont, 0) end, '?')))
    end

    local pos = get(function() return item.pos end, nil)
    if type(pos) ~= 'string' and pos ~= nil then
        table.insert(bits, string.format('at %s,%s,%s',
            tostring(get(function() return pos.x end)),
            tostring(get(function() return pos.y end)),
            tostring(get(function() return pos.z end))))
    end

    if #bits == 0 then return '<no holder, no position>' end
    return table.concat(bits, '  ')
end

local function census_corpses()
    local list
    local ok = pcall(function()
        list = df.global.world.items.other.CORPSE
    end)
    if not ok or not list then list = df.global.world.items.all end

    local total, free = 0, 0
    local counts = { in_job = 0, forbid = 0, contained = 0, not_placed = 0 }
    local free_samples, blocked_samples = {}, {}

    for _, item in ipairs(list) do
        if get(function() return item:getType() end, -1) == df.item_type.CORPSE then
            total = total + 1
            local f = item.flags
            local blocked = nil

            if get(function() return f.in_job end, false) then
                blocked = 'in_job'
            elseif get(function() return f.forbid end, false) then
                blocked = 'forbid'
            elseif get(function() return f.in_inventory end, false)
                or get(function() return f.in_chest end, false) then
                blocked = 'contained'
            elseif not get(function() return f.on_ground end, false)
                and not get(function() return f.in_building end, false) then
                blocked = 'not_placed'
            end

            if blocked then
                counts[blocked] = counts[blocked] + 1
                -- in_job corpses are already explained by the job dump
                -- above, so the samples focus on the ones that are not.
                if blocked ~= 'in_job' and #blocked_samples < 8 then
                    table.insert(blocked_samples, { item = item, why = blocked })
                end
            else
                free = free + 1
                if #free_samples < 5 then
                    table.insert(free_samples, item)
                end
            end
        end
    end

    print('')
    print('CORPSE CENSUS')
    print(string.format('  total=%d  FREE=%d', total, free))
    print(string.format('  blocked: in_job=%d forbid=%d contained=%d'
        .. ' not_placed=%d',
        counts.in_job, counts.forbid, counts.contained, counts.not_placed))

    if #free_samples > 0 then
        print('  FREE corpses, which an open slot should be taking:')
        for i, item in ipairs(free_samples) do
            print(string.format('    [%d] id=%s race=%s  %s',
                i,
                tostring(get(function() return item.id end)),
                tostring(get(function() return item.race end)),
                describe_location(item)))
            print('         flags=' .. set_flags(item.flags))
        end
    end

    if #blocked_samples > 0 then
        print('  BLOCKED corpses, where they actually are:')
        for i, rec in ipairs(blocked_samples) do
            local item = rec.item
            print(string.format('    [%d] %s  id=%s race=%s',
                i, rec.why,
                tostring(get(function() return item.id end)),
                tostring(get(function() return item.race end))))
            print('         ' .. describe_location(item))
            print('         flags=' .. set_flags(item.flags))
        end
    end
end


-- ==========================================
-- MAIN
-- ==========================================
function probe()
    if not dfhack.isMapLoaded() then
        print('PROBE: no map loaded.')
        return
    end

    local utils = require('utils')
    print('==========================================')
    print('MAKING FUEL JOB PROBE')
    print('==========================================')

    local found = 0
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.CustomReaction then
            local rname = tostring(job.reaction_name)
            if string.match(rname, '^' .. MODULE_PREFIX) then
                found = found + 1
                print('')
                print(string.format('JOB %d', job.id))
                print('  reaction_name = ' .. rname)

                -- Does the reaction the job names still exist, and how
                -- many reagents does it demand? Filters drive fetching
                -- and reagents drive completion; a mismatch here is a
                -- job that hauls correctly and then dies.
                local rxn = nil
                for _, r in ipairs(df.global.world.raws.reactions.reactions) do
                    if tostring(r.code) == rname then rxn = r; break end
                end
                if rxn then
                    print(string.format('  reaction FOUND, reagents=%d products=%d',
                        #rxn.reagents, #rxn.products))
                else
                    print('  reaction NOT FOUND in the reactions array.')
                end

                -- The flags that say what phase DF thinks this job is
                -- in. If collection is considered finished while slots
                -- are still open, that is the answer.
                print('  job.flags = ' .. set_flags(get(function()
                    return job.flags end, {})))
                print('  completion_timer = ' .. tostring(get(function()
                    return job.completion_timer end)))
                print('  worker = ' .. tostring(get(function()
                    return job.general_refs and #job.general_refs end)))

                dump_filters(job)
                dump_attached(job)
            end
        end
    end

    if found == 0 then
        print('No Making Fuel custom reaction jobs in the list.')
    end

    census_corpses()
    print('')
    print('==========================================')
end

return _ENV