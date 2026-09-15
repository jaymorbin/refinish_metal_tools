-- refinish-reagent-prompt-test.lua
-- ==========================================
-- ASK THE PLAYER HOW MANY
-- ==========================================
-- One reaction, any batch size. Click CHAR_SKULL and answer "how
-- many skulls", instead of shipping CHAR_SKULL_1, _5, _10 and
-- discovering the eleventh case a week after release.
--
-- HOW IT WORKS
--   A job posts. Within a few frames the poll sees it, SUSPENDS it
--   so no hauler can claim anything, and shows an input prompt. The
--   answer is written to the reagent's quantity, then the job is
--   unsuspended and fills normally.
--
--   Suspending first is the whole trick. Filters stop deciding
--   anything the moment an item is attached, so a prompt the player
--   takes four seconds to answer would otherwise arrive too late.
--
-- WHY THE OUTPUT STILL COMES OUT RIGHT
--   The adaptive system reads what was actually consumed rather
--   than what the raws declared, so raising a reagent quantity
--   raises the yield with no second edit. That is the same property
--   that makes the whole module work: the reaction declares zero
--   and the ghost fills it from real items.
--
-- WHICH REAGENT
--   Fuel filters are skipped: those are the module's business, not
--   the player's. The prompt targets the first NON fuel reagent,
--   which on a single input reaction is the only one there is.
--
-- Usage:
--   refinish-reagent-prompt-test arm CHAR_SKULL
--       Prompt whenever that reaction posts. Repeat to arm several.
--   refinish-reagent-prompt-test armall
--       Prompt on EVERY custom reaction. Blunt, for finding out
--       which reaction codes actually reach a posted job.
--   refinish-reagent-prompt-test max 20
--       Ceiling on the answer. Asking for 500 skulls posts a job
--       that can never fill and loops on cancel.
--   refinish-reagent-prompt-test start | stop | list
--
-- Nothing persists. Quantities live on posted jobs.
-- ==========================================

local repeatUtil = require('repeat-util')
local dialogs    = require('gui.dialogs')

local REPEAT_KEY = 'refinish_reagent_prompt_test'
local TAG        = 'REAGENT PROMPT: '

local armed     = {}      -- reaction code -> true
local arm_all   = false
local max_qty   = 20
local handled   = {}      -- job id -> true, one prompt per job
local pending   = {}      -- job id -> true, prompt on screen

local function log(m) print(TAG .. m) end

-- A fuel filter is the module's, not the player's. Same signature
-- the fuel access poll uses.
local function is_fuel_filter(e)
    local hit = false
    pcall(function()
        if e.item_type == df.item_type.BAR
           and e.mat_type == df.builtin_mats.COAL then
            hit = true
        else
            local rc = tostring(e.reaction_class)
            if rc == 'FUEL' or rc:find('FUEL', 1, true) == 1 then
                hit = true
            end
        end
    end)
    return hit
end

-- First reagent that is not fuel, with its index.
local function player_reagent(j)
    local found, idx = nil, nil
    pcall(function()
        for i, e in ipairs(j.job_items.elements) do
            if not is_fuel_filter(e) then
                found, idx = e, i
                return
            end
        end
    end)
    return found, idx
end

local function describe_reagent(e)
    local t, sub, q = '?', '', 1
    pcall(function() t = tostring(df.item_type[e.item_type]) end)
    pcall(function()
        if e.item_subtype and e.item_subtype >= 0 then
            sub = '/' .. tostring(e.item_subtype)
        end
    end)
    pcall(function() q = e.quantity end)
    return string.format('%s%s (currently %d)', t, sub, q)
end

local function ask(j, code)
    local e, idx = player_reagent(j)
    if not e then
        log('job ' .. j.id .. ' has no non fuel reagent, skipped.')
        handled[j.id] = true
        return
    end

    -- Suspend BEFORE asking. An unsuspended job fills while the
    -- prompt is open and the answer arrives too late to matter.
    pcall(function() j.flags.suspend = true end)
    pending[j.id] = true

    local jid = j.id
    dialogs.showInputPrompt(
        tostring(code),
        string.format('How many?  %s\nMaximum %d.',
            describe_reagent(e), max_qty),
        COLOR_WHITE,
        '1',
        function(txt)
            local n = tonumber(txt)
            local job = nil
            local l = df.global.world.jobs.list.next
            while l do
                if l.item and l.item.id == jid then job = l.item break end
                l = l.next
            end
            pending[jid] = nil
            handled[jid] = true
            if not job then
                log('job ' .. jid .. ' vanished while asking.')
                return
            end
            if n and n >= 1 then
                n = math.min(math.floor(n), max_qty)
                local ok = pcall(function()
                    job.job_items.elements[idx].quantity = n
                end)
                log(string.format(
                    'job %d %s: reagent[%d] quantity -> %d%s',
                    jid, tostring(code), idx, n,
                    ok and '' or '  (WRITE FAILED)'))
            else
                log('job ' .. jid .. ': not a number, left at 1.')
            end
            pcall(function()
                job.flags.suspend = false
                job.recheck_cntdn = 0
            end)
        end,
        function()
            -- Cancelled: leave the job at its declared quantity and
            -- release it, rather than stranding a suspended job.
            pending[jid] = nil
            handled[jid] = true
            local job = nil
            local l = df.global.world.jobs.list.next
            while l do
                if l.item and l.item.id == jid then job = l.item break end
                l = l.next
            end
            if job then
                pcall(function()
                    job.flags.suspend = false
                    job.recheck_cntdn = 0
                end)
            end
            log('job ' .. jid .. ': cancelled, quantity unchanged.')
        end)
end

local function poll()
    if not dfhack.isMapLoaded() then return end
    local ok, err = pcall(function()
        local live = {}
        local l = df.global.world.jobs.list.next
        while l do
            local j = l.item
            if j then
                live[j.id] = true
                if not handled[j.id] and not pending[j.id] then
                    local code = nil
                    pcall(function() code = tostring(j.reaction_name) end)
                    if code and code ~= ''
                       and (arm_all or armed[code]) then
                        -- Only ask if nothing is attached yet.
                        local att = 0
                        pcall(function() att = #j.items end)
                        if att == 0 then
                            ask(j, code)
                        else
                            handled[j.id] = true
                        end
                    end
                end
            end
            l = l.next
        end
        for id in pairs(handled) do
            if not live[id] then handled[id] = nil end
        end
    end)
    if not ok then log('POLL ERROR: ' .. tostring(err)) end
end

local args = {...}
local cmd = args[1]

if cmd == 'arm' and args[2] then
    armed[args[2]] = true
    log('armed ' .. args[2])

elseif cmd == 'armall' then
    arm_all = true
    log('armed EVERY custom reaction. Expect a prompt per job.')

elseif cmd == 'max' and args[2] then
    max_qty = math.max(1, tonumber(args[2]) or 20)
    log('ceiling set to ' .. max_qty)

elseif cmd == 'list' then
    local n = 0
    for c in pairs(armed) do print('  ' .. c) n = n + 1 end
    print(string.format('%s%d armed, armall=%s, max=%d',
        TAG, n, tostring(arm_all), max_qty))

elseif cmd == 'start' then
    handled, pending = {}, {}
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log('active. Queue an armed reaction.')

elseif cmd == 'stop' then
    repeatUtil.cancel(REPEAT_KEY)
    handled, pending = {}, {}
    log('stopped.')

else
    print('usage: refinish-reagent-prompt-test'
        .. ' arm CODE | armall | max N | start | stop | list')
end
