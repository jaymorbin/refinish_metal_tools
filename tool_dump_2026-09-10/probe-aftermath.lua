--@ module = true
-- probe-aftermath.lua
-- ==========================================
-- WHAT A CANCELLED JOB LEAVES BEHIND
-- ==========================================
-- ONE QUESTION: after a retort job is cancelled, what state survives
-- that could stop the NEXT job from running?
--
-- WHY. Measured twice: a job that follows a cancelled job on the same
-- stack attaches its base containers, sits, and fails without
-- consuming anything. A first job on the same stack runs fine. So
-- something the cancellation leaves is the difference, and guessing
-- which has already cost several rounds.
--
-- Run it BEFORE the cancel and AFTER, and diff the two dumps by eye.
-- The number that moved is the answer.
--
-- WHAT IT CHECKS, in the order they would break a job:
--
--   1. THE BASE REACTIONS. If an append ever landed on a base rather
--      than a ghost, every future job inherits reagents it can never
--      satisfy, and the failure would be permanent and exactly this
--      shape. The base should carry the reagent count its JSON
--      declares and never grow.
--
--   2. GHOST REACTIONS. One per job, named with the job id. A
--      cancelled job's ghost is never collapsed, so these accumulate.
--      Harmless in itself, but a large count means cleanup is not
--      running and is worth knowing.
--
--   3. ORPHANED CONTAINER CLAIMS. A container still flagged in_job
--      whose job no longer exists is a container permanently removed
--      from the fort. Enough of those and nothing can ever gather
--      again. This is the failure mode that would look exactly like
--      "attached two and sat there".
--
--   4. THE FEED ITEM. Whether the stack that was cancelled is still
--      flagged in_job, and what its counts read.
--
-- THIS PROBE ONLY READS.
--
-- USAGE
--   probe-aftermath          dump everything
-- ==========================================

local utils = require('utils')

local TAG = 'AFTERMATH: '

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- Job ids currently in the list, so a claim can be called orphaned.
local function live_job_ids()
    local live = {}
    pcall(function()
        for _, j in utils.listpairs(df.global.world.jobs.list) do
            live[j.id] = true
        end
    end)
    return live
end

-- ==========================================
-- 1. BASE REACTIONS
-- ==========================================
-- A base that has grown is the smoking gun: every job built from it
-- would demand containers it can never satisfy, permanently.
-- ==========================================
local function dump_bases()
    log('---- BASE REACTIONS (must not grow) ----')
    local n = 0
    pcall(function()
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            local code = tostring(r.code)
            if code:find('MAKING_FUEL_RXN_RETORT', 1, true)
               and not code:find('_GHOST_', 1, true) then
                local nr, np, vessels = -1, -1, 0
                pcall(function()
                    nr, np = #r.reagents, #r.products
                    for i = 0, nr - 1 do
                        if r.reagents[i].flags.PRESERVE_REAGENT then
                            vessels = vessels + 1
                        end
                    end
                end)
                -- Only the interesting ones, or this is 100 lines.
                if nr > 3 or vessels > 2 then
                    log(string.format('  GROWN? %-46s reagents=%d'
                        .. ' products=%d vessels=%d',
                        code, nr, np, vessels))
                    n = n + 1
                end
            end
        end
    end)
    if n == 0 then
        log('  every retort base is at its declared size. Good.')
    else
        log('  A GROWN BASE IS THE FAULT. Appends landed on a base')
        log('  instead of a ghost, and every future job inherits them.')
    end
end

-- ==========================================
-- 2. GHOST REACTIONS
-- ==========================================
local function dump_ghosts()
    local n, biggest, bname = 0, 0, ''
    pcall(function()
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            local code = tostring(r.code)
            if code:find('_GHOST_', 1, true) then
                n = n + 1
                local nr = #r.reagents
                if nr > biggest then biggest, bname = nr, code end
            end
        end
    end)
    log(string.format('---- GHOSTS ---- %d in the raws, largest %d'
        .. ' reagents (%s)', n, biggest, bname))
    if n > 20 then
        log('  These accumulate: a cancelled job is never collapsed,')
        log('  so its ghost and its appended reagents stay in the raws.')
    end
