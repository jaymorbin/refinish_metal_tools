-- refinish-pitch-doctor.lua  (D3)
-- ==========================================
-- ADAPTIVE CYCLE DOCTOR
-- ==========================================
-- One script, one run of any adaptive reaction, one report, in the
-- RM log, where deferred output actually lands in this environment.
--
-- D2 exists because six settle chain patches moved nothing, and the
-- reason is that no instrument ever showed WHICH attached items the
-- evidence ledger actually accepts. This build prints that:
--
--   1. PATCH SCAN with the real path from dfhack.findScript, so
--      absent versus present stops being arguable.
--   2. CLONE AND BASE in RAM for the watched reaction.
--   3. ALL BANK KEYS, before and after, with deltas.
--   4. THE CLASSIFICATION TABLE: every attached item pushed through
--      the preserved slot chain BOTH ways, the old broken read
--      (reagents[job_item_idx]) and the fixed read
--      (reagents[filter.reagent_index]), with an IN or OUT verdict
--      each. Which chain the disk file runs comes from the scan, so
--      the table shows what the live build is doing AND what the
--      fix would do, side by side, per item.
--   5. POST CYCLE AUTOPSY of every captured item and every
--      contained liquid: destroyed, or alive with stack, dimension
--      and cleanup flag.
--   6. LEDGER LINES for the job from the RM ring, whatever shape
--      its entries are.
--   7. A DIAGNOSIS naming the single next action.
--
-- USAGE
--   refinish-pitch-doctor RETORT_WOOD    arm on that reaction
--   refinish-pitch-doctor                arm on BOIL_PITCH
--   <run the reaction once, read the report in the RM log>
--   refinish-pitch-doctor stop           disarm
-- ==========================================

local BUILD = 'D3'

local repeatUtil = require('repeat-util')
local utils = require('utils')

local REPEAT_KEY = 'refinish-pitch-doctor'
local TAG = 'PITCH DOCTOR: '

local function log(msg)
    print(TAG .. msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg) end
end

local args = {...}
local first = (args[1] or ''):lower()
if first == 'stop' then
    repeatUtil.cancel(REPEAT_KEY)
    log('disarmed.')
    return
end
local NEEDLE = args[1] or 'BOIL_PITCH'

-- ==========================================
-- SAFE READERS
-- ==========================================
local function dig(o, f)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[f] end)
    if ok then return v end
    return nil
end

local function desc(item)
    local d = '?'
    pcall(function() d = dfhack.items.getDescription(item, 0) end)
    return d
end

-- ==========================================
-- SECTION 1: PATCH SCAN, REAL PATH
-- ==========================================
local MARKERS = {
    { 'preserved slots off ledger',   'contractually returned' },
    { 'tar burn witness (capture)',   'burn witness' },
    { 'witness via return channel',   'lands on nil and the pcall eats' },
    { 'evidence based store guard',   'enforced on EVIDENCE' },
    { 'fold aware desync target',     'MINUS the fold' },
    { 'filters map by reagent_index', 'filter names its owner' },
    { 'preserved slot chain fix',     'names a FILTER, not a reagent' },
    { 'dimension consume rule',       'liquid twin' },
}

local function scan_markers()
    log('==== SECTION 1: patches live on disk ====')
    local path = nil
    pcall(function() path = dfhack.findScript('making-fuel-ghost') end)
    if not path then
        log('  findScript could not resolve making-fuel-ghost.')
        return nil
    end
    log('  scanning ' .. path)
    local fh = io.open(path, 'r')
    if not fh then
        log('  CANNOT OPEN the resolved path; scan skipped.')
        return nil
    end
    local src = fh:read('*a')
    fh:close()
    local missing = 0
    for _, m in ipairs(MARKERS) do
        local found = src:find(m[2], 1, true) ~= nil
        if not found then missing = missing + 1 end
        log(string.format('  [%s] %s', found and 'LIVE' or 'ABSENT', m[1]))
    end
    return missing
end

-- ==========================================
-- SECTION 2: CLONE AND BASE IN RAM
-- ==========================================
local function find_rxn(code)
    for _, r in ipairs(df.global.world.raws.reactions.reactions) do
        if r.code == code then return r end
    end
    return nil
end

