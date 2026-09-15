--@ module = true
-- probe-bone-item.lua
-- ==========================================
-- BONE ITEM PROBE
-- ==========================================
-- TWO QUESTIONS, and they need opposite fixes:
--
--   1. Is "peasant bone [11]" ONE bone or ELEVEN bones? The bracket
--      is a display string. This reads the actual fields instead:
--      stack_size, material_amount, and how many body parts the
--      piece still has. Whichever number is 11 is what the bracket
--      means.
--
--   2. When a retort job runs, WHICH field decrements? The ghost
--      currently reads stack_size for both its value fraction and
--      its consumed test, and the session arithmetic says stack_size
--      is not moving. If the count lives somewhere else, that is the
--      field both of those have to read.
--
-- WHY IT MATTERS. If the item is eleven bones, DF taking one per job
-- is correct and the only fault is that the ghost credits the whole
-- pile every job (measured at 8.7x over five runs). If it is ONE
-- bone being consumed in elevenths, the reagent side is wrong and
-- that is a different and worse fault. The dump below separates
-- them.
--
-- THIS PROBE ONLY READS. It changes nothing.
--
-- USAGE
--   probe-bone-item            dump every bone piece in the fort now
--   probe-bone-item watch      dump, then report every field change
--   probe-bone-item stop       stop watching
--
-- HOW TO RUN IT
--   1. probe-bone-item          read the BEFORE state
--   2. probe-bone-item watch
--   3. Run ONE retort bone job, let it finish
--   4. The CHANGED block names exactly which field moved and by how
--      much. That is the whole answer.
--   5. probe-bone-item stop, then upload the log.
-- ==========================================

local repeatUtil = require('repeat-util')

local REPEAT_KEY = 'probe_bone_item'
local TAG        = 'BONE PROBE: '
local POLL       = 10  -- frames, same cadence as the ghost watcher

local function log(msg)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. msg)
    else print(TAG .. msg) end
end

-- ==========================================
-- READING ONE BONE ITEM
-- ==========================================
-- Every field that could plausibly hold "how many bones is this",
-- read defensively. A field that does not exist on this DF build is
-- reported as absent rather than skipped, because "the field is not
-- there" is itself an answer.
-- ==========================================
local function read_bone(it)
    local b = { id = it.id }

    pcall(function() b.desc = dfhack.items.getDescription(it, 0) end)
    pcall(function() b.itype = tostring(df.item_type[it:getType()]) end)

    -- Candidate 1: the ordinary stack count. The ghost reads this
    -- today, for both the value fraction and the consumed test.
    b.stack = '(absent)'
    pcall(function() b.stack = it.stack_size end)

    -- Candidate 2: corpsepieces carry material_amount, an array
    -- indexed by material kind (bone, skin, and so on). If the
    -- bracket is a bone COUNT rather than a stack, it most likely
    -- lives here.
    b.mat_amount = '(absent)'
    pcall(function()
        local parts = {}
        local ma = it.material_amount
        for i = 0, #ma - 1 do
            if ma[i] ~= 0 then
                table.insert(parts, string.format('[%d]=%d', i, ma[i]))
            end
        end
        b.mat_amount = #parts > 0 and table.concat(parts, ' ')
                       or '(all zero)'
    end)

    -- Candidate 3: body part bookkeeping. The ghost's piece fraction
    -- is present/total over these, and the session log shows the
    -- reported size dropping as the bracket drops, so something here
    -- is definitely moving.
    b.parts_total, b.parts_present, b.relsize_present, b.relsize_total =
        '(absent)', '(absent)', '(absent)', '(absent)'
    pcall(function()
        local rs     = it.body.body_part_relsize
        local status = it.body.components.body_part_status
        local n, present, rp, rt = 0, 0, 0, 0
        for k = 0, #rs - 1 do
            n  = n + 1
            rt = rt + rs[k]
            local gone = true
            pcall(function() gone = status[k].missing end)
            if not gone then
                present = present + 1
                rp = rp + rs[k]
            end
        end
        b.parts_total, b.parts_present = n, present
        b.relsize_total, b.relsize_present = rt, rp
    end)

    -- Identity, so the creature size the ghost prices against is
    -- visible next to everything else.
    pcall(function()
        b.race, b.caste = it.race, it.caste
        b.adult_size = df.global.world.raws.creatures.all[it.race]
                         .caste[it.caste].misc.adult_size
    end)

    return b