end

-- ==========================================
-- 3. ORPHANED CONTAINER CLAIMS
-- ==========================================
-- The failure mode that looks like "attached two and sat there": the
-- containers exist and read free to a naive count, but DF will not
-- hand them to anything because they are still claimed by a job that
-- no longer exists.
-- ==========================================
local function dump_containers(live)
    local total, free, claimed, orphaned, forbidden, held = 0, 0, 0, 0, 0, 0
    local orphan_ids = {}
    pcall(function()
        local vec = df.global.world.items.other.TOOL
        for _, it in ipairs(vec) do
            local is_lc = false
            pcall(function()
                for _, u in ipairs(it.subtype.tool_use) do
                    if u == df.tool_uses.LIQUID_CONTAINER then is_lc = true end
                end
            end)
            if is_lc then
                total = total + 1
                local inj, forb = false, false
                pcall(function() inj = it.flags.in_job end)
                pcall(function() forb = it.flags.forbid end)
                local n_held = 0
                pcall(function()
                    n_held = #(dfhack.items.getContainedItems(it) or {})
                end)
                if forb then forbidden = forbidden + 1
                elseif n_held > 0 then held = held + 1
                elseif inj then
                    claimed = claimed + 1
                    -- Is the claiming job still alive? DF does not
                    -- record which job on the item, so the test is
                    -- whether ANY live job holds it.
                    local owned = false
                    pcall(function()
                        for _, j in utils.listpairs(df.global.world.jobs.list) do
                            for _, iref in ipairs(j.items) do
                                if iref.item.id == it.id then owned = true end
                            end
                        end
                    end)
                    if not owned then
                        orphaned = orphaned + 1
                        if #orphan_ids < 12 then
                            table.insert(orphan_ids, it.id)
                        end
                    end
                else free = free + 1 end
            end
        end
    end)
    log(string.format('---- CONTAINERS ---- %d total: %d free, %d'
        .. ' forbidden, %d holding, %d claimed',
        total, free, forbidden, held, claimed))
    if orphaned > 0 then
        log(string.format('  ORPHANED CLAIMS: %d container(s) flagged'
            .. ' in_job with no live job holding them.', orphaned))
        log('  ids: ' .. table.concat(orphan_ids, ' '))
        log('  These are lost to the fort. A job cannot gather them,')
        log('  and enough of them looks exactly like the observed')
        log('  failure: attaches its base pair, sits, gives up.')
    else
        log('  no orphaned claims.')
    end
end

-- ==========================================
-- 4. THE FEED STOCK
-- ==========================================
local function dump_feed(live)
    log('---- CORPSEPIECES ----')
    local n = 0
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSEPIECE then
                local d, inj, sz = '?', false, '?'
                pcall(function() d = dfhack.items.getDescription(it, 0) end)
                pcall(function() inj = it.flags.in_job end)
                pcall(function() sz = tostring(it.stack_size) end)
                local amt = 0
                pcall(function()
                    local ma = it.material_amount
                    for i = 0, #ma - 1 do
                        if ma[i] > amt then amt = ma[i] end
                    end
                end)
                local owned = false
                if inj then
                    pcall(function()
                        for _, j in utils.listpairs(df.global.world.jobs.list) do
                            for _, iref in ipairs(j.items) do
                                if iref.item.id == it.id then owned = true end
                            end
                        end
                    end)
                end
                log(string.format('  #%-6d %-30s stack=%s amount=%d %s',
                    it.id, tostring(d), sz, amt,
                    inj and (owned and 'IN A LIVE JOB'
                             or 'CLAIMED BY NOTHING') or ''))
                n = n + 1
                if n >= 12 then return end
            end
        end
    end)
    if n == 0 then log('  none.') end
end

-- ==========================================
local live = live_job_ids()
log('==== AFTERMATH ====')
dump_bases()
dump_ghosts()
dump_containers(live)
dump_feed(live)
log('==== END ====')
