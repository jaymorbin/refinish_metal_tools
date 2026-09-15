-- refinish-perf-probe.lua
-- ==========================================
-- SCRIPT LOGIC: REFINISH PERF PROBE (v4, TWO MECHANISMS)
-- ==========================================
-- Times every repeat-util loop in the session and reports
-- milliseconds per wall second per loop, so the frame budget stops
-- being an estimate.
--
-- ---- WHAT EACH VERSION GOT WRONG, SO IT STAYS FIXED ----
--
-- v1 replaced repeat-util's scheduleEvery and relied on the module
-- being restarted so its loops would re-register through the
-- replacement. There is no such restart: making_fuel.lua takes no
-- arguments, and its loops start inside run_module_pipeline() at map
-- load. Nothing re-registered, so nothing was timed.
--
-- v2 adopted live timers instead, which is the right mechanism, but
-- it read v1's leftover state out of _G and assumed its own field
-- shape. v1 wrote {calls, ms, max_ms, rebinds}; v2 wanted `adopts`,
-- found nil, and threw. v3 makes state shape a non-issue: slot()
-- backfills any missing field, and a state block from another
-- version is retired rather than inherited.
--
-- v2 also had two latent faults worth naming, both fixed here:
--   ORPHANED COUNTERS. Each wrapper captured its stats table, so
--   wiping stats left live wrappers counting into tables nobody
--   read. Counters are now looked up BY NAME at fire time, so a
--   wipe can never silently undercount.
--   DOUBLE WRAPPING. reset() cleared the wrapper registry while the
--   wrappers were still installed, so the next adopt would wrap a
--   wrapper and count every fire twice. Every wrapper is now
--   recorded in an identity set and is never wrapped again.
--
-- v3 measured only repeat-util loops. RM CORE DOES NOT USE
-- repeat-util: refinish_steel.lua, refinish-module-inject-building
-- and refinish-menu-icons all self chain raw dfhack.timeout, which
-- never appears in repeat-util's registry. So RM's own load was
-- invisible to the probe, which is why not one refinish key showed
-- up in a 32 row status listing. v4 adds that second mechanism.
--
-- ---- HOW IT WORKS: TWO MECHANISMS ----
--
-- MECHANISM 1, ADOPTION, for repeat-util loops.
-- dfhack.timeout_active(id, new_callback) replaces a live timer's
-- callback, so a loop scheduled minutes ago at map load can be
-- wrapped right now: no restart, no recycle, no ordering rules.
--
-- MECHANISM 2, INTERCEPTION, for self chaining dfhack.timeout loops.
-- There is no registry to walk, so dfhack.timeout itself is wrapped.
-- A self chaining loop re-registers on every fire, so it is caught
-- on its next iteration and stays caught. Rows are named by where
-- the callback is DEFINED, as t:<file>:<line>, because these loops
-- have no keys to be named by.
--
-- THE TWO MUST NOT OVERLAP. repeat-util registers through
-- dfhack.timeout as well, so a repeat-util loop would be counted by
-- both. Mechanism 2 therefore skips any registration whose CALLER is
-- repeat-util, leaving those to adoption. If that skip ever fails a
-- t:repeat-util.lua row appears in the report, which is the tell.
--
-- USAGE (console), with the fort running:
--   refinish-perf-probe arm       adopt every live loop, start window
--   refinish-perf-probe status    what was found and adopted
--   ...let the fort run UNPAUSED for 30+ seconds...
--   refinish-perf-probe report    the table, sorted by cost
--   refinish-perf-probe reset     zero counters, stay adopted
--   refinish-perf-probe disarm    hand every loop back
--
-- WHAT THE TIME INCLUDES. The adopted callback is repeat-util's own
-- repeating helper, so each sample covers the poll body plus one
-- dfhack.timeout re-registration. That overhead is a rounding error
-- next to the loops this exists to weigh, and counting it is the
-- honest choice: it is real cost the loop imposes.
--
-- RESOLUTION. dfhack.getTickCount() is milliseconds. A loop whose
-- calls all read 0 costs under 1 ms each; the report's bound column
-- prints the most such a loop could still be hiding.
-- ==========================================

