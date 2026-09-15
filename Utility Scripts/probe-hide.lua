-- probe-hide.lua
-- ==========================================
-- HIDE PROBE
-- ==========================================
-- ONE QUESTION: does a skin corpsepiece carrying material_amount.Leather
-- of N tan into N leathers?
--
-- If yes, size proportionate hides are a count written onto an item,
-- and the denomination ladder is just numbers. If no, the count has to
-- live somewhere else and we will know that instead of guessing it.
--
-- ==========================================
-- WHY THIS FILE BUILDS NOTHING ITSELF
-- ==========================================
-- Two earlier probes crashed the game trying to construct a
-- corpsepiece by hand. The reason, found by reading DFHack's own
-- source rather than by theorising: a corpsepiece is not a simple
-- item. A valid one carries all of this, and DF walks it every tick.
--
--   race, normal_race, normal_caste, sex
--   largest_tissue.mat_type / .mat_index
--   largest_unrottable_tissue.mat_type / .mat_index
--   body.bp_modifiers                   200 entries
--   body.body_part_relsize              one per body part, from raws
--   body.components.body_part_status    one per part, copied off a unit
--   body.components.layer_status        one per layer, copied off a unit
--   corpse_flags appropriate to the tissue
--   material_amount at the matching index
--   caste, WHICH MUST BE WRITTEN LAST
--
-- That last one is not our finding. modtools/create-item carries the
-- comment "DO THIS LAST or else the game crashes for some reason" on
-- the line that sets caste. The earlier probe set caste second.
--
-- So this file constructs nothing. It calls the function that already
-- does all of the above correctly, which is what gui/create-item calls
-- when you spawn a skin by hand.
--
-- ==========================================
-- HOW IT DRIVES THAT FUNCTION
-- ==========================================
-- modtools/create-item is `--@module=true` with a guard at the top of
-- its main body, so reqscript loads it without triggering a wish
-- prompt. Its `hackWish` is a global, and it takes an ACCESSORS table:
-- a set of callbacks that answer "which item type", "which creature",
-- "which tissue". gui/create-item fills those with GUI prompts. We
-- fill them with plain returns. Same function, no dialogs.
--
-- The accessor contract, read off gui/create-item:
--   get_mat(itype, opts) returns
--     ok, mattype, matindex, casteId, bodypart, partlayerID, generic
--   and for a GENERIC corpsepiece (one made of a whole tissue rather
--   than one named body part) that is:
--     true, -1, raceId, casteId, 1, <material index>, true
--   where <material index> indexes creature.material and selects the
--   tissue by name. Generic is what we want: it un-hides every body
--   part made of that tissue, which is a whole animal's hide rather
--   than one leg's worth.
--
-- ==========================================
-- WHAT IT WRITES
-- ==========================================
-- Exactly one field, material_amount, and only AFTER hackWish has
-- returned a finished item. That field is not fragile: our own bone
-- work measured DF decrementing it six consecutive times as a stack
-- was eaten into. Changing its value is not the same kind of act as
-- building an item out of nothing.
--
-- `dump` and `watch` write nothing at all.
--
-- ==========================================
-- USAGE
-- ==========================================
--   probe-hide dump
--       Every corpsepiece in the fort with the fields that matter.
--       Run this on a FRESH butchered skin before it rots, so there is
--       a real one to compare a spawned one against.
--
--   probe-hide make CREATURE [COUNT] [TISSUE]
--       e.g.  probe-hide make WATER_BUFFALO 4
--       Spawns one generic corpsepiece of that tissue (default SKIN)
--       and sets its count to COUNT (default 4).
--
--   probe-hide watch
--       Reports every TanAHide job, what went in and what came out,
--       and marks anything this probe made. That is the answer.
--
--   probe-hide stop
--
-- ORDER TO RUN IT IN
--   butcher something, then immediately:
--   dump                       see a real skin's flags and count
--   make WATER_BUFFALO 4       spawn one beside it
--   dump                       diff the two blocks line for line
--   watch, then queue "tan a hide"
--   count the leather
-- ==========================================

