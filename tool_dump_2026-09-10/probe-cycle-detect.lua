--@ module = true
-- probe-cycle-detect.lua
-- ==========================================
-- CYCLE DETECTION PROBE
-- ==========================================
-- ONE QUESTION: why do six bone consumptions produce only four
-- ledger lines?
--
-- Measured on job 47: #1110 was decremented at 08:06:21, 08:06:44,
-- 08:06:58, 08:07:12, 08:07:26 and 08:07:40, and settle logged a
-- block for only four of them. Two whole cycles vanished with no
-- BURNED, no NOT CONSUMED, and no bank line, so their deposits were
-- lost in silence. That is upstream of everything else: if settle
-- never runs, no burn test of any kind gets a chance, and a payout
-- written on such a cycle is free.
--
-- WHAT DECIDES IT. handle_ghosted settles the previous cycle only
-- when:
--
--     if prev and prev.id_key and not untouched(prev) then
--
-- untouched() walks the recorded ids and answers false if one
-- vanished, shrank in stack, or dropped in dimension. A bone stack
-- answers none of those, so on paper the trigger should NEVER fire
-- for RETORT_BONE, yet it fired four times. Something incidental is
-- making it fire, and this measures what.
--
-- LEADING HYPOTHESIS, to be confirmed or killed: a preserved jug
-- sometimes lands in the recorded id set. slot_preserved returns
-- false when job_item_idx is -1, and the comment in the ghost says
-- DF does attach items to no particular filter sometimes. Jugs are
-- replaced every cycle, so a jug in the id set would vanish next
-- cycle and trip the trigger by accident. If that is what is
-- happening, cycle detection is currently luck.
--
-- WHAT IT REPORTS, per retort job, only when something changes:
--   the attached items, each with job_item_idx, the reagent it maps
--   to, and whether the ghost counts it as preserved
--   the id_key the ghost would compute
--   whether untouched() would return false right now, and WHY
--   every corpsepiece consumption, so settles and consumptions can
--   be lined up on one timeline
--
-- THIS PROBE ONLY READS.
--
-- USAGE
--   probe-cycle-detect watch    start
--   probe-cycle-detect stop     stop
--
-- HOW TO RUN IT
--   Start it, then run a repeat bone job on a multi bone stack and
--   let it chew through four or five bones. Every CONSUMED line
--   should be followed by a TRIGGER line. A CONSUMED with no
--   TRIGGER is a lost cycle, and the dump above it names the reason.
-- ==========================================

local repeatUtil = require('repeat-util')
local utils      = require('utils')

local REPEAT_KEY = 'probe_cycle_detect'
local TAG        = 'CYCLE PROBE: '

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- ==========================================
-- REACTION LOOKUP
-- ==========================================
-- The job names its ghost after the swap, and the reagents that
-- decide PRESERVE_REAGENT live on that ghost. Cached because the
-- reaction vector is long and this runs every poll.
-- ==========================================
local rxn_cache = {}

local function find_reaction(code)
    if rxn_cache[code] ~= nil then return rxn_cache[code] or nil end
    local found = false
    pcall(function()
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            if tostring(r.code) == code then
                rxn_cache[code] = r
                found = true
                return
            end
        end
    end)
    if not found then rxn_cache[code] = false end
    return rxn_cache[code] or nil
end

-- ==========================================
-- THE GHOST'S OWN PRESERVED TEST, COPIED EXACTLY
-- ==========================================
-- Deliberately a copy rather than a call, so this probe measures what
-- the ghost does rather than inheriting a shared mistake. Returns
-- preserved, job_item_idx, reagent_index, why.
-- ==========================================
local function slot_preserved(job, rxn, iref)
    local idx = iref.job_item_idx
    if not idx or idx < 0 then
        return false, idx, nil, 'job_item_idx is -1, counted IN'
    end
    local ri, pres, ok = nil, nil, false
    ok = pcall(function()
        ri   = job.job_items.elements[idx].reagent_index
        pres = rxn.reagents[ri].flags.PRESERVE_REAGENT
    end)
    if not ok then
        return false, idx, ri, 'mapping unreadable, counted IN'
    end
    return pres == true, idx, ri,
           pres == true and 'PRESERVE_REAGENT, skipped'
                        or 'not preserved, counted IN'
