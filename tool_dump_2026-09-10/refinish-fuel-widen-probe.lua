-- refinish-fuel-widen-probe.lua
-- ==========================================
-- FUEL FILTER WIDENING PROBE
-- ==========================================
-- Answers the last open question: will DF fetch and CONSUME a non
-- vanilla fuel for a hardcoded vanilla job when its fuel filter is
-- widened to match a reaction class instead of builtin coal.
--
-- Doing this by hand from the console does not work. A hauler claims
-- the coal within a few frames of the job posting, and once an item
-- is attached the filter no longer decides anything: the job already
-- holds what it needs. Every manual attempt is a race against a
-- dwarf who is already walking.
--
-- So this polls instead, and widens at posting time.
--
-- WHAT IS ALREADY PROVEN, from live cancellation messages:
--   DF reads reaction_class off a job filter and demands it by name
--   ("Needs FUEL_MINERAL item"), on a HARDCODED job with no reaction
--   object behind it. Class matching works.
--
-- WHAT WENT WRONG BEFORE:
--   vector_id was left at BAR (91), which is the vector DF searches.
--   Opening item_type while the search space stayed bars only meant
--   peat boulders were never considered. Confirmed against the
--   enum: 91 = BAR, 88 = ANY_MELT_DESIGNATED, 1 = IN_PLAY.
--
-- WHAT IS STILL UNKNOWN:
--   Whether the COMPLETION step honours the widened filter or
--   re-checks for coal by material. That is what this measures.
--
-- Read mostly. It writes only to posted job filters, which are
-- transient objects rebuilt every time a job posts. Nothing is
-- persisted, nothing is saved, and stopping the probe plus
-- cancelling any open job returns everything to stock behaviour.
--
-- Usage:
--   refinish-fuel-widen-probe start
--   refinish-fuel-widen-probe start ANY      broader vector
--   refinish-fuel-widen-probe stop
--   refinish-fuel-widen-probe status
--
-- TEST PROTOCOL
--   1. Leave coal available. Start the probe.
--   2. Queue a fuel using job at a NON magma workshop.
--   3. Watch which item the hauler brings. If it walks past coal and
--      picks up peat, fetching is proven.
--   4. Watch whether the job completes. That is the real answer.
-- ==========================================

local repeatUtil = require('repeat-util')

local REPEAT_KEY = 'refinish_fuel_widen_probe'
local LOG_TAG    = 'FUEL WIDEN: '

-- The class every widened filter demands. Peat, oil shale and
-- bitumen already carry this in inorganic_making_fuel.txt.
local FUEL_CLASS = 'FUEL_MINERAL'

local vector_choice = 'IN_PLAY'
local widened = {}      -- job id -> true, so each job logs once
local count   = 0

local function log(msg)
    if _G.refinish_log_event then
        _G.refinish_log_event(LOG_TAG .. msg)
    else
        print(LOG_TAG .. msg)
    end
end

-- ==========================================
-- FILTER IDENTIFICATION
-- ==========================================
-- The signature proven from live job dumps: a BAR of builtin COAL
-- with mat_index -1, meaning any coal subtype. Nothing else on a job
-- looks like this. The second test catches a filter this probe has
-- already widened, so a re-post is not treated as a new find.
-- ==========================================
local function is_fuel_filter(e)
    local hit = false
    pcall(function()
        if e.item_type == df.item_type.BAR
            and e.mat_type == df.builtin_mats.COAL then
            hit = true
        elseif tostring(e.reaction_class) == FUEL_CLASS then
            hit = true
        end
    end)
    return hit
end

-- ==========================================
-- THE WIDENING
-- ==========================================
-- Five fields. The first four open the filter; vector_id is the one
-- that actually matters, because it decides WHICH item vector DF
-- searches. Leaving it at BAR was why the earlier attempts found
-- nothing despite the class matching correctly.
-- ==========================================
local function widen(e)
    local ok = pcall(function()
        e.item_type      = -1
        e.item_subtype   = -1
        e.mat_type       = -1
        e.mat_index      = -1
        e.reaction_class = FUEL_CLASS
        e.vector_id      = df.job_item_vector_id[vector_choice]
    end)
    return ok
end

local function poll()
    if not dfhack.isMapLoaded() then return end
    local ok, err = pcall(function()
        local live = {}
        local link = df.global.world.jobs.list.next
        while link do
            local j = link.item
            if j then
                live[j.id] = true
                if not widened[j.id] then
                    -- Items already attached means a hauler claimed
                    -- something before this poll saw the job. Noted
                    -- in the log, because a job in that state cannot
                    -- prove anything either way.
                    local attached = 0
                    pcall(function() attached = #j.items end)

                    local hits = 0
                    pcall(function()
                        for i, e in ipairs(j.job_items.elements) do
                            if is_fuel_filter(e) and widen(e) then
                                hits = hits + 1
                            end
                        end
                    end)

                    if hits > 0 then
                        widened[j.id] = true
                        count = count + 1
                        pcall(function() j.recheck_cntdn = 0 end)
                        log(string.format(
                            'job %d %s: widened %d filter(s) to'
                            .. ' %s via %s%s',
                            j.id,
                            tostring(df.job_type[j.job_type]),
                            hits, FUEL_CLASS, vector_choice,
                            attached > 0 and string.format(
                                '  [WARNING: %d item(s) already'
                                .. ' attached, too late to matter]',
                                attached) or ''))
                    end
                end
            end
            link = link.next
        end
        -- Forget finished jobs so a re-post is logged fresh.
        for id in pairs(widened) do
            if not live[id] then widened[id] = nil end
        end
    end)
    if not ok then log('POLL ERROR: ' .. tostring(err)) end
end

-- ==========================================
-- COMMANDS
-- ==========================================
function start(vec)
    if vec and df.job_item_vector_id[vec] then
        vector_choice = vec
    end
    widened, count = {}, 0
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log(string.format(
        'active. Widening fuel filters to %s, searching %s (%d).',
        FUEL_CLASS, vector_choice,
        df.job_item_vector_id[vector_choice]))
    log('Queue a fuel using job at a non magma workshop and watch')
    log('which item the hauler brings.')
end

function stop()
    repeatUtil.cancel(REPEAT_KEY)
    widened = {}
    log(string.format('stopped after widening %d job(s).', count))
end

function status()
    local n = 0
    for _ in pairs(widened) do n = n + 1 end
    log(string.format(
        '%s, %d job(s) widened this session, %d currently open,'
        .. ' vector %s.',
        repeatUtil and 'running' or '?', count, n, vector_choice))
end

if dfhack_flags and dfhack_flags.module then return end
local args = {...}
if args[1] == 'start' then start(args[2])
elseif args[1] == 'stop' then stop()
elseif args[1] == 'status' then status()
else
    print('usage: refinish-fuel-widen-probe start [IN_PLAY|ANY]'
        .. ' | stop | status')
end
