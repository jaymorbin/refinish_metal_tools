-- probe-corpsepiece.lua
-- ==========================================
-- CORPSEPIECE CREATION PROBE
-- ==========================================
-- THREE QUESTIONS, in order:
--   1. Can we create a CORPSEPIECE at all, and which route works?
--   2. Does the thing we create ROT, the way a real hide does?
--   3. Can DF's tanner be stopped from taking it straight to leather?
--
-- Why it matters: hide denominations have to rot or raw hides become
-- a thing you stockpile forever and tanning stops being urgent. Tools
-- do not rot, so the tool pattern every other byproduct uses is out.
-- Corpsepieces rot, which means building one, and corpsepiece is the
-- item type that has broken four separate assumptions this week: no
-- mat_type, a getVolume that answers 350 for everything, quantity
-- hiding in material_amount, and no material pair at all.
--
-- ==========================================
-- THIS ONE WRITES
-- ==========================================
-- Every other probe in this project only reads. This one creates an
-- item, because there is no way to answer question 1 by looking. The
-- creation is behind an explicit `make` and produces exactly ONE item
-- per invocation, whose id is printed so it can be deleted.
--
-- `dump` and `watch` remain read-only.
--
-- ==========================================
-- USAGE
-- ==========================================
--   probe-corpsepiece dump
--       Every corpsepiece in the fort, with the fields that matter.
--       Run this FIRST: it gives the reference shape of a real skin
--       and a real bone to compare a built one against.
--
--   probe-corpsepiece make [MAT_TOKEN]
--       Builds one corpsepiece, trying each creation route in turn and
--       reporting which worked. MAT_TOKEN defaults to the material of
--       the first skin found, so the default case is "can we duplicate
--       what DF already made". Pass something else to test a tissue
--       the tanner should refuse, for example CREATURE:COW:HAIR.
--
--   probe-corpsepiece watch
--       Polls anything made by `make` and reports every field that
--       CHANGES, which is how rot gets identified without guessing
--       which field carries it. Also reports any TanAHide job and what
--       it attached, which answers question 3.
--
--   probe-corpsepiece stop
--
-- ==========================================
-- HOW TO RUN IT
-- ==========================================
--   dump, to see a real skin
--   make, to build one beside it
--   dump again, and compare the two blocks line for line
--   watch, then queue "tan a hide" and see which item the tanner takes
--   leave watch running a season to see whether the built one rots
-- ==========================================

local repeatUtil = require('repeat-util')
local utils      = require('utils')
local eventful   = require('plugins.eventful')

local REPEAT_KEY = 'probe_corpsepiece'
local EVENT_KEY  = 'probe_corpsepiece_job'
local TAG        = 'CORPSE PROBE: '

local made     = {}      -- ids this probe created, and their last field snapshot
local watching = false

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- ==========================================
-- READING AN ITEM WITHOUT GUESSING FIELD NAMES
-- ==========================================
-- Every scalar field on the struct, by iteration, rather than a
-- hand-written list. Which field carries rot is exactly what is not
-- known, and a list written from memory would omit it. Booleans and
-- numbers only: pointers and vectors are summarised separately.
-- ==========================================
local function scalars(it)
    local out = {}
    pcall(function()
        for k, v in pairs(it) do
            local t = type(v)
            if t == 'number' or t == 'boolean' then
                out[k] = v
            end
        end
    end)
    return out
end

-- The material, via matinfo rather than mat_type, because a
-- corpsepiece carries no material pair and reading mat_type throws.
local function mat_of(it)
    local tok = nil
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        tok = mi and mi:getToken() or nil
    end)
    return tok and tostring(tok) or '?'
end

-- Flag bitfields, listing only what is ON. Printed for corpse_flags
-- and for the general item flags, because either could be what makes
-- DF treat something as tannable.
local function flags_on(bf)
    local on = {}
    pcall(function()
        for k, v in pairs(bf) do
            if v == true then table.insert(on, k) end
        end
    end)
    table.sort(on)
    return #on > 0 and table.concat(on, ',') or '-'
end