end

-- ==========================================
-- BUILD THE ID SET THE GHOST WOULD BUILD
-- ==========================================
local function snapshot(job, rxn)
    local s = { ids = {}, stacks = {}, dims = {}, rows = {} }
    pcall(function()
        for _, iref in ipairs(job.items) do
            local it = iref.item
            local pres, idx, ri, why = slot_preserved(job, rxn, iref)
            local d = '?'
            pcall(function() d = dfhack.items.getDescription(it, 0) end)
            local sz = 1
            pcall(function() sz = it.stack_size or 1 end)
            local dm = nil
            pcall(function() dm = it.dimension end)
            -- The filter's own quantity, which is the number DF is
            -- trying to satisfy. Two items landing on one filter is
            -- either a quantity above 1 or DF doing something else
            -- entirely, and without this column there is no way to
            -- tell which.
            local q = '?'
            pcall(function()
                if idx and idx >= 0 then
                    q = tostring(job.job_items.elements[idx].quantity)
                end
            end)
            table.insert(s.rows, string.format(
                '#%-6d idx=%-3s reagent=%-4s qty=%-4s %-9s %s',
                it.id, tostring(idx), tostring(ri), q,
                pres and 'PRESERVED' or 'IN LEDGER', tostring(d)))
            if not pres then
                table.insert(s.ids, it.id)
                s.stacks[it.id] = sz
                if dm then s.dims[it.id] = dm end
            end
        end
    end)
    -- Every FILTER, including ones nothing is attached to. An item
    -- count and a filter count that disagree is the whole question
    -- when two items share an index.
    pcall(function()
        local els = job.job_items.elements
        local f = {}
        for i = 0, #els - 1 do
            -- The full SPEC, not just the index. If an appended
            -- container filter lost its item_type or its
            -- has_tool_use in the clone, it would match anything at
            -- all, and reading indices alone would never show it.
            local q, ri2 = '?', '?'
            local it_, sub, tu, mt, mi = '?', '?', '?', '?', '?'
            pcall(function() q   = tostring(els[i].quantity) end)
            pcall(function() ri2 = tostring(els[i].reagent_index) end)
            pcall(function()
                local t = els[i].item_type
                it_ = (t and t >= 0) and tostring(df.item_type[t])
                      or tostring(t)
            end)
            pcall(function() sub = tostring(els[i].item_subtype) end)
            pcall(function()
                local u = els[i].has_tool_use
                tu = (u and u >= 0) and tostring(df.tool_uses[u])
                     or tostring(u)
            end)
            pcall(function() mt = tostring(els[i].mat_type) end)
            pcall(function() mi = tostring(els[i].mat_index) end)
            table.insert(f, string.format(
                '\n              [%d] r%s q%s type=%s sub=%s use=%s mat=%s/%s',
                i, ri2, q, it_, sub, tu, mt, mi))
        end
        s.filters = table.concat(f, '')
        s.nfilters = #els
    end)
    s.id_key = table.concat(s.ids, ',')
    return s
end

-- ==========================================
-- THE GHOST'S untouched(), COPIED EXACTLY, PLUS A REASON
-- ==========================================
-- Returns untouched, reason. false means a settle WOULD fire.
-- ==========================================
local function untouched(s)
    if not s or not s.ids or #s.ids == 0 then
        return true, 'no recorded ids, cannot fire'
    end
    for _, iid in ipairs(s.ids) do
        local it = nil
        pcall(function() it = df.item.find(iid) end)
        if not it then
            return false, string.format('#%d vanished', iid)
        end
        local sz = 1
        pcall(function() sz = it.stack_size or 1 end)
        if sz < (s.stacks[iid] or sz) then
            return false, string.format('#%d stack %d -> %d',
                iid, s.stacks[iid], sz)
        end
        local dm = nil
        pcall(function() dm = it.dimension end)
        if dm and dm < (s.dims[iid] or dm) then
            return false, string.format('#%d dimension %s -> %s',
                iid, tostring(s.dims[iid]), tostring(dm))
        end
        local gc = false
        pcall(function() gc = it.flags.garbage_collect end)
        if gc then
            return false, string.format('#%d flagged garbage_collect', iid)
        end
    end
    return true, 'every recorded id intact'
