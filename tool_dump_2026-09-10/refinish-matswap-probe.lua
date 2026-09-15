-- refinish-matswap-probe.lua
-- ==========================================
-- PRODUCT MATERIAL REBIND PROBE
-- ==========================================
-- Answers one question, and RETORT_DRAIN depends entirely on it:
--
--   Does DF read a reaction product's MATERIAL at completion, the way
--   it reads count and dimension, or does it cache the material when
--   the job is created?
--
-- If it re-reads, the drain can carry two generic liquid slots and the
-- ghost can point them at whichever banks are fullest, per job. One
-- menu entry that drains whatever is actually there.
--
-- If it caches, that design is dead and the drain falls back to one
-- reaction per currency, which is thirteen menu entries.
--
-- WHY THE EXISTING EVIDENCE IS NOT ENOUGH
--
-- The ghost is compiled AFTER the job exists, and DF honours the
-- counts and dimensions written into it at runtime, so it clearly
-- re-reads the reaction rather than the job's creation-time copy. But
-- the ghost is a CLONE, so its materials are identical to the base's.
-- Nothing so far has ever asked DF to mint a material the job was not
-- created against. That is the whole gap this closes.
--
-- Nothing in making-fuel-ghost writes product materials at runtime, so
-- a swap made here will not be quietly overwritten by the next poll.
--
-- HOW IT WORKS
--
-- Armed, it watches for a live job running a MAKING_FUEL ghost, finds
-- the first liquid product bound to a container, rewrites that
-- product's material to a DIFFERENT module liquid, logs both, and
-- disarms itself. Then you watch what actually lands in the vessel.
--
--   new material in the vessel  -> DF re-reads. Design two is alive.
--   old material in the vessel  -> DF cached it. Design two is dead.
--
-- SAFETY
--
-- It changes ONE product on ONE job, once, then stops. The swap is a
-- material substitution between two module liquids, so the worst case
-- is a jug of the wrong module fluid, which is banked value in the
-- wrong pocket rather than anything lost. Run it on a corpse retort
-- you do not mind spending.
--
-- USAGE
--   refinish-matswap-probe            what is live right now
--   refinish-matswap-probe swap       swap it, now, on the spot
--
-- THE ARMED VERSION IS GONE. It scheduled itself through repeat-util
-- and never fired, and rather than debug DFHack's scheduling to find
-- out why, the listing already proved the thing that made arming
-- unnecessary: a live job is reachable from a manual command and sits
-- there long enough to act on. One less moving part between the
-- question and the answer.
--
-- So: queue the reaction, run the probe bare to confirm the job is
-- there, then run it with `swap`.
-- ==========================================

local utils = require('utils')

local args = {...}
local MODE = (args[1] or ''):lower()

local PREFIX = 'MAKING_FUEL_'

-- ==========================================
-- LOOKUPS
-- ==========================================

