--@ module = true
-- probe-liquid-mint.lua
-- ==========================================
-- LIQUID MINT PROBE
-- ==========================================
-- ONE QUESTION: when a retort completes, what does DF actually
-- create in the vessel, and how does that depend on the count the
-- ghost wrote to that liquid product slot?
--
-- WHY IT EXISTS. RETORT_BONE jobs 23 and 33 wrote count 0 to both
-- liquid slots, banked the fractions correctly and paid nothing,
-- and two liquid items appeared anyway at stack 0. That suggests DF
-- mints a to_container product even at count 0, leaving nulls in
-- vessels that later get handed to the boil. It is a hypothesis.
-- Nothing gets built on it until this measures it.
--
-- WHAT IT PAIRS, for every liquid item that appears:
--   the item     id, material, stack_size, dimension, container
--   the cause    what the ghost had written to that material's
--                product slot on the job running at the time:
--                count and product_dimension
--
-- The pairing is the entire point, and it splits three ways:
--   count 0, item appears           the null mint. Nothing was paid
--                                   and an item exists anyway.
--   count 1, item appears stack 1   a correct payout.
--   count 1, item appears stack 0   paying mints are broken too,
--                                   which is a different fix.
--
-- THIS PROBE ONLY WATCHES. It changes nothing, so it can run
-- through a whole test session safely.
--
-- USAGE
--   probe-liquid-mint          inventory now, plus an instrument check
--   probe-liquid-mint watch    start reporting new liquid items
--   probe-liquid-mint stop     stop reporting
--
-- HOW TO RUN THE TEST, on the clean save:
--   1. probe-liquid-mint          confirm the inventory is empty
--   2. probe-liquid-mint watch
--   3. Run ONE bone retort job. One bone accrues 0.206 oil bone,
--      which is under a package, so the correct outcome is that
--      NOTHING is minted into either vessel.
--   4. Keep feeding bones until a job pays. Five bones reach the
--      first jug of oil bone, so job five is the paying one.
--   5. Upload the log. Every MINT line carries the count that
--      caused it, which answers the question outright.
-- ==========================================

local repeatUtil = require('repeat-util')
local utils      = require('utils')

local REPEAT_KEY = 'probe_liquid_mint'
local TAG        = 'MINT PROBE: '
local POLL       = 10  -- frames, same cadence as the ghost watcher

-- ==========================================
-- LOGGING
-- ==========================================
-- Routes into the RM session log when it is available, so these
-- lines interleave with the ghost's own ledger. Reading a mint
-- against the ghost's `out` line in one file is the whole workflow.
-- ==========================================
local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- ==========================================
-- IDENTIFYING A MODULE LIQUID
-- ==========================================
-- Token match, the same handle the ghost's classifier trusts.
-- Vanilla liquids (water, lye, milk) are deliberately ignored: the
-- question is about this module's products, and including them
-- would bury the signal under every bucket in the fort.
-- ==========================================
local function module_token(it)
    local tok = nil
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        if mi then tok = tostring(mi:getToken()) end
    end)
    if tok and tok:upper():find('MAKING_FUEL_', 1, true) then
        return tok
    end
    return nil
end

-- Everything worth knowing about one liquid item, read defensively
-- because a half readable item is still evidence.
local function describe(it)
    local d = { id = it.id }
    pcall(function() d.stack = it.stack_size end)
    pcall(function() d.dim   = it.dimension end)
    d.token = module_token(it) or '(non module)'
    pcall(function()
        local c = dfhack.items.getContainer(it)
        if c then
            d.container = string.format('#%d %s', c.id,
                dfhack.items.getDescription(c, 0))
        end
    end)
    return d
end

local function fmt(d)
    return string.format(
        '#%d  %s  stack=%s  dimension=%s  in %s',
        d.id, tostring(d.token), tostring(d.stack),
        tostring(d.dim), tostring(d.container or '(loose, no container)'))
end

-- ==========================================
-- FINDING LIQUID ITEMS, AND CHECKING THE INSTRUMENT
-- ==========================================
-- Two independent scans on purpose. The typed vector is fast and is
-- what the module would use in production; items.all is slow and
-- cannot miss anything. If they ever disagree, the fast path is
-- blind to items inside containers and any production code built on
-- it would be blind the same way. That seam gets reported, not
-- assumed away.
-- ==========================================
local function scan_typed()
    local out, vec = {}, nil
    pcall(function() vec = df.global.world.items.other.LIQUID_MISC end)
    if not vec then
        pcall(function()
            vec = df.global.world.items.other[df.items_other_id.LIQUID_MISC]
        end)
    end
    if not vec then return nil end
    for _, it in ipairs(vec) do
        if module_token(it) then out[it.id] = it end
    end
    return out
end

local function scan_all()
    local out = {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.LIQUID_MISC
               and module_token(it) then
                out[it.id] = it
            end
        end
    end)
    return out
end