end

-- ==========================================
-- CORPSEPIECE CONSUMPTION, THE OTHER HALF OF THE TIMELINE
-- ==========================================
-- A consumption with no trigger beside it is a lost cycle. Tracked
-- on material_amount because that is the field measured to move.
-- ==========================================
local bone_amt = {}

local function amount_of(it)
    local most = 0
    pcall(function()
        local ma = it.material_amount
        for i = 0, #ma - 1 do
            if ma[i] > most then most = ma[i] end
        end
    end)
    return most
end

local function scan_consumption()
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSEPIECE then
                local a = amount_of(it)
                local was = bone_amt[it.id]
                if was and a < was then
                    local d = '?'
                    pcall(function()
                        d = dfhack.items.getDescription(it, 0)
                    end)
                    log(string.format('CONSUMED  #%d %s  amount %d -> %d',
                        it.id, tostring(d), was, a))
                end
                bone_amt[it.id] = a
            end
        end
    end)
end

-- ==========================================
-- THE WATCHER
-- ==========================================
local last = {}

local function poll()
    if not dfhack.isMapLoaded() then return end

    scan_consumption()

    local live = {}
    pcall(function()
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            if job.job_type ~= df.job_type.CustomReaction then goto next end
            local code = tostring(job.reaction_name)
            if not (code:find('RETORT', 1, true)
                    or code:find('BOIL', 1, true)) then goto next end
            live[job.id] = true

            local rxn = find_reaction(code)
            if not rxn then goto next end

            local now  = snapshot(job, rxn)
            local prev = last[job.id]

            -- Would the ghost settle the previous cycle right now?
            if prev then
                local ok, why = untouched(prev)
                if not ok then
                    log(string.format('TRIGGER   job %d  settle WOULD fire: %s',
                        job.id, why))
                end
            end

            -- Only report the item set when it changes, or this
            -- floods at six polls a second.
            -- Also dump when the FILTER count changes, not only when
            -- the item set does. Appends happen after the feed is
            -- attached, so keying on id_key alone never showed an
            -- appended filter's spec.
            if not prev or prev.id_key ~= now.id_key
               or prev.nfilters ~= now.nfilters then
                log(string.format('ITEMS     job %d  id_key "%s"%s',
                    job.id, now.id_key,
                    prev and (' was "' .. prev.id_key .. '"') or ' (first)'))
                for _, row in ipairs(now.rows) do
                    log('            ' .. row)
                end
                if now.filters then
                    log(string.format('            %d filter(s): %s',
                        now.nfilters or -1, now.filters))
                end
                if #now.ids == 0 then
                    log('            NOTE: empty ledger set, so'
                        .. ' untouched() can never return false and'
                        .. ' this cycle can never settle.')
                end
            end

            last[job.id] = now
            ::next::
        end
    end)

    for jid in pairs(last) do
        if not live[jid] then
            log(string.format('GONE      job %d left the job list', jid))
            last[jid] = nil
        end
    end
end

-- ==========================================
-- LIFECYCLE
-- ==========================================
function start()
    last, bone_amt, rxn_cache = {}, {}, {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSEPIECE then
                bone_amt[it.id] = amount_of(it)
            end
        end
    end)
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log('Watching cycle detection. Run a repeat bone job on a multi'
        .. ' bone stack and let it chew through four or five.')
    log('Every CONSUMED should have a TRIGGER beside it. A CONSUMED'
        .. ' with no TRIGGER is a lost cycle.')
    log('Stop with:  probe-cycle-detect stop')
end

function stop()
    repeatUtil.cancel(REPEAT_KEY)
    log('Stopped watching.')
end

local cmd = ...
if cmd == 'stop' then
    stop()
else
    start()
end