-- Every module inorganic, by index, so a swap target can be chosen and
-- both sides of the swap can be named in the log. A material reported
-- only as an index tells nobody anything.
local function module_inorganics()
    local out = {}
    pcall(function()
        for i, m in ipairs(df.global.world.raws.inorganics.all) do
            local id = tostring(m.id)
            if id:find(PREFIX, 1, true) then
                out[#out + 1] = { index = i, id = id }
            end
        end
    end)
    return out
end

local function inorganic_name(idx)
    local n = nil
    pcall(function()
        n = tostring(df.global.world.raws.inorganics.all[idx].id)
    end)
    return n or ('index ' .. tostring(idx))
end

-- The reaction a job is currently running, found by code rather than
-- by index, because the raws vector grows as ghosts are compiled.
local function reaction_of(job)
    local code, found = nil, nil
    pcall(function() code = tostring(job.reaction_name) end)
    if not code or code == '' then return nil, nil end
    pcall(function()
        for _, r in ipairs(df.global.world.raws.reactions.reactions) do
            if tostring(r.code) == code then found = r end
        end
    end)
    return found, code
end

-- Liquid products that are bound to a container. Those are the ones a
-- drain would ever want to repoint, and the only ones whose result is
-- visible afterwards by looking in a vessel.
local function liquid_slots(rxn)
    local out = {}
    pcall(function()
        for i = 0, #rxn.products - 1 do
            local p = rxn.products[i]
            local to = tostring(p.product_to_container or '')
            if to ~= '' and p.mat_type == 0 and p.mat_index >= 0 then
                out[#out + 1] = { at = i, mat_index = p.mat_index,
                                  to = to, count = p.count,
                                  dim = p.product_dimension }
            end
        end
    end)
    return out
end

local function ghosted_jobs()
    local out = {}
    pcall(function()
        for _, job in utils.listpairs(df.global.world.jobs.list) do
            local rxn, code = reaction_of(job)
            if rxn and code:find(PREFIX, 1, true)
               and code:find('_GHOST_', 1, true) then
                out[#out + 1] = { job = job, rxn = rxn, code = code }
            end
        end
    end)
    return out
end

-- ==========================================
-- REPORT
-- ==========================================

local function show()
    print('')
    print('PRODUCT MATERIAL REBIND PROBE')
    print('')
    local jobs = ghosted_jobs()
    if #jobs == 0 then
        print('  No job is running a MAKING_FUEL ghost right now.')
        print('  Queue a retort reaction and run this again, or use')
        print('  "arm" to have it wait for one.')
    else
        for _, e in ipairs(jobs) do
            print(string.format('  job %s  %s',
                  tostring(e.job.id), e.code))
            local slots = liquid_slots(e.rxn)
            if #slots == 0 then
                print('    no container bound liquid products')
            end
            for _, s in ipairs(slots) do
                print(string.format(
                    '    slot %-3d -> %-12s %-34s count %s dim %s',
                    s.at, s.to, inorganic_name(s.mat_index),
                    tostring(s.count), tostring(s.dim)))
            end
        end
    end

    local mats = module_inorganics()
    print('')
    print(string.format('  %d module inorganic(s) available as swap'
          .. ' targets.', #mats))
    print('')
end

-- ==========================================
-- THE SWAP
-- ==========================================

local function do_swap()
    local jobs = ghosted_jobs()
    if #jobs == 0 then
        print('')
        print('  Nothing to swap: no job is running a MAKING_FUEL ghost')
        print('  right now. Queue a retort reaction and try again while')
        print('  it is still gathering or working.')
        print('')
        return
    end

    for _, e in ipairs(jobs) do
        local slots = liquid_slots(e.rxn)
        if #slots > 0 then
            local s = slots[1]

            -- Any module liquid that is not the one already there.
            -- Preferring a DIFFERENT one is the entire point: swapping
            -- a material for itself would look like success no matter
            -- which way DF behaves, which is the non-discriminating
            -- test this project keeps writing.
            local target = nil
            for _, m in ipairs(module_inorganics()) do
                if m.index ~= s.mat_index then target = m break end
            end
            if not target then
                dfhack.printerr('Only one module inorganic exists, so'
                    .. ' there is nothing to swap to. Cannot test.')
                return
            end

            local before = inorganic_name(s.mat_index)
            local ok = pcall(function()
                e.rxn.products[s.at].mat_type  = 0
                e.rxn.products[s.at].mat_index = target.index
            end)
            if not ok then
                dfhack.printerr('The write itself failed. That is also'
                    .. ' an answer: the field is not writable here.')
                return
            end

            -- Read it back rather than trusting the write. A field that
            -- accepts an assignment and keeps its old value is a real
            -- possibility on injected structures and it would look
            -- exactly like a cached material afterwards.
            local now = nil
            pcall(function() now = e.rxn.products[s.at].mat_index end)
            if now ~= target.index then
                dfhack.printerr(string.format(
                    'The write did not stick: asked for %d, reads %d.'
                    .. ' Nothing further can be concluded from this run.',
                    target.index, tonumber(now) or -1))
                return
            end

            print('')
            print('MATSWAP DONE, now watch the vessel')
            print(string.format('  job      %s', tostring(e.job.id)))
            print(string.format('  reaction %s', e.code))
            print(string.format('  slot     %d, bound to %s', s.at, s.to))
            print(string.format('  was      %s', before))
            print(string.format('  now      %s', inorganic_name(now)))
            print('')
            print('  NOW material in the vessel  -> DF re-reads at')
            print('    completion. A generic drain works.')
            print('  WAS material in the vessel  -> DF cached it at job')
            print('    creation. The drain needs one reaction per')
            print('    currency instead.')
            print('  empty vessel or a null      -> the swap broke the')
            print('    product outright, which rules it out just as')
            print('    firmly.')
            print('')
            print('  The swapped slot is the FIRST container bound')
            print('  liquid product, so watch that vessel specifically.')
            print('')
            return
        end
    end

    print('')
    print('  A ghost job is running but none of its products is a')
    print('  container bound liquid, so there is nothing to repoint.')
    print('')
end

-- ==========================================
-- MAIN
-- ==========================================

if MODE == 'swap' then
    do_swap()
else
    show()
    if MODE == 'arm' then
        print('  "arm" is gone. Run this bare to confirm a job is')
        print('  live, then run "refinish-matswap-probe swap".')
        print('')
    end
end