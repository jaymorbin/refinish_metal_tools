--@ module = true
-- refinish-fuel-slot-probe.lua
-- ==========================================
-- WHAT A WIDENED FUEL FILTER WILL ACCEPT
-- ==========================================
-- Supersedes refinish-fuel-count-probe, which reported a number it
-- never read. DELETE THAT FILE, and if it is still scheduled from
-- an earlier console run, stop it first: two probes on the same
-- jobs double every line in the log.
--
-- ---- MEASURED, job 86, MAKE_CLAY_JUG, one reagent ----
--   [0]  quantity=1 reagent_index=0  reaction_id=98 item_type=4
--        vector_id=19 has_material_reaction_product=FIRED_MAT
--   [1]  quantity=1 reagent_index=-1 reaction_id=-1 item_type=-1
--        vector_id=1  reaction_class=FUEL          <- the fuel slot
--
-- Three things settled by that one dump:
--
-- 1. `quantity` EXISTS and reads 1. `count` is ABSENT. The old
--    probe wrote `count`, DFHack raised on the unknown field, the
--    pcall swallowed it, and "count 0 -> 4" was printed from an
--    untouched local. That experiment never ran.
--
-- 2. THE FUEL SLOT IS NOT A REAGENT. reagent_index is -1 and
--    reaction_id is -1, so it is disconnected from the reaction
--    entirely. This is the answer the slot design was waiting on:
--    L7's out of bounds read is a lookup of an index PAST THE END
--    of the reagent list, and -1 is not past the end, it is the
--    value DF itself writes and completes with every day. Clones of
--    this filter inherit -1 and are the same shape.
--
-- 3. Fuel landed last AGAIN. Jobs 85 and 86 both covered their fuel
--    slot on the exact tick coverage completed. Twice is a pattern,
--    and it is the expected one: the other reagents are workshop
--    inputs a dwarf is already fetching, fuel is an afterthought
--    hauled last. Nothing may be added to these jobs on attach.
--    Additions happen at POSTING or not at all.
--
-- ---- MEASURED, job 18, slot 4 ----
-- Three clones appended at posting, filters 2 -> 5. Every extra
-- slot filled, one at a time: 2:1, then 3:1, then 4:1. The job
-- completed and made one earthenware jug. Nothing spurious in the
-- 20 frame window. MULTI SLOT COLLECTION WORKS.
--
-- Two things that run did NOT settle, and this version measures the
-- first of them:
--
-- 1. COLLECTION IS NOT PAYMENT. Four items were fetched. Whether
--    all four were destroyed, or one was burned and three handed
--    back, is a different question and the log could not answer it
--    because the job never left the list to print its last holding.
--    The survival check below answers it by item id.
--
-- 2. THE FILTER VECTOR SURVIVES A REPEAT JOB'S RE-POST. Job 18 went
--    straight back to collecting under the same id with all five
--    filters intact. The ghost measured this once already on job
--    826 and it is the reason multi item collection was abandoned
--    there: a job grown to N is BORN demanding N every later cycle,
--    so when the pile runs dry it cancels inside a second without
--    ever entering the working phase. Any build of this must tear
--    the extras down between cycles and re-decide, the way
--    collapse_vessels does. That is a design fact, not a probe
--    question.
--
-- ---- MODES ----
--   read       Changes nothing. Dumps every field of every filter,
--              printing ABSENT for names this build does not carry
--              rather than assuming any of them, and gives the
--              reagent_index verdict. Run this first, always.
--   quantity N The experiment that never ran, with the right field
--              name. Writes are NOT swallowed: a failed write says
--              so by name.
--   slot N     Appends N-1 clones of the fuel filter at POSTING,
--              before anything attaches, cloned with :assign so
--              every field including reagent_index matches a filter
--              DF wrote itself. Refuses unless `read` has confirmed
--              the index.
--
-- ---- WHY COMPLETION IS READ FROM THE POLL, NOT THE EVENT ----
-- onJobCompleted hands over a COPY, and on job 86 that copy's item
-- list was already EMPTY, so the "consuming:" line named nothing.
-- The attached items are therefore snapshotted on every poll while
-- the job is still live, and the LAST snapshot is what gets printed
-- when the job leaves the list. That is the only reading that
-- exists at the moment it matters.
--
-- ---- HOW TO RUN ----
--   1. Making Fuel running, fuel access active.
--   2. Stock well more than N of ONE plain fuel and nothing else
--      burnable, so there is no doubt what got fetched.
--   3. refinish-fuel-slot-probe read, queue a kiln job, read it.
--   4. Then refinish-fuel-slot-probe slot 4, queue another.
--
-- Console only. This is an instrument, not a feature.
-- ==========================================