end

local function dump(b, indent)
    local p = indent or '  '
    log(string.format('%s#%d  %s   (%s)', p, b.id,
        tostring(b.desc), tostring(b.itype)))
    log(string.format('%s   stack_size      = %s', p, tostring(b.stack)))
    log(string.format('%s   material_amount = %s', p, tostring(b.mat_amount)))
    log(string.format('%s   body parts      = %s present of %s',
        p, tostring(b.parts_present), tostring(b.parts_total)))
    log(string.format('%s   relsize         = %s present of %s',
        p, tostring(b.relsize_present), tostring(b.relsize_total)))
    log(string.format('%s   race/caste      = %s/%s   adult_size = %s',
        p, tostring(b.race), tostring(b.caste), tostring(b.adult_size)))
end

-- ==========================================
-- FINDING BONE ITEMS
-- ==========================================
-- Full item scan rather than a typed vector. Slower, and it cannot
-- be blind to an item sitting inside a workshop or a container,
-- which is exactly where a bone in a running job will be.
-- ==========================================
local function all_bones()
    local out = {}
    pcall(function()
        for _, it in ipairs(df.global.world.items.all) do
            local t = it:getType()
            if t == df.item_type.CORPSEPIECE then
                out[it.id] = it
            end
        end
    end)
    return out
end

-- ==========================================
-- CHANGE REPORTING
-- ==========================================
-- The answer to question 2 is whichever line appears in a CHANGED
-- block after a job completes. A field that never appears is a
-- field the ghost must not rely on.
-- ==========================================
local FIELDS = { 'stack', 'mat_amount', 'parts_present', 'parts_total',
                 'relsize_present', 'relsize_total', 'desc' }

local function diff(old, new)
    local hits = {}
    for _, f in ipairs(FIELDS) do
        if tostring(old[f]) ~= tostring(new[f]) then
            table.insert(hits, string.format('%s: %s -> %s',
                f, tostring(old[f]), tostring(new[f])))
        end
    end
    return hits
end

local snap = {}

local function poll()
    if not dfhack.isMapLoaded() then return end
    local now = all_bones()

    for id, it in pairs(now) do
        local fresh = read_bone(it)
        local old   = snap[id]
        if not old then
            log('NEW bone item:')
            dump(fresh, '  ')
        else
            local hits = diff(old, fresh)
            if #hits > 0 then
                log(string.format('CHANGED #%d  %s', id,
                    tostring(fresh.desc)))
                for _, h in ipairs(hits) do
                    log('   ' .. h)
                end
            end
        end
        snap[id] = fresh
    end

    -- An item that vanished entirely was fully consumed, which is
    -- its own answer and must not be silent.
    for id, old in pairs(snap) do
        if not now[id] then
            log(string.format('GONE #%d  %s  (was stack=%s parts=%s)',
                id, tostring(old.desc), tostring(old.stack),
                tostring(old.parts_present)))
            snap[id] = nil
        end
    end
end

-- ==========================================
-- LIFECYCLE
-- ==========================================
local function inventory()
    log('==== BONE ITEM DUMP ====')
    local n = 0
    for _, it in pairs(all_bones()) do
        dump(read_bone(it), '  ')
        n = n + 1
    end
    if n == 0 then
        log('  no corpsepiece items in the fort.')
    else
        log(string.format('  ---- %d corpsepiece item(s) ----', n))
    end
    log('READ THIS FIRST: if one line shows stack_size 11, the item is'
        .. ' eleven bones and DF taking one per job is correct.')
    log('If stack_size is 1 and the 11 shows up in material_amount or'
        .. ' the part counts, it is ONE bone being consumed in'
        .. ' elevenths, and the reagent side is the fault.')
    log('==== END ====')
end

function start()
    snap = {}
    for id, it in pairs(all_bones()) do snap[id] = read_bone(it) end
    repeatUtil.scheduleEvery(REPEAT_KEY, POLL, 'frames', poll)
    log('Watching bone items. Run ONE retort job; the CHANGED block'
        .. ' names the field that actually moves.')
    log('Stop with:  probe-bone-item stop')
end

function stop()
    repeatUtil.cancel(REPEAT_KEY)
    log('Stopped watching.')
end

local cmd = ...
if cmd == 'watch' then
    inventory()
    start()
elseif cmd == 'stop' then
    stop()
else
    inventory()
end