local repeatUtil = require('repeat-util')
local eventful   = require('plugins.eventful')

local REPEAT_KEY = 'probe_hide'
local EVENT_KEY  = 'probe_hide_job'
local TAG        = 'HIDE PROBE: '

local made     = {}     -- id -> last scalar snapshot, for the rot watch
local watching = false

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- ==========================================
-- TISSUE TO COUNT FIELD
-- ==========================================
-- material_amount is an array indexed by df.corpse_material_type, and
-- the index names the PRODUCT the piece yields, not the tissue it is
-- made of. A skin yields leather so its count sits at Leather. A bone
-- sits at Bone. This table is lifted from the flag branches in
-- createCorpsePiece rather than worked out from first principles.
--
-- SCALE is deliberately absent: modtools/create-item has no branch for
-- it either, so a scale piece gets no flag and no count field. That is
-- a real gap and reptiles will need handling separately.
-- ==========================================
local COUNT_FIELD = {
    SKIN  = 'Leather',
    BONE  = 'Bone',
    HAIR  = 'HairWool',
    TOOTH = 'Tooth',
    IVORY = 'Tooth',
    HORN  = 'Horn',
    HOOF  = 'Horn',
    SHELL = 'Shell',
}

-- ==========================================
-- REPORTING HELPERS
-- ==========================================

-- matinfo, not mat_type. A corpsepiece carries no material pair and
-- reading mat_type on one throws.
local function mat_of(it)
    local tok = nil
    pcall(function()
        local mi = dfhack.matinfo.decode(it)
        tok = mi and mi:getToken() or nil
    end)
    return tok and tostring(tok) or '?'
end

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

-- The whole material_amount array, every nonzero slot, named by the
-- enum. Printed in full because a count landing at the wrong index
-- looks identical to a count not landing at all.
local function amounts(it)
    local parts = {}
    pcall(function()
        local ma = it.material_amount
        for i = 0, #ma - 1 do
            if ma[i] ~= 0 then
                table.insert(parts, string.format('%s(%d)=%d',
                    tostring(df.corpse_material_type[i] or '?'), i, ma[i]))
            end
        end
    end)
    return #parts > 0 and table.concat(parts, ' ') or 'all zero'
end

-- Every scalar on the struct, by iteration rather than a list I wrote,
-- because which field carries rot is exactly what is being watched and
-- a list from memory would leave it out.
local function scalars(it)
    local out = {}
    pcall(function()
        for k, v in pairs(it) do
            local t = type(v)
            if t == 'number' or t == 'boolean' then out[k] = v end
        end
    end)
    return out
end

