-- probe-butcher.lua
-- ==========================================
-- BUTCHER OUTPUT PROBE
-- ==========================================
-- ONE QUESTION: what does a butcher job actually emit for one animal,
-- and is any of it proportional to the animal's size?
--
-- The claim to test is that DF gives one skin per animal flat, so a
-- rat and an elephant hand over the same hide. If that holds, the fix
-- is a product count correction on the REPLACE path scaled off
-- caste.misc.adult_size, the same measure the cremation work uses,
-- because getVolume() reports a flat 350 on corpses and cannot carry
-- the difference.
--
-- WHAT IT REPORTS, per butcher job:
--   the creature: race, caste, adult_size, and where that was read
--   every product: item type, material token, stack size, volume,
--     and corpse_flags where the product is a corpsepiece
--   a per material-tail tally, since skin, bone, fat and meat all
--     arrive as CORPSEPIECE and only the material tells them apart
--
-- THIS PROBE ONLY READS. It never writes to a job, an item or a
-- building.
--
-- IT STOPS ITSELF after MAX_JOBS observations and says so. A probe
-- left running in the scripts folder is how a stale CYCLE PROBE spent
-- a day pretending to be part of the module.
--
-- USAGE
--   probe-butcher          start watching
--   probe-butcher stop     stop early
--
-- HOW TO RUN IT
--   Start it, then butcher two animals of very different sizes. A rat
--   and anything large. Compare the skin counts and the adult_size
--   figures in the two blocks.
-- ==========================================

local repeatUtil = require('repeat-util')
local utils      = require('utils')
local eventful   = require('plugins.eventful')

local REPEAT_KEY = 'probe_butcher'
local EVENT_KEY  = 'probe_butcher_done'
local TAG        = 'BUTCHER PROBE: '

-- Stops on its own after this many jobs. Deliberately small.
local MAX_JOBS   = 5

local seen_jobs  = 0
local watching   = false

-- Snapshot per job id, taken while the job still exists.
-- After completion the job is gone and none of this can be re-read.
local snap = {}

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- ==========================================
-- READING A MATERIAL
-- ==========================================
-- matinfo rather than mat_type, because item_corpsepiecest carries no
-- material pair at all and reading mat_type on one throws. Returns the
-- full token and the tail after the last colon, which is the part that
-- separates BONE from SKIN from FAT on otherwise identical items.
-- ==========================================
local function mat_of(item)
    local tok = nil
    pcall(function()
        local mi = dfhack.matinfo.decode(item)
        tok = mi and mi:getToken() or nil
    end)
    if not tok then return '?', '?' end
    tok = tostring(tok)
    return tok, (tok:match('([^:]+)$') or '?')
end

-- ==========================================
-- THE CREATURE BEING BUTCHERED
-- ==========================================
-- Two routes, because butchering a corpse and butchering a live
-- animal do not present the same way. A corpse is an attached ITEM
-- carrying race and caste. A live animal is a general_ref pointing at
-- a unit. Both are tried and the probe says which one answered, so a
-- later fix knows which field to read rather than guessing.
-- ==========================================
local function creature_of(job)
    local race, caste, via = nil, nil, 'not found'

    -- Route 1: an attached corpse or corpsepiece item.
    for _, iref in ipairs(job.items) do
        pcall(function()
            local it = iref.item
            if it.race ~= nil and it.caste ~= nil then
                race, caste, via = it.race, it.caste, 'corpse item'
            end
        end)
        if race then break end
    end

    -- Route 2: a unit reference on the job.
    if not race then
        for _, ref in ipairs(job.general_refs) do
            pcall(function()
                local uid = ref.unit_id
                if uid then
                    local u = df.unit.find(uid)
                    if u then
                        race, caste, via = u.race, u.caste, 'unit ref'
                    end
                end
            end)
            if race then break end
        end
    end

    -- adult_size is the whole grown creature in DF's internal units,
    -- which are one tenth of the published wiki figures. It is the only
    -- number that separates a rat from an elephant, because getVolume()
    -- answers a flat 350 for every corpse regardless of what died.
    local size, name = -1, '?'
    if race then
        pcall(function()
            local c = df.global.world.raws.creatures.all[race]
            name = tostring(c.creature_id)
            size = c.caste[caste].misc.adult_size
        end)
    end
    return race, caste, via, name, size
end

-- ==========================================
-- SNAPSHOT: WHAT WAS IN THE SHOP BEFORE
-- ==========================================
-- Anything present after completion and absent here is this job's
-- output. Same technique the hijacker uses, and for the same reason:
-- highest item id would usually work and would be silently wrong the
-- one time two shops finish together.
-- ==========================================
local function take_snapshot(job)
    if snap[job.id] then return end

    local race, caste, via, name, size = creature_of(job)
    if not race then return end   -- nothing to compare against yet

    local before = {}
    local bid = nil
    pcall(function()
        local b = dfhack.job.getHolder(job)
        if not b then return end
        bid = b.id
        for _, ci in ipairs(b.contained_items) do
            pcall(function()
                if ci.item then before[ci.item.id] = true end
            end)
        end
    end)

    snap[job.id] = {
        before = before, bid = bid,
        race = race, caste = caste, via = via,
        name = name, size = size,
    }
end