local function count_keys(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

local function instrument_check()
    local typed, all = scan_typed(), scan_all()
    if not typed then
        log('INSTRUMENT: typed LIQUID_MISC vector unreachable.'
            .. ' Falling back to a full item scan.')
        return
    end
    local nt, na = count_keys(typed), count_keys(all)
    if nt == na then
        log(string.format(
            'INSTRUMENT: typed vector and full scan agree at %d'
            .. ' module liquid item(s).', nt))
    else
        log(string.format(
            'INSTRUMENT DISAGREEMENT: typed vector sees %d, full scan'
            .. ' sees %d. The typed vector is missing items, most'
            .. ' likely ones inside containers.', nt, na))
        for id in pairs(all) do
            if not typed[id] then
                log('   missed by typed vector: #' .. id)
            end
        end
    end
end

-- ==========================================
-- WHAT THE GHOST WROTE
-- ==========================================
-- Reads the live reaction a job is pointing at and returns its
-- LIQUID product slots as they stand right now. This is the cause
-- side of the pairing: count is what the ghost's write_liquid set,
-- and product_dimension is what it would mint if it fires.
--
-- Read from the reaction the JOB names, which after the swap is the
-- ghost clone, so this is the live template DF will complete on.
-- ==========================================
local function liquid_slots_of(rname)
    local out = {}
    pcall(function()
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            if tostring(r.code) == rname then
                for i, p in ipairs(r.products) do
                    local itype = nil
                    pcall(function() itype = p.item_type end)
                    if itype == df.item_type.LIQUID_MISC then
                        local e = { slot = i - 1 }
                        pcall(function() e.count = p.count end)
                        pcall(function() e.dim = p.product_dimension end)
                        pcall(function()
                            if p.mat_type == 0 and p.mat_index >= 0 then
                                e.mat = tostring(df.global.world.raws
                                    .inorganics.all[p.mat_index].id)
                            end
                        end)
                        table.insert(out, e)
                    end
                end
                return
            end
        end
    end)
    return out
end

local function slots_text(slots)
    if #slots == 0 then return '(no liquid slots)' end
    local parts = {}
    for _, e in ipairs(slots) do
        table.insert(parts, string.format('[%d] %s count=%s dim=%s',
            e.slot, tostring(e.mat or '?'), tostring(e.count),
            tostring(e.dim)))
    end
    return table.concat(parts, '   ')
end

-- ==========================================
-- THE WATCHER
-- ==========================================
-- known    every module liquid id already seen, so only genuinely
--          new items are reported
-- recent   the last liquid slot state observed per job, kept so a
--          mint can still be attributed after its job has left the
--          list, which is usually the case by the time DF has
--          created the item
-- ==========================================
local known  = {}
local recent = {}
local tick   = 0

local function poll()
    if not dfhack.isMapLoaded() then return end
    tick = tick + 1

    -- ---- CAUSE SIDE ----
    -- Snapshot what every live custom reaction job has written to
    -- its liquid slots. Cheap, and it must happen before the item
    -- scan so a mint discovered this poll has its cause on hand.
    pcall(function()
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            if job.job_type == df.job_type.CustomReaction then
                local rname = tostring(job.reaction_name)
                local slots = liquid_slots_of(rname)
                if #slots > 0 then
                    recent[job.id] = { rname = rname, slots = slots,
                                       tick = tick }
                end
            end
        end
    end)

    -- ---- EFFECT SIDE ----
    -- Full scan rather than the typed vector: a probe that might be
    -- blind to contained items would answer this question wrongly
    -- in the safe looking direction.
    local now = scan_all()
    for id, it in pairs(now) do
        if not known[id] then
            known[id] = true
            local d = describe(it)
            log('MINT  ' .. fmt(d))
            -- Attribute it to whatever job wrote liquid slots most
            -- recently. Reported as an attribution, not a fact,
            -- because DF creates the item after the job is gone.
            local best, best_tick = nil, -1
            for jid, snap in pairs(recent) do
                if snap.tick > best_tick then
                    best, best_tick = { id = jid, snap = snap }, snap.tick
                end
            end
            if best then
                log(string.format('      caused by job %d %s',
                    best.id, best.snap.rname))
                log('      slots at that poll:  '
                    .. slots_text(best.snap.slots))
                local age = tick - best_tick
                if age > 3 then
                    log(string.format(
                        '      NOTE: that snapshot is %d polls old,'
                        .. ' attribution is weak.', age))
                end
            else
                log('      no recent job with liquid slots.'
                    .. ' Unattributed.')
            end
        end
    end

    -- Forget job snapshots that are far in the past, so attribution
    -- never quietly points at something ancient.
    for jid, snap in pairs(recent) do
        if tick - snap.tick > 60 then recent[jid] = nil end
    end
end

-- ==========================================
-- INVENTORY
-- ==========================================
-- The baseline. On the clean save this must print nothing, and
-- every MINT line afterwards is one Jay caused and can attribute.
-- ==========================================
local function inventory()
    log('==== MODULE LIQUID INVENTORY ====')
    local all = scan_all()
    local n = 0
    for _, it in pairs(all) do
        log('  ' .. fmt(describe(it)))
        n = n + 1
    end
    if n == 0 then
        log('  none. Clean baseline.')
    else
        log(string.format('  ---- %d module liquid item(s) ----', n))
    end
    instrument_check()
    log('==== END ====')
end

-- ==========================================
-- LIFECYCLE
-- ==========================================
function start()
    known, recent, tick = {}, {}, 0
    -- Seed with what already exists so the first poll does not
    -- report the whole fort as newly minted.
    for id in pairs(scan_all()) do known[id] = true end
    repeatUtil.scheduleEvery(REPEAT_KEY, POLL, 'frames', poll)
    log('Watching for new module liquid items. Every MINT line will'
        .. ' carry the product count that caused it.')
    log('Stop with:  probe-liquid-mint stop')
end

function stop()
    repeatUtil.cancel(REPEAT_KEY)
    log('Stopped watching.')
end

-- ==========================================
-- ARGS
-- ==========================================
local cmd = ...
if cmd == 'watch' then
    inventory()
    start()
elseif cmd == 'stop' then
    stop()
else
    inventory()
end