local eventful   = require('plugins.eventful')
local repeatUtil = require('repeat-util')

local REPEAT_KEY = 'refinish_fuel_slot_probe'
local LOG_TAG    = 'FUEL PROBE: '

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
-- FIELD ACCESS THAT CANNOT LIE
-- ==========================================
-- One statement per pcall, and the failure is returned rather than
-- discarded. Every number this probe prints came out of the game or
-- is printed as ABSENT. That is the lesson of the count round.
local function rd(obj, field)
    local ok, v = pcall(function() return obj[field] end)
    if not ok then return nil, 'ABSENT' end
    return v, tostring(v)
end

local function wr(obj, field, value)
    local ok, err = pcall(function() obj[field] = value end)
    if not ok then
        log(string.format('WRITE FAILED on %s: %s',
            field, tostring(err)))
    end
    return ok
end

local FIELDS = {
    'quantity', 'count', 'reagent_index', 'reaction_id',
    'item_type', 'item_subtype', 'mat_type', 'mat_index',
    'vector_id', 'reaction_class', 'min_dimension',
    'has_tool_use', 'metal_ore', 'has_material_reaction_product',
}

-- ==========================================
-- STATE
-- ==========================================
local MODE_READ, MODE_QTY, MODE_SLOT = 'read', 'quantity', 'slot'

local mode      = MODE_READ
local want_n    = 4
local running   = false
local tracked   = {}
local tick      = 0
local watch_new = 0
local index_ok  = nil

-- ==========================================
-- THE SURVIVAL CHECK
-- ==========================================
-- THE QUESTION THE SLOT RUN LEFT OPEN. Four kindling were fetched
-- and the jug was made, which proves COLLECTION. It does not prove
-- PAYMENT. DF might consume one fuel item and hand the other three
-- back to the stockpile, and the whole surcharge would be theatre
-- that a stock count exposes a week later.
--
-- An item id outlives the item. A few polls after completion every
-- recorded id is looked up again: gone means destroyed, still there
-- means handed back. Delayed rather than immediate, because
-- destruction and the completion event need not land on one frame.
local pending = {}      -- { at = tick, id = job id, ids = {...} }

-- ==========================================
-- FINDING THE FUEL FILTER
-- ==========================================
-- Recognised exactly as making-fuel-fuel-access recognises its own
-- work: reaction_class equals one of the two tier classes. A
-- job_item's reaction_class is a plain string field, unlike a
-- material's, which is a vector of string pointers, so tostring is
-- right here and wrong there.
--
-- This probe never hooks onJobInitiated. Fuel access owns that
-- event, listener order between two handlers is not something to
-- depend on, and this must run strictly AFTER the widen or it would
-- be measuring an untouched BAR/COAL filter.
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

-- How many reagents the job's reaction declares, or nil when there
-- is no reaction at all (every hardcoded job: melt, smelt, glass).
local function reaction_reagent_count(j)
    local n = nil
    pcall(function()
        local name = j.reaction_name
        if not name or name == '' then return end
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            if r.code == name then
                n = #r.reagents
                return
            end
        end
    end)
    return n
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