-- body vector lengths. These are the fields the earlier probe left
-- empty, which is what DF choked on, so they are worth seeing filled.
local function body_shape(it)
    local a, b, c = -1, -1, -1
    pcall(function() a = #it.body.bp_modifiers end)
    pcall(function() b = #it.body.components.body_part_status end)
    pcall(function() c = #it.body.components.layer_status end)
    return string.format('bp_modifiers %d  body_part_status %d  layer_status %d',
        a, b, c)
end

local function dump_item(it, label)
    local id, desc, vol = -1, '?', -1
    pcall(function() id = it.id end)
    pcall(function() desc = dfhack.items.getDescription(it, 0) end)
    pcall(function() vol = it:getVolume() end)

    log(string.format('%s#%d  %s', label, id, desc))
    log(string.format('    mat        %s', mat_of(it)))
    pcall(function()
        log(string.format('    race %d caste %d  vol %d',
            it.race, it.caste, vol))
    end)
    log(string.format('    amounts    %s', amounts(it)))
    pcall(function()
        log(string.format('    corpse_fl  %s', flags_on(it.corpse_flags)))
    end)
    pcall(function()
        log(string.format('    item_fl    %s', flags_on(it.flags)))
    end)
    log(string.format('    body       %s', body_shape(it)))
end

-- ==========================================
-- DUMP, read only
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
        log('no corpsepieces in the fort. Butcher something first, and'
            .. ' dump before it rots.')
    else
        log(string.format('%d corpsepiece(s).', n))
    end
end

-- ==========================================
-- MAKE
-- ==========================================
-- Finds the creature, finds the tissue's index in its material list,
-- then hands both to hackWish and lets DFHack build the item.
-- ==========================================
local function cmd_make(creature, count, tissue)
    if not creature then
        log('usage: probe-hide make CREATURE [COUNT] [TISSUE]')
        log('example: probe-hide make WATER_BUFFALO 4')
        return
    end
    tissue = (tissue or 'SKIN'):upper()
    count  = tonumber(count) or 4
    creature = creature:upper()

    -- ---- THE CREATURE ----
    local race_id, race_raw = nil, nil
    pcall(function()
        for i, cr in ipairs(df.global.world.raws.creatures.all) do
            if tostring(cr.creature_id):upper() == creature then
                race_id, race_raw = i, cr
                return
            end
        end
    end)
    if not race_id then
        log('no creature called ' .. creature)
        return
    end

    -- ---- THE TISSUE, AS AN INDEX INTO creature.material ----
    -- createCorpsePiece reads the generic tissue as
    -- creatorRaceRaw.material[partlayer].id, so partlayer is a direct
    -- zero based index into that list. Found by name, never assumed.
    local mat_idx = nil
    pcall(function()
        for i, m in ipairs(race_raw.material) do
            if tostring(m.id):upper() == tissue then mat_idx = i return end
        end
    end)
    if not mat_idx then
        local have = {}
        pcall(function()
            for _, m in ipairs(race_raw.material) do
                table.insert(have, tostring(m.id))
            end
        end)
        log(creature .. ' has no tissue called ' .. tissue)
        log('  it has: ' .. table.concat(have, ' '))
        return
    end
    log(string.format('%s tissue %s is material index %d',
        creature, tissue, mat_idx))

    -- ---- A CREATOR UNIT ----
    -- createCorpsePiece copies body_part_status[0] and layer_status[0]
    -- off this unit as a template for the new item's body vectors, so
    -- it needs a real live one. hackWish falls back to a citizen if we
    -- return nil, but being explicit makes the failure legible.
    local unit = nil
    pcall(function()
        local cits = dfhack.units.getCitizens(true)
        if cits and cits[1] then unit = cits[1] end
    end)
    if not unit then
        log('no citizen available to act as creator. Cannot build.')
        return
    end

    -- ---- THE ACCESSORS ----
    -- Same contract gui/create-item fills with dialogs. get_quality and
    -- get_description are never reached for a CORPSEPIECE, and
    -- get_count is skipped because opts.count is set, but they are
    -- supplied so a change upstream cannot nil-call.
    local accessors = {
        get_unit        = function() return unit end,
        get_item_type   = function()
            return true, df.item_type.CORPSEPIECE, -1
        end,
        get_mat         = function()
            -- ok, mattype, matindex, caste, bodypart, partlayer, generic
            return true, -1, race_id, 0, 1, mat_idx, true
        end,
        get_quality     = function() return true, df.item_quality.Ordinary end,
        get_description = function() return true, '' end,
        get_count       = function() return true, 1 end,
    }

    local created = nil
    local ok, err = pcall(function()
        local mod = reqscript('modtools/create-item')
        created = mod.hackWish(accessors, { count = 1, pos = unit.pos })
    end)
    if not ok then
        log('hackWish threw: ' .. tostring(err))
        return
    end
    if not created or #created == 0 then
        log('hackWish returned nothing. No item exists.')
        return
    end

    local it = created[1]
    log('BUILT, before the count is written:')
    dump_item(it, '  ')

    -- ---- THE ONE FIELD WE WRITE ----
    -- After hackWish has returned, so caste is already set and the item
    -- is complete. createCorpsePiece writes 1 here for a skin; we are
    -- changing a value, not introducing a field.
    local field = COUNT_FIELD[tissue]
    if not field then
        log(tissue .. ' has no count field in DF. Item left as built.')
    else
        local wrote = pcall(function() it.material_amount[field] = count end)
        if wrote then
            log(string.format('set material_amount.%s = %d', field, count))
        else
            log('could not write material_amount.' .. field)
        end
        log('AFTER:')
        dump_item(it, '  ')
    end

    made[it.id] = scalars(it)
    log(string.format('id %d. Now:  probe-hide watch', it.id))
    log('then queue "tan a hide" and count the leather.')
end

-- ==========================================
-- WATCH
-- ==========================================
-- Field CHANGES rather than named fields, so rot identifies itself
-- without me deciding in advance which field carries it.
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
            local now, diffs = scalars(it), {}
            for k, v in pairs(now) do
                if before[k] ~= v then
                    table.insert(diffs, string.format('%s %s -> %s',
                        k, tostring(before[k]), tostring(v)))
                end
            end
            if #diffs > 0 then
                table.sort(diffs)
                log(string.format('#%d changed: %s | amounts %s',
                    id, table.concat(diffs, ' | '), amounts(it)))
                made[id] = now
            end
        end
    end
end

-- Tanning, both ends. onJobInitiated shows what went in while the
-- items still exist; onJobCompleted shows what came out.
local tan_snap = {}

local function on_init(job)
    if not watching then return end
    pcall(function()
        if job.job_type ~= df.job_type.TanAHide then return end
        log(string.format('TanAHide %d STARTED, %d item(s):',
            job.id, #job.items))
        for _, iref in ipairs(job.items) do
            pcall(function()
                local it = iref.item
                log(string.format('    in  #%d %s  amounts %s%s',
                    it.id, mat_of(it), amounts(it),
                    made[it.id] and '   <-- MADE BY THIS PROBE' or ''))
            end)
        end
        local before, bid = {}, nil
        pcall(function()
            local b = dfhack.job.getHolder(job)
            if not b then return end
            bid = b.id
            for _, ci in ipairs(b.contained_items) do
                pcall(function()
                    if ci.item then before[ci.item.id] = true end
                end)
            end
        end)
        tan_snap[job.id] = { before = before, bid = bid }
    end)
end

local function on_done(job)
    if not watching then return end
    pcall(function()
        if job.job_type ~= df.job_type.TanAHide then return end
        local s = tan_snap[job.id]
        if not s then return end
        tan_snap[job.id] = nil

        local n, rows = 0, {}
        pcall(function()
            local b = df.building.find(s.bid)
            if not b then return end
            for _, ci in ipairs(b.contained_items) do
                pcall(function()
                    local it = ci.item
                    if not it or s.before[it.id] then return end
                    local stack = 1
                    pcall(function() stack = it.stack_size or 1 end)
                    n = n + stack
                    table.insert(rows, string.format('    out #%d %s x%d',
                        it.id, mat_of(it), stack))
                end)
            end
        end)
        for _, r in ipairs(rows) do log(r) end
        log(string.format('TanAHide %d FINISHED: %d leather.', job.id, n))
        log('  more than 1 means material_amount drives tanning output.')
    end)
end

-- ==========================================
-- LIFECYCLE
-- ==========================================
function start_watch()
    watching = true
    eventful.onJobInitiated[EVENT_KEY] = on_init
    eventful.onJobCompleted[EVENT_KEY] = on_done
    repeatUtil.scheduleEvery(REPEAT_KEY, 100, 'frames', poll)
    log('watching. Queue "tan a hide" now.')
    log('stop with:  probe-hide stop')
end

function stop()
    watching = false
    eventful.onJobInitiated[EVENT_KEY] = nil
    eventful.onJobCompleted[EVENT_KEY] = nil
    repeatUtil.cancel(REPEAT_KEY)
    log('stopped.')
end

-- No module flag and no start on load, so nothing can set this running
-- by reqscripting the file.
local cmd, a1, a2, a3 = ...
if cmd == 'dump' then
    cmd_dump()
elseif cmd == 'make' then
    cmd_make(a1, a2, a3)
elseif cmd == 'watch' then
    start_watch()
elseif cmd == 'stop' then
    stop()
else
    log('usage:')
    log('  probe-hide dump')
    log('  probe-hide make CREATURE [COUNT] [TISSUE]')
    log('  probe-hide watch')
    log('  probe-hide stop')
end
