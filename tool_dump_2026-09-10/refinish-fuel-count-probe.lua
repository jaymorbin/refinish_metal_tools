--@ module = true
-- refinish-fuel-count-probe.lua
-- ==========================================
-- DOES A WIDENED FUEL FILTER SURVIVE count > 1
-- ==========================================
-- THE ONE OPEN QUESTION behind charging plain FUEL more than
-- FUEL_SMELTING at the same furnace.
--
-- The header of making-fuel-fuel-access records "do not retry:
-- reagent quantity edits (spurious peat bar out of a melt)". That
-- verdict came from a single run where the count was set to 3 with
-- ONE peat reachable in the whole fort. One peat attached, the
-- filter stayed short, and the melt emitted a steel bar AND a peat
-- bar. The note written at the time said so plainly: worth one
-- retest with plenty of peat reachable, to separate "could not fill
-- 3" from "count > 1 breaks it". That retest never happened, and
-- everything downstream has been built around the verdict rather
-- than the measurement.
--
-- This probe is that retest. It changes nothing permanently and
-- ships nothing; it stamps a count onto fuel filters that
-- making-fuel-fuel-access has already widened, then reports what DF
-- does with them.
--
-- ---- WHAT IT ANSWERS ----
--   Q1  With supply plentiful, does DF fetch N items onto one
--       widened fuel filter and complete the job cleanly?
--   Q2  Does anything spurious come out? Every item created in the
--       20 frames after a probed job completes is named, so a
--       second peat bar cannot hide.
--   Q3  WHEN does the fuel filter get covered relative to the
--       job's other filters? This decides whether a count could
--       ever be raised on the fly instead of being set at posting.
--       The ghost has already measured that appended slots are
--       honoured while collection is open and ignored once it is
--       not, so if fuel routinely lands LAST, the on the fly design
--       is a race and must not be built.
--
-- ---- WHAT IT DELIBERATELY DOES NOT DO ----
-- It does not hook onJobInitiated. making-fuel-fuel-access already
-- owns that event, handler order between two listeners on the same
-- event is not something this file should depend on, and the probe
-- must run strictly AFTER the widen or it would be stamping a
-- vanilla BAR/COAL filter and measuring the wrong thing. The poll
-- recognises an already widened filter by its reaction class, which
-- is the same test the access script uses.
--
-- ---- HOW TO RUN IT ----
--   1. Make sure Making Fuel is running and fuel access is active.
--   2. Stock the fort with WELL MORE than N of one plain fuel, and
--      ideally nothing else burnable, so there is no doubt what got
--      fetched. Dried dung, dried peat or kindling all qualify.
--   3. refinish-fuel-count-probe start 4
--   4. Queue a kiln job. Watch the log.
--   5. refinish-fuel-count-probe stop
--
-- Console only, on purpose. This is an instrument, not a feature.
-- ==========================================

local eventful   = require('plugins.eventful')
local repeatUtil = require('repeat-util')

local REPEAT_KEY = 'refinish_fuel_count_probe'
local LOG_TAG    = 'FUEL COUNT PROBE: '

local tuning = nil
pcall(function() tuning = reqscript('making-fuel-tuning') end)

local function T()
    return (tuning and tuning.T) or {}
end

local function log(msg)
    print(LOG_TAG .. msg)
    if _G.refinish_log_event then
        _G.refinish_log_event(LOG_TAG .. msg)
    end
end

-- ==========================================
-- STATE
-- ==========================================
-- tracked[job_id] = {
--   idx      index of the fuel filter in job_items.elements
--   n_base   how many filters the job was born with
--   want     the count this probe stamped
--   last     last reported line, so the log only speaks on change
--   fuel_at  the poll tick fuel first covered its filter
--   full_at  the poll tick every base filter was covered
-- }
local tracked   = {}
local running   = false
local want_n    = 4
local tick      = 0
local watch_new = 0        -- frames left in the item creation window
local n_stamped = 0

-- ==========================================
-- READING A JOB
-- ==========================================
-- The fuel filter is the one making-fuel-fuel-access rewrote. It is
-- recognised exactly as that script recognises its own work: the
-- reaction class equals one of the two tier classes. job_item's
-- reaction_class is a plain string field, unlike material's, which
-- is a vector of string pointers; tostring() is correct here and
-- wrong there.
local function fuel_filter_index(j)
    local found = nil
    pcall(function()
        local prim  = T().FUEL_CLASS
        local smith = T().FUEL_SMITH_CLASS
        for i, e in ipairs(j.job_items.elements) do
            local rc = tostring(e.reaction_class)
            if (prim and rc == prim) or (smith and rc == smith) then
                found = i
                return
            end
        end
    end)
    return found
end

-- Which filter indices currently hold at least one item. Coverage,
-- not item count: DF attaches spares to satisfied filters and
-- sometimes attaches at index -1, so counting items answers a
-- different question than the one being asked.
local function coverage(j)
    local cov = {}
    pcall(function()
        for _, iref in ipairs(j.items) do
            local i = iref.job_item_idx
            if i and i >= 0 then cov[i] = (cov[i] or 0) + 1 end
        end
    end)
    return cov
end

local function all_covered(cov, n_base)
    for i = 0, n_base - 1 do
        if not cov[i] then return false end
    end
    return true
end

local function token_of(item)
    local tok = '?'
    pcall(function()
        local mi = dfhack.matinfo.decode(item)
        if mi then tok = tostring(mi:getToken()) end
    end)
    return tok
end

local function job_name(j)
    local s = '?'
    pcall(function() s = tostring(df.job_type[j.job_type]) end)
    return s
end