local function dump_item(it, label)
    local id, ty = -1, '?'
    pcall(function() id = it.id end)
    pcall(function() ty = tostring(df.item_type[it:getType()]) end)

    local desc = '?'
    pcall(function() desc = dfhack.items.getDescription(it, 0) end)

    local vol = -1
    pcall(function() vol = it:getVolume() end)

    local amount = 0
    pcall(function()
        local ma = it.material_amount
        for i = 0, #ma - 1 do
            if ma[i] > amount then amount = ma[i] end
        end
    end)

    local race, caste = -1, -1
    pcall(function() race, caste = it.race, it.caste end)

    log(string.format('%s#%d %s  %s', label, id, ty, desc))
    log(string.format('    mat      %s', mat_of(it)))
    log(string.format('    race %d caste %d  vol %d  material_amount %d',
        race, caste, vol, amount))
    pcall(function()
        log(string.format('    corpse_flags  %s', flags_on(it.corpse_flags)))
    end)
    pcall(function()
        log(string.format('    item flags    %s', flags_on(it.flags)))
    end)

    -- Everything numeric, sorted, so the same call on a real skin and
    -- on a built one can be diffed by eye.
    local s, keys = scalars(it), {}
    for k in pairs(s) do table.insert(keys, k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        table.insert(parts, string.format('%s=%s', k, tostring(s[k])))
    end
    log('    scalars  ' .. table.concat(parts, ' '))
end

-- ==========================================
-- DUMP
-- ==========================================
local function cmd_dump()
    local n = 0
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSEPIECE then
                n = n + 1
                dump_item(it, '')
            end
        end
    end)
    if n == 0 then
        log('no corpsepieces in the fort. Butcher something first.')
    else
        log(string.format('%d corpsepiece(s) dumped.', n))
    end
end

-- ==========================================
-- MAKE
-- ==========================================
-- Two routes, tried in order, because which one DFHack supports for
-- this item type is the question. Both are attempted inside pcall and
-- the probe reports which succeeded rather than assuming.
--
-- ROUTE 1  dfhack.items.createItem, the normal path for everything
--          else. May refuse a type that needs race and caste set.
-- ROUTE 2  construct the struct directly and place it, then fill race,
--          caste and flags by copying the donor skin.
--
-- The donor is a real skin DF already built, so every field we cannot
-- name is inherited rather than invented.
-- ==========================================
local function find_donor()
    local donor = nil
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            if it:getType() == df.item_type.CORPSEPIECE then
                local tok = mat_of(it)
                if tok:upper():find(':SKIN') then donor = it return end
                if not donor then donor = it end   -- fall back to any piece
            end
        end
    end)
    return donor
end

local function cmd_make(token)
    local donor = find_donor()
    if not donor then
        log('no corpsepiece to copy from. Butcher something first.')
        return
    end

    log('donor:')
    dump_item(donor, '  ')

    -- Material to build with. Defaults to the donor's own, which makes
    -- the default question "can we duplicate what DF made".
    local mt, mi = nil, nil
    if token then
        pcall(function()
            local mi2 = dfhack.matinfo.find(token)
            if mi2 then mt, mi = mi2.type, mi2.index end
        end)
        if not mt then
            log('could not resolve material token ' .. tostring(token))
            return
        end
    else
        pcall(function()
            local m = dfhack.matinfo.decode(donor)
            if m then mt, mi = m.type, m.index end
        end)
    end
    log(string.format('building with mat_type %s mat_index %s',
        tostring(mt), tostring(mi)))

    local newit, route = nil, 'none'

    -- ROUTE 1
    pcall(function()
        local unit = nil
        for _, u in ipairs(df.global.world.units.active) do
            if dfhack.units.isCitizen(u) then unit = u break end
        end
        local r = dfhack.items.createItem(
            df.item_type.CORPSEPIECE, -1, mt, mi, unit)
        if r then newit, route = r, 'createItem' end
    end)

    -- ROUTE 2
    if not newit then
        pcall(function()
            local it = df.item_corpsepiecest:new()
            it.id = df.global.item_next_id
            df.global.item_next_id = df.global.item_next_id + 1
            it.race  = donor.race
            it.caste = donor.caste
            -- corpse_flags decide how DF treats the piece, so they are
            -- copied wholesale from a piece DF itself built rather
            -- than set field by field from a guess.
            pcall(function()
                for k, v in pairs(donor.corpse_flags) do
                    it.corpse_flags[k] = v
                end
            end)
            df.global.world.items.all:insert('#', it)
            local pos = dfhack.items.getPosition(donor)
            if pos then dfhack.items.moveToGround(it, pos) end
            newit, route = it, 'struct new + moveToGround'
        end)
    end

    if not newit then
        log('BOTH ROUTES FAILED. Creating a corpsepiece is not'
            .. ' available, and the hide denominations need a'
            .. ' different item shape or a creature host.')
        return
    end

    log(string.format('CREATED via %s', route))
    dump_item(newit, '  ')
    pcall(function() made[newit.id] = scalars(newit) end)
    log(string.format('watch it with:  probe-corpsepiece watch'))
    log(string.format('delete it with gui/gm-editor if it misbehaves.'
        .. ' Its id is %d', newit.id))