local function dump_reactions()
    log('==== SECTION 2: base and clone in RAM ====')
    local newest = nil
    for _, r in ipairs(df.global.world.raws.reactions.reactions) do
        if r.code:find(NEEDLE, 1, true) then
            if r.code:find('_GHOST_', 1, true) then
                newest = r
            else
                log(string.format('  base %s: %d reagent(s) %d product(s)',
                    r.code, #r.reagents, #r.products))
            end
        end
    end
    if newest then
        log('  clone ' .. newest.code)
        for i = 0, #newest.reagents - 1 do
            local g = newest.reagents[i]
            log(string.format(
                '    reagent[%d] %s  mat=%d/%d  PRESERVE=%s IN_CONTAINER=%s',
                i, tostring(g.code), g.mat_type, g.mat_index,
                tostring(g.flags.PRESERVE_REAGENT),
                tostring(g.flags.IN_CONTAINER)))
        end
    else
        log('  no ghost clone for this needle yet.')
    end
    return newest
end

-- ==========================================
-- SECTION 3: EVERY BANK KEY
-- ==========================================
local function bank_table()
    local out = {}
    pcall(function()
        for k, v in pairs(_G.refinish_fuel_bank or {}) do
            out[tostring(k)] = tonumber(v) or 0
        end
    end)
    return out
end

local function dump_banks(label, before)
    log('==== ' .. label .. ' ====')
    local now, any = bank_table(), false
    for k, v in pairs(now) do
        any = true
        local delta = ''
        if before and before[k] ~= nil and before[k] ~= v then
            delta = string.format('   (was %.6f, delta %+.6f)',
                before[k], v - before[k])
        elseif before and before[k] == nil then
            delta = '   (new key)'
        end
        log(string.format('  %-26s %.6f%s', k, v, delta))
    end
    if not any then log('  bank table is empty.') end
    return now
end

-- ==========================================
-- SECTION 4: THE CLASSIFICATION TABLE
-- ==========================================
-- Both chains per attached item. The verdict that matters is the
-- one the disk file runs (SECTION 1 says which), but printing both
-- shows exactly what the fix changes on this very job.
-- ==========================================
local function classify(job, ghost)
    log('==== SECTION 4: attached item classification ====')
    local witnesses = {}
    for _, iref in ipairs(job.items) do
        local it = iref.item
        local idx = dig(iref, 'job_item_idx') or -1
        local ri = nil
        pcall(function()
            ri = job.job_items.elements[idx].reagent_index
        end)
        local old_p, new_p = nil, nil
        pcall(function()
            old_p = ghost.reagents[idx].flags.PRESERVE_REAGENT
        end)
        if ri ~= nil then
            pcall(function()
                new_p = ghost.reagents[ri].flags.PRESERVE_REAGENT
            end)
        end
        local old_v = (idx < 0) and 'IN(unmapped)'
            or (old_p and 'OUT(preserved)' or 'IN')
        local new_v = (idx < 0) and 'IN(unmapped)'
            or (ri == nil and 'IN(no reagent_index)')
            or (new_p and 'OUT(preserved)' or 'IN')
        log(string.format(
            '  item #%d %-28s jidx=%d ri=%s  old=%s new=%s',
            it.id, desc(it):sub(1, 28), idx, tostring(ri),
            old_v, new_v))
        if new_v:sub(1, 2) == 'IN' then
            local snap = { id = it.id, name = desc(it),
                           stack = dig(it, 'stack_size') or 1,
                           dim = dig(it, 'dimension') }
            table.insert(witnesses, snap)
        end
        -- Contained liquids, informational plus autopsy targets.
        pcall(function()
            local inside = dfhack.items.getContainedItems(it)
            if not inside then return end
            for _, c in ipairs(inside) do
                if c:getType() == df.item_type.LIQUID_MISC then
                    log(string.format('    holds liquid #%d %s dim=%s',
                        c.id, desc(c):sub(1, 24),
                        tostring(dig(c, 'dimension'))))
                    table.insert(witnesses, { id = c.id,
                        name = desc(c),
                        stack = dig(c, 'stack_size') or 1,
                        dim = dig(c, 'dimension'), contained = true })
                end
            end
        end)
    end
    return witnesses
end

-- ==========================================
-- SECTION 5 + 6: AUTOPSY AND LEDGER
-- ==========================================
local function autopsy(witnesses)
    log('==== SECTION 5: post cycle autopsy ====')
    local any_dead, any_alive = false, false
    for _, w in ipairs(witnesses) do
        local it = nil
        pcall(function() it = df.item.find(w.id) end)
        if not it then
            any_dead = true
            log(string.format('  #%d %-24s DESTROYED',
                w.id, w.name:sub(1, 24)))
        else
            any_alive = true
            local gc = false
            pcall(function() gc = it.flags.garbage_collect end)
            log(string.format(
                '  #%d %-24s ALIVE stack=%s dim=%s gc=%s',
                w.id, w.name:sub(1, 24),
                tostring(dig(it, 'stack_size')),
                tostring(dig(it, 'dimension')), tostring(gc)))
        end
    end
    return any_dead, any_alive
end

local function ring_lines(job_id)
    local hits = {}
    pcall(function()
        local ring = _G.refinish_log
        if type(ring) ~= 'table' then return end
        local n = #ring
        for i = math.max(1, n - 200), n do
            local e = ring[i]
            local s = nil
            if type(e) == 'string' then s = e
            elseif type(e) == 'table' then
                s = tostring(e.msg or e.text or e.line or e[1] or '')
            else s = tostring(e) end
            if s:find('job ' .. job_id, 1, true) then
                hits[#hits + 1] = s
            end
        end
    end)
    return hits
end

-- ==========================================
-- WATCHER
-- ==========================================
local watch, banks0, missing = nil, nil, nil

local function poll()
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.CustomReaction
           and tostring(dig(job, 'reaction_name'))
               :find(NEEDLE, 1, true) then
            local ghost = find_rxn(tostring(job.reaction_name))
            if ghost then
                if not watch then
                    log(string.format('captured job %d [%s]',
                        job.id, tostring(job.reaction_name)))
                    -- The working flag probe: named access beside
                    -- bit 2, because the live dumps show only
                    -- anonymous bits. If named reads nil while the
                    -- bit is set, the ghost's worked observation is
                    -- dead code on this build.
                    local named, bit2 = 'nil', 'nil'
                    pcall(function()
                        named = tostring(job.flags.working)
                    end)
                    pcall(function()
                        bit2 = tostring(job.flags[2])
                    end)
                    log('  flags.working=' .. named
                        .. '  flags[2]=' .. bit2)
                    banks0 = bank_table()
                    watch = { job_id = job.id, witnesses = {},
                              n_items = -1, ev_sig = '' }
                end
                if watch.job_id == job.id then
                    -- Reclassify whenever the attachment set grows
                    -- or shrinks: D2 looked once, at the first item,
                    -- and the whole question is what the FINAL set
                    -- holds.
                    if #job.items ~= watch.n_items then
                        watch.n_items = #job.items
                        watch.witnesses = classify(job, ghost)
                    end
                    -- Reproduce the ghost's identity loop verbatim:
                    -- the evidence ids this poll would put in the
                    -- snap. Printed on change; the last line printed
                    -- before the cycle report IS the settled set,
                    -- give or take the store guard, which only ever
                    -- keeps a BETTER one.
                    local ev = {}
                    for _, iref in ipairs(job.items) do
                        local idx = dig(iref, 'job_item_idx') or -1
                        local skip = false
                        if idx >= 0 then
                            pcall(function()
                                local ri = job.job_items
                                    .elements[idx].reagent_index
                                skip = ghost.reagents[ri]
                                    .flags.PRESERVE_REAGENT == true
                            end)
                        end
                        if not skip then
                            ev[#ev + 1] = iref.item.id
                        end
                    end
                    table.sort(ev)
                    local sig = table.concat(ev, ',')
                    if sig ~= watch.ev_sig then
                        watch.ev_sig = sig
                        log('  evidence set now: {' .. sig .. '}')
                    end
                    return
                end
            end
        end
    end
    if watch then
        local w = watch
        watch = nil
        log('==== CYCLE REPORT: job ' .. w.job_id .. ' ====')
        local dead, alive = autopsy(w.witnesses)
        local lines = ring_lines(w.job_id)
        local burned = false
        if #lines == 0 then
            log('  ledger: no ring lines matched this job.')
        end
        for _, l in ipairs(lines) do
            if l:find('BURNED', 1, true) then burned = true end
            log('  ledger: ' .. l)
        end
        dump_banks('SECTION 3b: banks after cycle', banks0)
        log('==== DIAGNOSIS ====')
        if missing and missing > 0 then
            log('  patches ABSENT (SECTION 1). Apply them first;')
            log('  nothing below is judgeable until they run.')
        elseif dead and not burned then
            log('  Witnesses died, ledger refused. With the new')
            log('  chain live and items IN per SECTION 4, the')
            log('  settled snapshot is not the one holding them.')
            log('  Snapshot lifecycle is the sole remaining site.')
        elseif dead and burned then
            log('  Burned and credited. If a bank delta above still')
            log('  disagrees, the fault is inside settle payout math.')
        elseif alive and not dead then
            log('  Nothing captured was consumed. The ledger is')
            log('  telling the truth; the reaction is not eating')
            log('  its feedstock. That is a reaction bug, not a')
            log('  bank bug, and SECTION 2 shows the clone that')
            log('  failed to demand it.')
        end
        log('watcher stays armed. refinish-pitch-doctor stop when done.')
    end
end

log('build ' .. BUILD .. ' arming on [' .. NEEDLE .. '].')
missing = scan_markers()
dump_reactions()
dump_banks('SECTION 3: banks now', nil)
repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
log('run the reaction once, then read the report in the RM log.')