-- Every item currently attached, named, with the filter index it
-- was attached to. Refreshed every poll: this is the only reading
-- that survives to completion, because the event's copy is stripped.
local function snapshot(j)
    local parts = {}
    pcall(function()
        for _, iref in ipairs(j.items) do
            table.insert(parts, string.format('[%s]%s',
                tostring(iref.job_item_idx), token_of(iref.item)))
        end
    end)
    if #parts == 0 then return nil end
    return table.concat(parts, ' ')
end

-- The same reading kept as ITEM IDS, which is what the survival
-- check needs. An id outlives the item: df.item.find on a destroyed
-- one returns nil, and that is how consumed is told from released.
local function attached_ids(j)
    local out = {}
    pcall(function()
        for _, iref in ipairs(j.items) do
            local it = iref.item
            if it then
                table.insert(out, {
                    id  = it.id,
                    idx = iref.job_item_idx,
                    tok = token_of(it),
                })
            end
        end
    end)
    if #out == 0 then return nil end
    return out
end

-- ==========================================
-- THE DUMP
-- ==========================================
local function dump_job(j, fuel_idx)
    local n_r = reaction_reagent_count(j)
    log(string.format('---- job %d %s, reaction %s, %s reagent(s)',
        j.id, job_name(j),
        tostring(j.reaction_name ~= '' and j.reaction_name
                 or 'HARDCODED'),
        n_r and tostring(n_r) or 'no reaction'))

    pcall(function()
        for i, e in ipairs(j.job_items.elements) do
            local parts = {}
            for _, f in ipairs(FIELDS) do
                local _, s = rd(e, f)
                table.insert(parts, f .. '=' .. s)
            end
            log(string.format('  [%d]%s %s', i,
                i == fuel_idx and ' FUEL' or '',
                table.concat(parts, ' ')))
        end
    end)

    local ri = rd(j.job_items.elements[fuel_idx], 'reagent_index')
    if ri == nil then
        log('  reagent_index is ABSENT on this build. Appended slots'
            .. ' cannot be reasoned about. STOP.')
        index_ok = false
    elseif ri < 0 then
        log(string.format('  fuel reagent_index=%s, NOT a reagent.'
            .. ' Clones inherit -1 and are the shape DF completes'
            .. ' today. Safe to append.', tostring(ri)))
        index_ok = true
    elseif n_r == nil then
        log(string.format('  fuel reagent_index=%s on a HARDCODED'
            .. ' job with no reaction to look it up on. Do not'
            .. ' append until this case is understood.',
            tostring(ri)))
        index_ok = false
    elseif ri < n_r then
        log(string.format('  fuel reagent_index=%s points at a REAL'
            .. ' reagent of %d. Clones would make two filters claim'
            .. ' one reagent, the shape the ghost refused to build'
            .. ' for vessels. Test with care.', tostring(ri), n_r))
        index_ok = true
    else
        log(string.format('  fuel reagent_index=%s is PAST the end'
            .. ' of %d reagent(s), already the out of bounds shape.'
            .. ' Do not append. STOP.', tostring(ri), n_r))
        index_ok = false
    end
end

-- ==========================================
-- THE TWO EXPERIMENTS
-- ==========================================
local function stamp_quantity(j, idx)
    local before = select(2, rd(j.job_items.elements[idx], 'quantity'))
    if wr(j.job_items.elements[idx], 'quantity', want_n) then
        local after = select(2,
            rd(j.job_items.elements[idx], 'quantity'))
        wr(j, 'recheck_cntdn', 0)
        log(string.format('job %d: fuel quantity %s -> %s (read back)',
            j.id, before, after))
        return true
    end
    return false
end