end

-- ==========================================
-- WATCH
-- ==========================================
-- Reports FIELD CHANGES rather than named fields, which is how rot
-- gets identified without knowing in advance what carries it. Also
-- reports any tanning job and what it attached, which is question 3.
-- ==========================================
local function poll()
    if not dfhack.isMapLoaded() then return end
    for id, before in pairs(made) do
        local it = nil
        pcall(function() it = df.item.find(id) end)
        if not it then
            log(string.format('#%d is GONE. Rotted away, or consumed.', id))
            made[id] = nil
        else
            local now = scalars(it)
            local diffs = {}
            for k, v in pairs(now) do
                if before[k] ~= v then
                    table.insert(diffs, string.format('%s %s -> %s',
                        k, tostring(before[k]), tostring(v)))
                end
            end
            if #diffs > 0 then
                table.sort(diffs)
                log(string.format('#%d changed: %s',
                    id, table.concat(diffs, ' | ')))
                made[id] = now
            end
        end
    end
end

-- Any tanning job, and what it picked up. If a built piece appears
-- here, DF considers it tannable and the processing gate has to come
-- from somewhere other than the item's own shape.
local function on_job(job)
    if not watching then return end
    pcall(function()
        if job.job_type ~= df.job_type.TanAHide then return end
        log(string.format('TanAHide job %d attached %d item(s):',
            job.id, #job.items))
        for _, iref in ipairs(job.items) do
            pcall(function()
                local it = iref.item
                local mine = made[it.id] and '  <-- BUILT BY THIS PROBE' or ''
                log(string.format('    #%d %s%s',
                    it.id, mat_of(it), mine))
            end)
        end
    end)
end

-- ==========================================
-- LIFECYCLE
-- ==========================================
function start_watch()
    watching = true
    eventful.onJobInitiated[EVENT_KEY] = on_job
    repeatUtil.scheduleEvery(REPEAT_KEY, 100, 'frames', poll)
    log(string.format('watching %d built item(s) for field changes, and'
        .. ' every TanAHide job.', (function()
            local n = 0 for _ in pairs(made) do n = n + 1 end return n
        end)()))
    log('queue "tan a hide" now to see which items the tanner accepts.')
    log('stop with:  probe-corpsepiece stop')
end

function stop()
    watching = false
    eventful.onJobInitiated[EVENT_KEY] = nil
    repeatUtil.cancel(REPEAT_KEY)
    log('stopped. Built item ids are still tracked if you restart watch.')
end

-- No `--@ module = true`, deliberately, and no start on load. This one
-- creates items; nothing should be able to trigger it by reqscripting
-- the file.
local cmd, arg1 = ...
if cmd == 'dump' then
    cmd_dump()
elseif cmd == 'make' then
    cmd_make(arg1)
elseif cmd == 'watch' then
    start_watch()
elseif cmd == 'stop' then
    stop()
else
    log('usage: probe-corpsepiece dump | make [MAT_TOKEN] | watch | stop')
    log('  start with dump, to see the shape of a real skin.')
end
