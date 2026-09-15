--@ module = true
-- test-retort-claims.lua
-- ==========================================
-- RETORT CLAIM TESTS
-- ==========================================
-- Every claim the retort fix rests on, checked and reported PASS or
-- FAIL. The point is to stop arguing from log readings. A claim that
-- cannot be checked reports SKIP and says what it needs, rather than
-- passing quietly.
--
-- Read the register first: RETORT_DEFECT_REGISTER.md. The three
-- assumptions the pending patch rests on are A1, A2 and A3 there, and
-- they are what the destructive tests below exist to settle.
--
-- USAGE
--   test-retort-claims           all read only checks, safe, instant
--   test-retort-claims reap      A1. destroys ONE null liquid
--   test-retort-claims watch     A2. arms the completion witness test
--   test-retort-claims stop      disarm the watcher
--
-- ORDER TO RUN THEM
--   1. test-retort-claims                    baseline
--   2. test-retort-claims reap               settles A1 immediately
--   3. test-retort-claims watch
--      run a retort job and LET IT FINISH    expect MINTED
--      run another and CANCEL it mid work    expect NOT MINTED
--      test-retort-claims stop
--   That sequence settles A1 and A2. A3 is covered by check 3 below.
-- ==========================================

local repeatUtil = require('repeat-util')
local utils      = require('utils')

local REPEAT_KEY = 'test_retort_claims'
local TAG        = 'RETORT TEST: '

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

local function verdict(ok, name, detail)
    log(string.format('%-4s %s', ok and 'PASS' or 'FAIL', name))
    if detail then log('       ' .. detail) end
end

local function skip(name, why)
    log(string.format('SKIP %s', name))
    log('       ' .. why)
end

-- ==========================================
-- SHARED READERS
-- ==========================================
local function module_token(it)
    local tok = nil
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        if mi then tok = tostring(mi:getToken()) end
    end)
    if tok and tok:upper():find('MAKING_FUEL_', 1, true) then return tok end
    return nil
end

-- Every module liquid in the world, contained or loose. Full scan
-- rather than a typed vector: a fast path blind to items inside jugs
-- would answer these questions wrongly in the reassuring direction.
local function module_liquids()
    local out = {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.LIQUID_MISC
               and module_token(it) then
                table.insert(out, it)
            end
        end
    end)
    return out
end

local function corpsepieces()
    local out = {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSEPIECE then
                table.insert(out, it)
            end
        end
    end)
    return out
end

local function contained_count(container)
    local n = -1
    pcall(function()
        n = #(dfhack.items.getContainedItems(container) or {})
    end)
    return n
end

-- ==========================================
-- CHECK 1. stack_size mirrors the product count
-- ==========================================
-- The discriminator the whole null reaper depends on. If a stack 0
-- module liquid ever turns out to be a real payout, the reaper
-- destroys paid product and the fix is wrong.
--
-- This cannot prove the pairing on its own, it reports the split so
-- an unexpected value shows up loudly.
-- ==========================================
local function check_liquid_stacks()
    local liq = module_liquids()
    local zero, one, other = 0, 0, {}
    for _, it in ipairs(liq) do
        local sz = nil
        pcall(function() sz = it.stack_size end)
        if sz == 0 then zero = zero + 1
        elseif sz == 1 then one = one + 1
        else table.insert(other, string.format('#%d stack=%s', it.id,
                 tostring(sz))) end
    end
    if #liq == 0 then
        skip('1. module liquid stack sizes',
             'no module liquids in the fort yet, run a retort first')
        return
    end
    verdict(#other == 0, '1. every module liquid is stack 0 or stack 1',
        string.format('%d null (stack 0), %d real (stack 1)%s',
            zero, one,
            #other > 0 and (', UNEXPECTED: ' .. table.concat(other, ', '))
            or ''))
    if #other > 0 then
        log('       A stack outside 0 and 1 breaks the reaper rule.'
            .. ' Do NOT apply the null reaper until this is explained.')
    end
