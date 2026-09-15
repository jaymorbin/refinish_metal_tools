-- refinish-fuel-quantity-test.lua
-- ==========================================
-- FUEL: QUANTITY, MATERIAL GATING, AND PROMPT
-- ==========================================
-- Three questions, one rig. Each independently switchable so a
-- failure in one does not hide a result in another.
--
-- ---- Q1: DOES quantity COUNT ITEMS ON A WIDENED FILTER? ----
-- Live job dumps show fuel at quantity 1 and metal at quantity 150.
-- The metal is measured by DIMENSION, the fuel is COUNTED. Once
-- item_type is opened to -1 the filter can match boulders, bars and
-- tools at once, and those do not share a dimension concept, so it
-- is an open question whether quantity 3 means three items, three
-- units of dimension, or fails to fill at all.
--
-- This matters because consumption rate is how fuel EFFECTIVENESS
-- gets modelled: a dung fire should burn several piles where
-- charcoal burns one bar. If quantity counts items, the whole
-- effectiveness system is one integer per job.
--
--   quantity N   sets every widened fuel filter to demand N.
--
-- Watch: are N items hauled, does the job fill, does it complete.
-- DF cancels a job it cannot fill, so an unfillable filter shows up
-- as an activate-cancel loop rather than a silent stall.
--
-- ---- Q2: DOES A MATERIAL FLAG NARROW THE MATCH? ----
-- job_item.flags3 carries wood, stone, metal. Setting wood should
-- restrict a widened filter to wooden items while reaction_class
-- still does the fuel test.
--
--   gate wood | gate stone | gate metal | gate none
--
-- Known limitation worth confirming rather than assuming: a wooden
-- DOOR is also wood. flags1 has a furniture bit but it is a
-- POSITIVE match with no negation, so this can narrow to a material
-- but probably cannot exclude furniture. If a hauler feeds the
-- smelter a bed, that is the answer.
--
-- ---- Q3: CAN THE PLAYER BE ASKED HOW MANY? ----
-- gui.dialogs is already proven in this codebase; refinish-panel-
-- config uses showListPrompt. showInputPrompt takes free text.
--
--   prompt      ask once, then apply that quantity to the next
--               fuel job that posts.
--
-- If this works, one reaction covers every batch size and the
-- combinatorial explosion of fixed quantity reactions disappears.
--
-- Usage:
--   refinish-fuel-quantity-test start
--   refinish-fuel-quantity-test quantity 3
--   refinish-fuel-quantity-test gate wood
--   refinish-fuel-quantity-test prompt
--   refinish-fuel-quantity-test report
--   refinish-fuel-quantity-test stop
--
-- Read/write on posted jobs only. Nothing persists.
-- ==========================================

local repeatUtil = require('repeat-util')
local dialogs    = require('gui.dialogs')

local REPEAT_KEY = 'refinish_fuel_quantity_test'
local TAG        = 'FUEL QTY: '

local FUEL_CLASS = 'FUEL'
local VECTOR     = 'IN_PLAY'

local want_qty  = 1
local want_gate = nil        -- 'wood' | 'stone' | 'metal' | nil
local widened   = {}
local watching  = {}         -- job id -> record, for the report

local function log(m) print(TAG .. m) end

-- ==========================================
-- FILTER WORK
-- ==========================================
local function is_fuel_filter(e)
    local hit = false
    pcall(function()
        if e.item_type == df.item_type.BAR
           and e.mat_type == df.builtin_mats.COAL then
            hit = true
        elseif tostring(e.reaction_class) == FUEL_CLASS then
            hit = true
        end
    end)
    return hit
end

local function widen(e)
    return pcall(function()
        e.item_type      = -1
        e.item_subtype   = -1
        e.mat_type       = -1
        e.mat_index      = -1
        e.reaction_class = FUEL_CLASS
        e.vector_id      = df.job_item_vector_id[VECTOR]
        e.quantity       = want_qty

        -- Material gate. Cleared first so switching gates mid
        -- session does not leave the previous one set.
        e.flags3.wood  = false
        e.flags3.stone = false
        e.flags3.metal = false
        if want_gate then e.flags3[want_gate] = true end
    end)