-- Cloned with :assign off the fuel filter itself, so every field
-- including reagent_index matches a filter DF wrote. The ghost's
-- vessel expansion uses exactly this idiom; the difference is that
-- it also grows the reagent list, which cannot be done here without
-- editing a reaction every other kiln job in the fort shares. It
-- does not need to be done here either, because -1 claims no
-- reagent and so nothing looks it up.
local function append_slots(j, idx)
    if index_ok ~= true then
        log(string.format('job %d: refusing to append. Run `read`'
            .. ' first and confirm reagent_index.', j.id))
        return false
    end
    local made, after = 0, -1
    local ok, err = pcall(function()
        local els   = j.job_items.elements
        local proto = els[idx]
        for _ = 2, want_n do
            local ne = proto._type:new()
            ne:assign(proto)
            els:insert('#', ne)
            made = made + 1
        end
        after = #els
    end)
    if not ok then
        log(string.format('job %d: APPEND FAILED: %s',
            j.id, tostring(err)))
        return false
    end
    wr(j, 'recheck_cntdn', 0)
    log(string.format('job %d: appended %d clone(s) of the fuel'
        .. ' filter. Filters now %d.', j.id, made, after))
    return true
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
                if not tracked[j.id] then
                    local idx = fuel_filter_index(j)
                    if idx then
                        local n_el = #j.job_items.elements
                        dump_job(j, idx)
                        if mode == MODE_QTY then
                            stamp_quantity(j, idx)
                        elseif mode == MODE_SLOT then
                            append_slots(j, idx)
                        end
                        tracked[j.id] = {
                            idx = idx, n_base = n_el, last = '',
                            n_last = #j.job_items.elements,
                            fuel_at = nil, full_at = nil, seen = nil,
                        }
                    end
                else
                    local st = tracked[j.id]

                    -- ---- DID DF PRUNE OUR FILTERS ----
                    -- Appended slots vanishing would be a finding in
                    -- itself, so the vector length is watched.
                    local n_now = st.n_last
                    pcall(function()
                        n_now = #j.job_items.elements
                    end)
                    if n_now ~= st.n_last then
                        log(string.format('job %d: FILTER COUNT'
                            .. ' CHANGED %d -> %d', j.id,
                            st.n_last, n_now))
                        st.n_last = n_now
                    end

                    local cov, n_cov = {}, 0
                    pcall(function()
                        for _, iref in ipairs(j.items) do
                            local i = iref.job_item_idx
                            if i and i >= 0 then
                                cov[i] = (cov[i] or 0) + 1
                            end
                        end
                    end)
                    for i = 0, st.n_base - 1 do
                        if cov[i] then n_cov = n_cov + 1 end
                    end

                    -- Extras reported one by one, not summed: which
                    -- slot filled and which did not is the answer,
                    -- and a total hides it.
                    local extras = {}
                    for i = st.n_base, n_now - 1 do
                        table.insert(extras,
                            string.format('%d:%d', i, cov[i] or 0))
                    end

                    local on_fuel = cov[st.idx] or 0
                    if on_fuel > 0 and not st.fuel_at then
                        st.fuel_at = tick
                    end
                    if not st.full_at and n_cov >= st.n_base then
                        st.full_at = tick
                    end

                    local snap = snapshot(j)
                    if snap then
                        st.seen = snap
                        st.ids  = attached_ids(j)
                    end

                    local line = string.format(
                        'fuel slot %d, base covered %d/%d%s',
                        on_fuel, n_cov, st.n_base,
                        #extras > 0 and (', extras ' ..
                            table.concat(extras, ' ')) or '')
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

    for id, st in pairs(tracked) do
        if not live[id] then
            log(string.format('job %d left the list. fuel at tick %s,'
                .. ' base covered at tick %s, filters %d.', id,
                tostring(st.fuel_at), tostring(st.full_at),
                st.n_last))
            log(string.format('  last held: %s',
                st.seen or 'NOTHING RECORDED'))
            tracked[id] = nil
        end
    end

    -- ---- SURVIVAL CHECK, A FEW POLLS AFTER COMPLETION ----
    -- A REPEAT JOB NEVER LEAVES THE LIST, so this cannot wait for a
    -- departure. Job 18 completed a jug and went straight back to
    -- collecting under the same id. Timed off completion instead.
    for k = #pending, 1, -1 do
        local p = pending[k]
        if tick >= p.at then
            local gone, kept = 0, {}
            for _, rec in ipairs(p.ids) do
                local alive = false
                pcall(function()
                    local it = df.item.find(rec.id)
                    alive = it ~= nil
                        and not it.flags.removed
                        and not it.flags.garbage_collect
                end)
                if alive then
                    table.insert(kept, string.format('[%s]%s#%d',
                        tostring(rec.idx), rec.tok, rec.id))
                else
                    gone = gone + 1
                end
            end
            log(string.format('job %d payment: %d of %d attached'
                .. ' item(s) DESTROYED.', p.id, gone, #p.ids))
            if #kept > 0 then
                log(string.format('  still in the world: %s',
                    table.concat(kept, ' ')))
                log('  RELEASED, NOT CONSUMED. The surcharge is not'
                    .. ' being paid.')
            end
            table.remove(pending, k)
        end
    end
end

-- ==========================================
-- THE SPURIOUS PRODUCT WINDOW
-- ==========================================
-- The completion event's job is a copy whose item list is already
-- empty, so it is used only to open this window. Everything created
-- in the next 20 frames is named, which is how a second peat bar
-- gets caught by name rather than found in a stockpile next week.
-- Unrelated births land in it too; a cave swallow's remains showed
-- up in the last run. Read it as a window, not a product list.
local function on_completed(j)
    pcall(function()
        local st = tracked[j.id]
        if not st then return end
        log(string.format('job %d COMPLETED holding: %s', j.id,
            st.seen or 'NOTHING RECORDED'))
        -- Queued rather than checked now: the items may not be
        -- destroyed on the same frame the event fires.
        if st.ids then
            table.insert(pending,
                { at = tick + 4, id = j.id, ids = st.ids })
        end
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
function start(m, n)
    mode = m or MODE_READ
    if mode ~= MODE_READ and mode ~= MODE_QTY
       and mode ~= MODE_SLOT then
        print('mode must be read, quantity or slot')
        return
    end
    want_n = tonumber(n) or 4
    tracked, tick, watch_new, pending = {}, 0, 0, {}
    if mode == MODE_READ then index_ok = nil end
    running = true
    eventful.onJobCompleted[REPEAT_KEY] = on_completed
    eventful.onItemCreated[REPEAT_KEY]  = on_created
    -- Frequency 0 on completion is what separates a finished job
    -- from a cancelled one, per the eventful contract.
    eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 0)
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, 0)
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log(string.format('active, mode=%s n=%d.', mode, want_n))
    if mode ~= MODE_READ then
        log('Stock well more than that of ONE plain fuel first.')
    end
end

function stop()
    running = false
    eventful.onJobCompleted[REPEAT_KEY] = nil
    eventful.onItemCreated[REPEAT_KEY]  = nil
    repeatUtil.cancel(REPEAT_KEY)
    tracked, pending = {}, {}
    log('stopped. Filters die with their jobs; nothing to undo.')
end

function status()
    print(string.format('%srunning=%s mode=%s n=%d index_ok=%s',
        LOG_TAG, tostring(running), mode, want_n, tostring(index_ok)))
    print(string.format('  primary %s | smith %s',
        tostring(T().FUEL_CLASS), tostring(T().FUEL_SMITH_CLASS)))
end

if dfhack_flags and dfhack_flags.module then return end
local args = {...}
if args[1] == 'read' then start('read')
elseif args[1] == 'quantity' then start('quantity', args[2])
elseif args[1] == 'slot' then start('slot', args[2])
elseif args[1] == 'stop' then stop()
elseif args[1] == 'status' then status()
else
    print('usage: refinish-fuel-slot-probe read'
        .. ' | quantity N | slot N | stop | status')
end