end

-- ==========================================
-- CHECK 2. jugs held hostage by nulls
-- ==========================================
-- R4. Reports how many containers hold nothing but nulls, which is
-- the jug drain measured at two per job.
-- ==========================================
local function check_jug_occupancy()
    local held, free_if_reaped = 0, 0
    for _, it in ipairs(module_liquids()) do
        local sz = nil
        pcall(function() sz = it.stack_size end)
        if sz ~= nil and sz < 1 then
            pcall(function()
                local c = dfhack.items.getContainer(it)
                if c then
                    held = held + 1
                    if contained_count(c) == 1 then
                        free_if_reaped = free_if_reaped + 1
                    end
                end
            end)
        end
    end
    if held == 0 then
        skip('2. jugs held by nulls', 'no nulls present right now')
        return
    end
    verdict(true, '2. jugs currently held by null liquids',
        string.format('%d null(s) sitting in containers, %d container(s)'
            .. ' would be emptied by reaping them', held, free_if_reaped))
end

-- ==========================================
-- CHECK 3. where a corpsepiece keeps its count  (assumption A3)
-- ==========================================
-- The patch reads the LARGEST entry in material_amount as the count.
-- This prints every nonzero entry so a piece carrying two materials
-- shows up rather than being silently maxed over. It also confirms
-- stack_size is useless here, which is R1 and R5.
-- ==========================================
local function check_corpsepiece_count()
    local pieces = corpsepieces()
    if #pieces == 0 then
        skip('3. corpsepiece count field',
             'no corpsepieces in the fort, butcher something')
        return
    end
    local all_stack_one, multi = true, {}
    for _, it in ipairs(pieces) do
        local sz = nil
        pcall(function() sz = it.stack_size end)
        if sz ~= 1 then all_stack_one = false end
        pcall(function()
            local ma, nonzero = it.material_amount, {}
            for i = 0, #ma - 1 do
                if ma[i] ~= 0 then
                    table.insert(nonzero, string.format('[%d]=%d', i, ma[i]))
                end
            end
            if #nonzero > 1 then
                local d = '?'
                pcall(function() d = dfhack.items.getDescription(it, 0) end)
                table.insert(multi, string.format('#%d %s  %s',
                    it.id, d, table.concat(nonzero, ' ')))
            end
        end)
    end
    verdict(all_stack_one,
        '3a. every corpsepiece reads stack_size 1',
        all_stack_one
        and 'confirms the fraction and the burn test must not read it'
        or 'a corpsepiece with stack_size above 1 exists, which'
           .. ' contradicts the measured basis of the fix')
    verdict(#multi == 0,
        '3b. no corpsepiece carries two material amounts',
        #multi == 0
        and 'taking the largest entry is unambiguous on this stock'
        or ('AMBIGUOUS, largest entry is a guess on: '
            .. table.concat(multi, ' | ')))
end

-- ==========================================
-- CHECK 4. primed banks, the free payout state
-- ==========================================
-- R2. A bank at or above its package size will pay on the next job.
-- While R1 is unfixed that payout is free, so this is the check that
-- says whether the fort is currently minting value from nothing.
-- ==========================================
local function check_banks()
    local bank = _G.refinish_fuel_bank
    if type(bank) ~= 'table' then
        skip('4. bank balances', 'refinish_fuel_bank is not a table')
        return
    end
    local primed, lines = {}, {}
    for k, v in pairs(bank) do
        table.insert(lines, string.format('%s=%.6f', tostring(k), v))
        if v >= 1.0 then table.insert(primed, tostring(k)) end
    end
    table.sort(lines)
    if #lines == 0 then
        verdict(true, '4. no bank balances held', 'all banks empty')
        return
    end
    verdict(#primed == 0, '4. no bank is primed above one package',
        table.concat(lines, '  '))
    if #primed > 0 then
        log('       PRIMED: ' .. table.concat(primed, ', '))
        log('       While R1 is unfixed each of these pays a FREE unit'
            .. ' on the next job. Zero them:')
        for _, k in ipairs(primed) do
            log(string.format('         :lua refinish_fuel_bank.%s = 0', k))
        end
    end