local repeatUtil = require('repeat-util')

local VERSION = 4

local function log(msg)
    if _G.refinish_log_event then
        _G.refinish_log_event('PERF PROBE: ' .. msg)
    end
    print('PERF PROBE: ' .. msg)
end

-- ==========================================
-- STATE
-- ==========================================
-- Lives in _G so adoptions and counters survive re-running this
-- script. Wall clock based, so a reload mid window just keeps
-- accumulating.
--
--   stats       repeat key -> {calls, ms, max_ms, adopts}
--   wrappers    repeat key -> the timing function installed for it
--   is_wrapper  wrapper function -> repeat key (identity set)
--   origins     repeat key -> the callback displaced, for disarm
--   reg         repeat-util's live timer registry, once found
_G.refinish_perf_probe = _G.refinish_perf_probe or {}
local P = _G.refinish_perf_probe

-- ---- RETIRING AN OLDER STATE BLOCK ----
-- A state block written by another version may hold rows in a shape
-- this build does not understand, and mixing its numbers into a new
-- report would be worse than losing them. Counters go; the wrapper
-- identity set is KEPT, because those wrappers are still installed
-- on live timers and forgetting them is what causes double wrapping.
if P.version ~= VERSION then
    if P.orig then
        -- v1 left its replacement on scheduleEvery. Left there it
        -- would wrap future registrations and double count them
        -- against adoption, so it goes back first.
        repeatUtil.scheduleEvery = P.orig
        P.orig = nil
        log('v1 scheduleEvery patch found and removed.')
    end
    if P.stats and next(P.stats) then
        log(('state from an older probe version retired (%d row(s)'
            .. ' dropped).'):format((function()
                local n = 0
                for _ in pairs(P.stats) do n = n + 1 end
                return n
            end)()))
    end
    P.stats = {}
    P.t0 = nil
    P.version = VERSION
end

P.stats      = P.stats      or {}
P.wrappers   = P.wrappers   or {}
P.is_wrapper = P.is_wrapper or {}
P.origins    = P.origins    or {}
P.armed      = P.armed      or false
P.reg        = P.reg        or nil
P.sweep_id   = P.sweep_id   or nil
P.t0         = P.t0         or nil

-- Returns the counter row for a key, creating it if absent and
-- BACKFILLING any field it is missing. The backfill is why a shape
-- change can never throw again: a row from any version is repaired
-- on first touch rather than trusted.
local function slot(key)
    local s = P.stats[key]
    if not s then
        s = {}
        P.stats[key] = s
    end
    s.calls  = s.calls  or 0
    s.ms     = s.ms     or 0
    s.max_ms = s.max_ms or 0
    s.adopts = s.adopts or 0
    return s
end