-- ==========================================
-- REPORT: WHAT APPEARED
-- ==========================================
local function report(job)
    local s = snap[job.id]
    if not s then return end
    snap[job.id] = nil

    seen_jobs = seen_jobs + 1

    log(string.format(
        '---- job %d: %s (race %d caste %d, read via %s)  adult_size=%d',
        job.id, s.name, s.race, s.caste, s.via, s.size))

    local rows, tally, total = {}, {}, 0
    pcall(function()
        local b = df.building.find(s.bid)
        if not b then return end
        for _, ci in ipairs(b.contained_items) do
            pcall(function()
                local it = ci.item
                if not it or s.before[it.id] then return end

                local ty = tostring(df.item_type[it:getType()])
                local tok, tail = mat_of(it)

                -- ---- STACK SIZE IS THE WRONG FIELD ON A CORPSEPIECE ----
                -- stack_size reads 1 on every corpsepiece no matter how
                -- many bones are in the pile, which is why the first run
                -- of this probe reported a flat two bones off a
                -- groundhog and off a dragon alike. The real count lives
                -- in material_amount, the same field the bone
                -- consumption work measured decrementing when a stack
                -- was eaten into.
                --
                -- BOTH are printed, because which field carries the
                -- quantity depends on the item type and guessing that
                -- once already cost a run. MEAT and GLOB are genuine
                -- stacks and their stack_size is real.
                local stack = 1
                pcall(function() stack = it.stack_size or 1 end)

                local amount = 0
                pcall(function()
                    local ma = it.material_amount
                    for i = 0, #ma - 1 do
                        if ma[i] > amount then amount = ma[i] end
                    end
                end)

                -- The count that actually means something for this
                -- item: material_amount where it exists, stack_size
                -- otherwise.
                local qty = (amount > 0) and amount or stack
                local vol = -1
                pcall(function() vol = it:getVolume() end)

                -- corpse_flags is the other possible discriminator for
                -- a corpsepiece. Recorded so a later fix can choose
                -- between reading flags and reading the material tail.
                local flags = ''
                pcall(function()
                    local f = it.corpse_flags
                    if f then
                        local on = {}
                        for k, v in pairs(f) do
                            if v == true then table.insert(on, k) end
                        end
                        table.sort(on)
                        if #on > 0 then
                            flags = ' flags[' .. table.concat(on, ',') .. ']'
                        end
                    end
                end)

                total = total + qty
                tally[tail] = (tally[tail] or 0) + qty
                table.insert(rows, string.format(
                    '  %-13s qty=%-4d stack=%-3d amount=%-4d vol=%-6s %s%s',
                    ty, qty, stack, amount, tostring(vol), tok, flags))
            end)
        end
    end)

    if #rows == 0 then
        log('  nothing new in the shop. Products may drop to the floor'
            .. ' rather than into contained_items, which would mean the'
            .. ' count correction has to hook the products directly.')
    else
        table.sort(rows)
        for _, r in ipairs(rows) do log(r) end

        local parts = {}
        for tail, n in pairs(tally) do
            table.insert(parts, string.format('%s %d', tail, n))
        end
        table.sort(parts)
        log(string.format('  tally: %d item(s) total | %s',
            total, table.concat(parts, ', ')))
        -- Reported per tissue as well as in total, because the whole
        -- question is which ROWS scale with the animal and which do
        -- not. A single total hides a flat skin behind a varying
        -- muscle count.
        log(string.format('  per 1000 adult_size: %.4f unit(s) total',
            s.size > 0 and (total * 1000 / s.size) or 0))
        if s.size > 0 then
            local per = {}
            for tail, n in pairs(tally) do
                table.insert(per, string.format('%s %.4f',
                    tail, n * 1000 / s.size))
            end
            table.sort(per)
            log('  per 1000 adult_size, by tissue: ' ..
                table.concat(per, ', '))
        end
    end

    if seen_jobs >= MAX_JOBS then
        log(string.format('seen %d job(s), stopping myself. Restart with:'
            .. '  probe-butcher', seen_jobs))
        stop()
    end
end

-- ==========================================
-- THE WATCHER
-- ==========================================
-- Only the jobs list, which is short. No sweep over world items: the
-- last probe to do that polled every item in the fort twelve times a
-- second for an entire session.
-- ==========================================
local function poll()
    if not dfhack.isMapLoaded() then return end
    pcall(function()
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            if job.job_type == df.job_type.ButcherAnimal then
                take_snapshot(job)
            end
        end
    end)
end

local function on_completed(job)
    if not watching then return end
    pcall(function()
        if job.job_type == df.job_type.ButcherAnimal then
            report(job)
        end
    end)
end

-- ==========================================
-- LIFECYCLE
-- ==========================================
function start()
    seen_jobs, snap, watching = 0, {}, true
    eventful.onJobCompleted[EVENT_KEY] = on_completed
    repeatUtil.scheduleEvery(REPEAT_KEY, 10, 'frames', poll)
    log('watching butcher jobs. Butcher two animals of very different'
        .. ' sizes, a rat and something large.')
    log(string.format('stops itself after %d job(s). Stop early with:'
        .. '  probe-butcher stop', MAX_JOBS))
end

function stop()
    watching = false
    eventful.onJobCompleted[EVENT_KEY] = nil
    repeatUtil.cancel(REPEAT_KEY)
    snap = {}
    log('stopped.')
end

-- No `--@ module = true` on this file, deliberately. A module flagged
-- script that also calls start() at the bottom begins polling the
-- moment anything reqscripts it, which is how a probe nobody ran ends
-- up in a log for a day.
local cmd = ...
if cmd == 'stop' then stop() else start() end