end

-- ==========================================
-- CHECK 5. un-adapted reactions hiding in the retort set
-- ==========================================
-- R7. A reaction with any nonzero product count is excluded from the
-- adaptive engine entirely and says nothing about it. Reported from
-- the LIVE reactions rather than the JSON, because live is what runs.
-- ==========================================
local function check_adaptive_coverage()
    local bad = {}
    pcall(function()
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            local code = tostring(r.code)
            if code:find('MAKING_FUEL_RXN_RETORT', 1, true)
               or code:find('MAKING_FUEL_RXN_BOIL', 1, true) then
                if not code:find('_GHOST_', 1, true) then
                    local nonzero = {}
                    for i, p in ipairs(r.products) do
                        local c = nil
                        pcall(function() c = p.count end)
                        if c ~= nil and c ~= 0 then
                            table.insert(nonzero,
                                string.format('slot %d count=%d', i, c))
                        end
                    end
                    if #nonzero > 0 then
                        table.insert(bad, code .. ' (' ..
                            table.concat(nonzero, ', ') .. ')')
                    end
                end
            end
        end
    end)
    verdict(#bad == 0, '5. every retort and boil reaction is fully adaptive',
        #bad == 0 and 'no nonzero product counts found'
        or ('NOT adaptive, paying fixed output and silently excluded: '
            .. table.concat(bad, ' | ')))
end

-- ==========================================
-- READ ONLY SUITE
-- ==========================================
local function run_checks()
    log('==== RETORT CLAIM TESTS ====')
    check_liquid_stacks()
    check_jug_occupancy()
    check_corpsepiece_count()
    check_banks()
    check_adaptive_coverage()
    log('==== END ====')
end

-- ==========================================
-- TEST A1. does removing a null free its jug
-- ==========================================
-- DESTRUCTIVE, one item. The pending patch reaps nulls to put jugs
-- back in circulation, and that only works if the container reports
-- itself empty afterwards. dfhack.items.remove hides the item and
-- marks it for garbage collection; whether the container drops it
-- immediately is exactly what is unknown.
--
-- Picks one null sitting alone in a container, records the count,
-- removes it, and reads the count back.
-- ==========================================
local function test_reap()
    log('==== A1. REAP TEST ====')
    local target, container = nil, nil
    for _, it in ipairs(module_liquids()) do
        local sz = nil
        pcall(function() sz = it.stack_size end)
        if sz ~= nil and sz < 1 then
            local c = nil
            pcall(function() c = dfhack.items.getContainer(it) end)
            if c and contained_count(c) == 1 then
                target, container = it, c
                break
            end
        end
    end
    if not target then
        skip('A1. reap frees the jug',
             'no null found alone in a container. Run a retort job that'
             .. ' pays nothing, then try again.')
        log('==== END ====')
        return
    end

    local tid, cid = target.id, container.id
    local before = contained_count(container)
    log(string.format('  target null #%d in container #%d, contents before = %d',
        tid, cid, before))

    local ok, err = pcall(function() dfhack.items.remove(target) end)
    if not ok then
        verdict(false, 'A1. dfhack.items.remove succeeded',
            'threw: ' .. tostring(err))
        log('==== END ====')
        return
    end

    local after = contained_count(container)
    local still = nil
    pcall(function() still = df.item.find(tid) end)

    log(string.format('  contents after = %d, item still findable = %s',
        after, tostring(still ~= nil)))
    verdict(after == 0, 'A1. the container reports empty after the reap',
        after == 0
        and 'the jug goes back into circulation, the reaper is sound'
        or 'the container still holds something. The reaper will NOT'
           .. ' free jugs, and that half of the patch is wrong as'
           .. ' written.')
    log('==== END ====')