local function count(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- ==========================================
-- FINDING THE REGISTRY
-- ==========================================
-- repeat-util keeps its live timers in a table inside its module,
-- mapping repeat key to timer id. The field name is not documented
-- anywhere in the DFHack docs bundled with this project, so it is
-- DISCOVERED rather than assumed: walk the module's own fields and
-- accept the first table whose string keys hold values that
-- dfhack.timeout_active resolves to a live function. That test is
-- the definition of a timer id, so a false positive would have to
-- be a table of live timer ids, which is the thing being looked for.
local function find_registry()
    if P.reg then return P.reg end
    for _, v in pairs(repeatUtil) do
        if type(v) == 'table' then
            for k, id in pairs(v) do
                if type(k) == 'string'
                   and type(dfhack.timeout_active(id)) == 'function' then
                    P.reg = v
                    return v
                end
            end
        end
    end
    return nil
end

-- ==========================================
-- ADOPTION
-- ==========================================
-- Install a timing wrapper as the live callback for one repeat key.
--
-- THE RE-ADOPT IS THE WHOLE TRICK. repeat-util's helper reschedules
-- itself on every fire, and the new timer carries the ORIGINAL
-- helper as its callback, not ours. So after calling it, the key's
-- new id is looked up and the wrapper installed again. Miss this
-- and the probe times exactly one fire per loop, then goes quiet.
-- If a report ever shows every row at calls=1, this is the line
-- that stopped working.
local function adopt(name)
    local reg = P.reg
    if not reg then return false end

    local id = reg[name]
    local cb = dfhack.timeout_active(id)
    if type(cb) ~= 'function' then return false end

    -- Already one of ours, possibly installed by an earlier run of
    -- this script. Re-point the name at it and stop: wrapping a
    -- wrapper counts every fire twice and nests the timing.
    if P.is_wrapper[cb] then
        P.wrappers[name] = cb
        return false
    end

    slot(name).adopts = slot(name).adopts + 1
    P.origins[name] = cb

    local w
    w = function()
        -- Looked up by NAME, not captured. A counter wipe therefore
        -- cannot orphan this wrapper's numbers.
        local s = slot(name)

        local t = dfhack.getTickCount()
        -- pcall so a throwing poll still gets its time booked and
        -- still gets re-adopted; the error is rethrown below so
        -- repeat-util sees exactly what it would have seen without
        -- the probe in the way.
        local ok, err = pcall(cb)
        local dt = dfhack.getTickCount() - t

        s.calls = s.calls + 1
        s.ms = s.ms + dt
        if dt > s.max_ms then s.max_ms = dt end

        -- Re-adopt on the id the helper just created. A nil here
        -- means the loop cancelled itself, which is a legitimate end
        -- of life: stop chasing it and let the sweep notice.
        local nid = reg[name]
        if nid ~= nil and dfhack.timeout_active(nid) ~= nil then
            dfhack.timeout_active(nid, w)
        end

        if not ok then error(err, 0) end
    end

    P.wrappers[name] = w
    P.is_wrapper[w] = name
    dfhack.timeout_active(id, w)
    return true
end

-- Adopt everything currently registered, and pick up anything that
-- slipped: a loop cancelled and rescheduled carries a fresh helper
-- again, and a module started after arm was never adopted at all.
-- Returns how many were newly taken.
local function adopt_all()
    if not find_registry() then return 0 end
    local n = 0
    for name in pairs(P.reg) do
        -- pcall per key so one awkward entry cannot abort the walk
        -- and leave the set half adopted, which is exactly what the
        -- v2 crash did.
        local ok, took = pcall(adopt, name)
        if ok and took then n = n + 1
        elseif not ok then
            log(('could not adopt %q: %s'):format(tostring(name),
                tostring(took)))
        end
    end
    return n
end

-- ==========================================
-- MECHANISM 2: INTERCEPTING dfhack.timeout
-- ==========================================
-- Only the file name, so a row reads refinish_steel.lua:695 rather
-- than a full Windows path that wraps the terminal.
local function basename(p)
    return tostring(p):match('([^/\\]+)$') or tostring(p)
end

-- Where a callback was DEFINED, which is the only stable name a raw
-- timeout loop has. Cached on the function itself with WEAK KEYS:
-- a self chaining loop passes the same function object every fire,
-- so this is one debug.getinfo per loop rather than one per fire,
-- and closures built fresh each iteration can still be collected.
local site_cache = setmetatable({}, { __mode = 'k' })

local function site_of(cb)
    local k = site_cache[cb]
    if k then return k end
    local ok, info = pcall(debug.getinfo, cb, 'S')
    if ok and info then
        k = ('t:%s:%d'):format(basename(info.short_src),
                               info.linedefined or 0)
    else
        k = 't:unknown'
    end
    site_cache[cb] = k
    return k
end

local function patch_timeout()
    if P.real_timeout then return end
    -- Attribution and the repeat-util skip both depend on the debug
    -- library. Without it this mechanism cannot tell one loop from
    -- another or avoid double counting, so it declines to run rather
    -- than report something it cannot stand behind.
    if not (debug and debug.getinfo) then
        log('debug.getinfo unavailable; self chaining timeout loops'
            .. ' will NOT be measured.')
        return
    end
    P.real_timeout = dfhack.timeout

    dfhack.timeout = function(t, mode, cb)
        if type(cb) ~= 'function' then
            return P.real_timeout(t, mode, cb)
        end

        -- ---- WHO IS ASKING ----
        -- repeat-util's registrations belong to adoption, and the
        -- probe's own sweep belongs to nobody. Wrapping either here
        -- would double count it.
        --
        -- NOT THROUGH pcall. debug.getinfo counts stack levels from
        -- ITSELF, so pcall(debug.getinfo, 2, ...) puts pcall's own C
        -- frame at level 1 and resolves level 2 to this wrapper
        -- instead of its caller. That read this file's own name for
        -- every registration, matched the self skip below, and
        -- silently declined to wrap anything at all. Called directly,
        -- level 2 is the caller. An out of range level returns nil
        -- rather than throwing, so the pcall bought nothing.
        local info = debug.getinfo(2, 'S')
        local caller = info and basename(info.short_src) or ''
        if P.is_wrapper[cb]
           or caller:find('repeat%-util')
           or caller:find('refinish%-perf%-probe') then
            return P.real_timeout(t, mode, cb)
        end

        local name = site_of(cb)
        local w = function(...)
            local s = slot(name)
            local t0 = dfhack.getTickCount()
            local ok2, err = pcall(cb, ...)
            local dt = dfhack.getTickCount() - t0
            s.calls = s.calls + 1
            s.ms = s.ms + dt
            if dt > s.max_ms then s.max_ms = dt end
            if not ok2 then error(err, 0) end
        end
        -- No re-adopt needed here, unlike mechanism 1: a self
        -- chaining loop calls dfhack.timeout again from inside cb,
        -- and that call comes straight back through this wrapper.
        return P.real_timeout(t, mode, w)
    end
end

local function unpatch_timeout()
    if not P.real_timeout then return end
    -- Only if ours is still the one standing. Timers already
    -- registered keep their wrappers until they next fire, which is
    -- harmless: they time one more call and then chain through the
    -- restored function.
    dfhack.timeout = P.real_timeout
    P.real_timeout = nil
end

-- ==========================================
-- THE SWEEP
-- ==========================================
-- Self chaining dfhack.timeout rather than a repeat-util loop, for
-- two reasons: it stays out of the registry so it cannot adopt
-- itself, and 'frames' timers survive a world unload, so the probe
-- keeps working across a reload.
--
-- 100 frames. Its own cost is one walk over a dozen keys, which is
-- nothing, and it is what catches loops that restart.
local SWEEP_FRAMES = 100

local function sweep()
    if not P.armed then return end
    pcall(adopt_all)
    P.sweep_id = dfhack.timeout(SWEEP_FRAMES, 'frames', sweep)
end

-- ==========================================
-- COMMANDS
-- ==========================================
-- Zeroes in place rather than replacing the rows, so the identity of
-- each row survives and no wrapper is left writing somewhere unread.
local function zero_counters()
    for _, s in pairs(P.stats) do
        s.calls, s.ms, s.max_ms = 0, 0, 0
    end
    P.t0 = dfhack.getTickCount()
end

-- arm always starts a FRESH window. Arming twice is therefore a
-- restart, not a silent continuation of an older window whose
-- elapsed time would flatten every average.
local function arm()
    if not find_registry() then
        log('could not find the repeat-util timer registry. Nothing'
            .. ' adopted. Run "refinish-perf-probe status" and send'
            .. ' the output.')
        return
    end
    patch_timeout()
    local n = adopt_all()
    if not P.armed then
        P.armed = true
        P.sweep_id = dfhack.timeout(SWEEP_FRAMES, 'frames', sweep)
    end
    zero_counters()
    log(('armed. %d loop(s) newly adopted, %d held, %d registered;'
        .. ' dfhack.timeout intercepted for self chaining loops.'
        .. ' Window reset. Run the fort UNPAUSED, then: report')
        :format(n, count(P.wrappers), count(P.reg)))
end

local function disarm()
    if not P.armed then log('not armed.') return end
    P.armed = false
    unpatch_timeout()
    if P.sweep_id then
        dfhack.timeout_active(P.sweep_id, nil)
        P.sweep_id = nil
    end

    -- Hand each loop back its original callback, but only where our
    -- wrapper is still the one standing. If something else has taken
    -- the slot since, writing over it would be the kind of silent
    -- damage this probe must not do.
    --
    -- A wrapper that could NOT be handed back stays in the identity
    -- set. It is still installed and still firing, and forgetting it
    -- is what would let a later arm wrap it a second time.
    local restored, kept = 0, {}
    if P.reg then
        for name, w in pairs(P.wrappers) do
            local id = P.reg[name]
            if id and dfhack.timeout_active(id) == w and P.origins[name] then
                dfhack.timeout_active(id, P.origins[name])
                P.is_wrapper[w] = nil
                restored = restored + 1
            else
                kept[name] = w
            end
        end
    end
    P.wrappers = kept
    P.origins = {}
    log(('disarmed. %d loop(s) handed back, %d wrapper(s) still'
        .. ' installed and tracked.'):format(restored, count(kept)))
end

local function reset()
    zero_counters()
    pcall(adopt_all)
    log('counters zeroed, window restarted.')
end

-- What the probe can see. This is the command that would have caught
-- v1's failure in one line instead of one 221 second window.
local function status()
    local reg = find_registry()
    local traw = 0
    for k in pairs(P.stats) do
        if tostring(k):sub(1, 2) == 't:' then traw = traw + 1 end
    end
    log(('version=%d armed=%s registry=%s rows=%d timeout_patch=%s'
        .. ' raw_timeout_rows=%d'):format(VERSION, tostring(P.armed),
        reg and 'found' or 'NOT FOUND', count(P.stats),
        P.real_timeout and 'ON' or 'off', traw))
    if not reg then
        print('repeat-util module fields:')
        for k, v in pairs(repeatUtil) do
            print(('  %-28s %s'):format(tostring(k), type(v)))
        end
        return
    end
    print(('%-36s %-10s %8s'):format('repeat key', 'state', 'calls'))
    for name, id in pairs(reg) do
        local cur = dfhack.timeout_active(id)
        local state = 'foreign'
        if cur == nil then state = 'dead'
        elseif P.is_wrapper[cur] then state = 'ADOPTED' end
        local s = P.stats[name]
        print(('%-36s %-10s %8d'):format(name, state, s and s.calls or 0))
    end
end

-- Sorted by total ms, which over one window is the same order as ms
-- per second. The bound column exonerates the quiet loops: a loop
-- reading all zeros still cannot cost more than one sub-ms call per
-- fire, so calls/s is its ceiling in ms/s.
local function report()
    if not P.t0 then log('never armed; nothing measured.') return end
    local elapsed = (dfhack.getTickCount() - P.t0) / 1000.0
    if elapsed <= 0 then elapsed = 0.001 end

    local rows = {}
    for key, s in pairs(P.stats) do rows[#rows + 1] = { key = key, s = s } end
    table.sort(rows, function(a, b) return a.s.ms > b.s.ms end)

    if #rows == 0 then
        log('no loops adopted. Run "refinish-perf-probe status".')
        return
    end

    print(('PERF PROBE: %.1f s window, %d loop(s) timed.')
        :format(elapsed, #rows))
    print(('%-36s %9s %8s %9s %8s %9s'):format(
        'repeat key', 'ms/sec', 'calls/s', 'avg ms', 'max ms', 'bound'))
    for _, r in ipairs(rows) do
        local s = r.s
        local cps = s.calls / elapsed
        print(('%-36s %9.1f %8.1f %9.2f %8d %9.1f'):format(
            r.key, s.ms / elapsed, cps,
            s.calls > 0 and (s.ms / s.calls) or 0, s.max_ms, cps))
    end
    print('PERF PROBE: a row of zeros with LOW calls/s is exonerated.')
    print('PERF PROBE: a row of zeros with HIGH calls/s costs at most')
    print('PERF PROBE: its bound column in ms/sec.')
end

local cmd = ({...})[1] or 'report'
if     cmd == 'arm'    then arm()
elseif cmd == 'disarm' then disarm()
elseif cmd == 'reset'  then reset()
elseif cmd == 'status' then status()
elseif cmd == 'report' then report()
else
    print('refinish-perf-probe: arm | status | report | reset | disarm')
end