-- ==========================================
-- THE POLL
-- ==========================================
local function poll()
    if not dfhack.isMapLoaded() then return end
    tick = tick + 1
    if watch_new > 0 then watch_new = watch_new - 1 end

    local live = {}
    local ok, err = pcall(function()
        local l = df.global.world.jobs.list.next
        while l do
            local j = l.item
            if j then
                live[j.id] = true
                local st = tracked[j.id]

                if not st then
                    -- ---- FIRST SIGHTING ----
                    -- Stamp once, and only a filter that has been
                    -- widened already. recheck_cntdn is zeroed so DF
                    -- re-evaluates the job on the next opportunity
                    -- rather than at its own leisure, which is what
                    -- the access script does after widening.
                    local idx = fuel_filter_index(j)
                    if idx then
                        local n_el, before = 0, 0
                        pcall(function()
                            n_el   = #j.job_items.elements
                            before = j.job_items.elements[idx].count
                            j.job_items.elements[idx].count = want_n
                            j.recheck_cntdn = 0
                        end)
                        tracked[j.id] = {
                            idx = idx, n_base = n_el, want = want_n,
                            last = '', fuel_at = nil, full_at = nil,
                        }
                        n_stamped = n_stamped + 1
                        log(string.format(
                            'job %d %s: fuel filter at index %d of'
                            .. ' %d, count %d -> %d',
                            j.id, job_name(j), idx, n_el,
                            before, want_n))
                    end
                else
                    -- ---- TRACKING ----
                    local cov = coverage(j)
                    local on_fuel = cov[st.idx] or 0
                    if on_fuel > 0 and not st.fuel_at then
                        st.fuel_at = tick
                    end
                    if not st.full_at
                       and all_covered(cov, st.n_base) then
                        st.full_at = tick
                    end

                    local line = string.format(
                        'fuel %d/%d, filters covered %d/%d',
                        on_fuel, st.want,
                        (function()
                            local n = 0
                            for i = 0, st.n_base - 1 do
                                if cov[i] then n = n + 1 end
                            end
                            return n
                        end)(), st.n_base)
                    if line ~= st.last then
                        st.last = line
                        log(string.format('job %d: %s', j.id, line))
                    end
                end
            end
            l = l.next
        end
    end)
    if not ok then log('POLL ERROR: ' .. tostring(err)) end

    -- ---- DEPARTURE ----
    -- A job leaving the list is either done or cancelled, and the
    -- ordering tells the Q3 story: fuel first or fuel last.
    for id, st in pairs(tracked) do
        if not live[id] then
            log(string.format(
                'job %d left the list. fuel covered at tick %s,'
                .. ' all filters covered at tick %s.',
                id, tostring(st.fuel_at), tostring(st.full_at)))
            if st.fuel_at and st.full_at
               and st.fuel_at >= st.full_at then
                log(string.format(
                    'job %d: FUEL LANDED LAST. A count raised on'
                    .. ' attach would have missed this job.', id))
            end
            tracked[id] = nil
        end
    end
end

-- ==========================================
-- COMPLETION AND THE SPURIOUS PRODUCT WINDOW
-- ==========================================
-- The job handed to onJobCompleted is a COPY, so it is safe to read
-- and pointless to write. Every attached item is named here, and
-- the item creation window opens so anything DF mints in the next
-- 20 frames says what it is. That is how a second peat bar gets
-- caught by name rather than by someone noticing it in a stockpile
-- a week later.
local function on_completed(j)
    pcall(function()
        local st = tracked[j.id]
        if not st then return end
        local parts = {}
        for _, iref in ipairs(j.items) do
            table.insert(parts, string.format('[%d]%s',
                iref.job_item_idx, token_of(iref.item)))
        end
        log(string.format('job %d COMPLETED consuming: %s',
            j.id, table.concat(parts, ' ')))
        watch_new = 20
    end)
end

local function on_created(item_id)
    if watch_new <= 0 then return end
    pcall(function()
        local it = df.item.find(item_id)
        if not it then return end
        log(string.format('  created: %s %s',
            tostring(df.item_type[it:getType()]), token_of(it)))
    end)
end

-- ==========================================
-- PUBLIC API
-- ==========================================
function start(n)
    want_n = tonumber(n) or 4
    tracked, tick, watch_new, n_stamped = {}, 0, 0, 0
    running = true
    eventful.onJobCompleted[REPEAT_KEY] = on_completed
    eventful.onItemCreated[REPEAT_KEY]  = on_created
    -- Frequency 0 on completion is what separates a finished job
    -- from a cancelled one, per the eventful contract.
    eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 0)
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, 0)
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log(string.format('active. Every widened fuel filter will be'
        .. ' stamped to count %d.', want_n))
    log('Stock well more than that of ONE plain fuel before testing.')
end

function stop()
    running = false
    eventful.onJobCompleted[REPEAT_KEY] = nil
    eventful.onItemCreated[REPEAT_KEY]  = nil
    repeatUtil.cancel(REPEAT_KEY)
    log(string.format('stopped. %d filter(s) stamped this run.',
        n_stamped))
    tracked = {}
end

function status()
    print(string.format('%srunning=%s want=%d stamped=%d tracked=%d',
        LOG_TAG, tostring(running), want_n, n_stamped,
        (function()
            local n = 0
            for _ in pairs(tracked) do n = n + 1 end
            return n
        end)()))
    print(string.format('  primary %s | smith %s',
        tostring(T().FUEL_CLASS), tostring(T().FUEL_SMITH_CLASS)))
end

if dfhack_flags and dfhack_flags.module then return end
local args = {...}
if args[1] == 'start' then start(args[2])
elseif args[1] == 'stop' then stop()
elseif args[1] == 'status' then status()
else
    print('usage: refinish-fuel-count-probe start [N] | stop | status')
end