end

-- ==========================================
-- TEST A2. does a cancelled job mint into its vessels
-- ==========================================
-- The pending patch uses "a module liquid appeared in a vessel" as
-- proof the reaction completed. That is only sound if a CANCELLED job
-- mints nothing. If cancellations mint, the witness credits them and
-- the free payout comes straight back in a new form.
--
-- Watches every retort job, remembers its vessels and what they held,
-- and when the job leaves the list reports whether anything new
-- appeared. Run it once letting a job finish, once cancelling one.
-- ==========================================
local watched = {}

local function vessel_ids_of(job)
    local out = {}
    pcall(function()
        for _, iref in ipairs(job.items) do
            -- Any container the job is holding. Deliberately loose:
            -- this test must not depend on the same reagent mapping
            -- the code under test uses.
            local n = contained_count(iref.item)
            if n >= 0 then
                local had = {}
                pcall(function()
                    for _, cc in ipairs(
                            dfhack.items.getContainedItems(iref.item) or {}) do
                        had[cc.id] = true
                    end
                end)
                table.insert(out, { id = iref.item.id, had = had })
            end
        end
    end)
    return out
end

local function poll()
    if not dfhack.isMapLoaded() then return end

    local live = {}
    pcall(function()
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            if job.job_type == df.job_type.CustomReaction then
                local rn = tostring(job.reaction_name)
                if rn:find('RETORT', 1, true) or rn:find('BOIL', 1, true) then
                    live[job.id] = true
                    local w = watched[job.id]
                    local working = false
                    pcall(function() working = job.flags.working end)
                    if not w then
                        watched[job.id] = { rname = rn,
                                            vessels = vessel_ids_of(job),
                                            working = working }
                    elseif working and not w.working then
                        -- Refresh at the moment work starts, so the
                        -- baseline is what the vessels held going in.
                        w.vessels = vessel_ids_of(job)
                        w.working = true
                    end
                end
            end
        end
    end)

    for jid, w in pairs(watched) do
        if not live[jid] then
            local minted = {}
            for _, v in ipairs(w.vessels or {}) do
                pcall(function()
                    local c = df.item.find(v.id)
                    if not c then return end
                    for _, cc in ipairs(
                            dfhack.items.getContainedItems(c) or {}) do
                        if module_token(cc) and not v.had[cc.id] then
                            local sz = nil
                            pcall(function() sz = cc.stack_size end)
                            table.insert(minted, string.format(
                                '#%d stack=%s', cc.id, tostring(sz)))
                        end
                    end
                end)
            end
            if #minted > 0 then
                log(string.format('job %d %s ENDED: MINTED %s',
                    jid, w.rname, table.concat(minted, ', ')))
                log('       If you CANCELLED this job, assumption A2 is'
                    .. ' FALSE and the vessel witness is unsafe.')
            else
                log(string.format('job %d %s ENDED: NOT MINTED',
                    jid, w.rname))
                log('       If you LET THIS FINISH, the witness would'
                    .. ' have missed a real completion.')
            end
            watched[jid] = nil
        end
    end
end

function start()
    watched = {}
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log('A2 watcher armed. Run one retort job and LET IT FINISH,'
        .. ' then run one and CANCEL it mid work.')
    log('Expected: finished job says MINTED, cancelled job says NOT'
        .. ' MINTED. Anything else and the witness is unsafe.')
    log('Stop with:  test-retort-claims stop')
end

function stop()
    repeatUtil.cancel(REPEAT_KEY)
    log('A2 watcher disarmed.')
end

-- ==========================================
-- ARGS
-- ==========================================
local cmd = ...
if cmd == 'reap' then
    test_reap()
elseif cmd == 'watch' then
    run_checks()
    start()
elseif cmd == 'stop' then
    stop()
else
    run_checks()
end