end

-- ==========================================
-- THE POLL
-- ==========================================
-- Also tracks each widened job so report can show what it actually
-- attached: how many items, of what, versus what was demanded.
-- ==========================================
local function poll()
    if not dfhack.isMapLoaded() then return end
    local ok, err = pcall(function()
        local live = {}
        local l = df.global.world.jobs.list.next
        while l do
            local j = l.item
            if j then
                live[j.id] = true
                if not widened[j.id] then
                    local hits = 0
                    pcall(function()
                        for _, e in ipairs(j.job_items.elements) do
                            if is_fuel_filter(e) and widen(e) then
                                hits = hits + 1
                            end
                        end
                    end)
                    if hits > 0 then
                        widened[j.id] = true
                        pcall(function() j.recheck_cntdn = 0 end)
                        watching[j.id] = {
                            jt = tostring(df.job_type[j.job_type]),
                            demanded = want_qty,
                            gate = want_gate or 'none',
                            attached = 0, items = {},
                        }
                        log(string.format(
                            'job %d %s: widened, demands %d, gate %s',
                            j.id, watching[j.id].jt, want_qty,
                            want_gate or 'none'))
                    end
                end

                -- Record what actually got attached, so the report
                -- can answer "did quantity count items".
                local w = watching[j.id]
                if w then
                    pcall(function()
                        local n = #j.items
                        if n > w.attached then
                            w.attached = n
                            w.items = {}
                            for _, ir in ipairs(j.items) do
                                local d = '?'
                                pcall(function()
                                    d = dfhack.items.getDescription(
                                        ir.item, 0)
                                end)
                                table.insert(w.items, d)
                            end
                        end
                    end)
                end
            end
            l = l.next
        end
        for id in pairs(widened) do
            if not live[id] then widened[id] = nil end
        end
    end)
    if not ok then log('POLL ERROR: ' .. tostring(err)) end
end

-- ==========================================
-- COMMANDS
-- ==========================================
local args = {...}
local cmd = args[1]

if cmd == 'start' then
    widened, watching = {}, {}
    repeatUtil.scheduleEvery(REPEAT_KEY, 5, 'frames', poll)
    log(string.format('active. class %s, quantity %d, gate %s',
        FUEL_CLASS, want_qty, want_gate or 'none'))

elseif cmd == 'quantity' and args[2] then
    want_qty = math.max(1, tonumber(args[2]) or 1)
    widened = {}   -- so already seen jobs get re-widened
    log('quantity set to ' .. want_qty
        .. '. Queue a fuel job and watch what gets hauled.')

elseif cmd == 'gate' then
    local g = args[2]
    if g == 'none' or g == nil then want_gate = nil
    elseif g == 'wood' or g == 'stone' or g == 'metal' then
        want_gate = g
    else
        log('gate must be wood, stone, metal or none')
        return
    end
    widened = {}
    log('material gate set to ' .. (want_gate or 'none'))

elseif cmd == 'prompt' then
    dialogs.showInputPrompt(
        'Fuel quantity',
        'How many fuel items should the next job burn?',
        COLOR_WHITE,
        tostring(want_qty),
        function(txt)
            local n = tonumber(txt)
            if n and n >= 1 then
                want_qty = math.floor(n)
                widened = {}
                log('quantity set to ' .. want_qty .. ' by prompt.')
            else
                log('not a number, quantity unchanged.')
            end
        end,
        function() log('prompt cancelled.') end)

elseif cmd == 'report' then
    local n = 0
    for id, w in pairs(watching) do
        n = n + 1
        print(string.format(
            '  job %d %s: demanded %d, gate %s, attached %d',
            id, w.jt, w.demanded, w.gate, w.attached))
        for _, d in ipairs(w.items) do
            print('      ' .. d)
        end
    end
    if n == 0 then print(TAG .. 'nothing watched yet.') end

elseif cmd == 'stop' then
    repeatUtil.cancel(REPEAT_KEY)
    widened, watching = {}, {}
    log('stopped.')

else
    print('usage: refinish-fuel-quantity-test'
        .. ' start | quantity N | gate wood|stone|metal|none'
        .. ' | prompt | report | stop')
end
