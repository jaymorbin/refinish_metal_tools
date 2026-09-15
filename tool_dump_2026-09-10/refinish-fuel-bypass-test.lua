-- refinish-fuel-bypass-test.lua
-- ==========================================
-- FUEL GATE BYPASS: MECHANISM TEST RIG
-- ==========================================
-- One script, several mechanisms, each independently switchable.
-- Point of the exercise: find one that makes a fuel using vanilla
-- job SELECTABLE and COMPLETABLE with zero coal in the fort.
--
-- ALREADY KILLED, do not retry:
--   objection = ""      clears the text, button stays orange.
--                       pressable() and set_button_color are
--                       VMETHODS, engine code, recomputed live.
--   building type flip  magma twin off magma has no menu at all.
--
-- MECHANISMS HERE:
--   inject   Clone the vanilla greyed button into a NEW button and
--            insert it into the live list. DF computes objection
--            and pressability when it BUILDS the list; ours is
--            inserted after, so it may never be evaluated. Uses
--            the exact idiom proven by making-concrete-sand-button.
--   widen    Standing poll: rewrite any posted coal fuel filter to
--            reaction_class FUEL_MINERAL over IN_PLAY. Proven to
--            make haulers fetch peat. Needed alongside inject so
--            the job the button posts can actually be filled.
--   tagcoal  Push FUEL_MINERAL onto builtin COAL so coal remains
--            valid fuel under a widened filter.
--
-- Usage:
--   refinish-fuel-bypass-test scan        what is in the live list
--   refinish-fuel-bypass-test inject      arm button injection
--   refinish-fuel-bypass-test widen       arm the filter poll
--   refinish-fuel-bypass-test all         inject + widen
--   refinish-fuel-bypass-test tagcoal / untagcoal
--   refinish-fuel-bypass-test stop
--
-- Nothing persists. Buttons live in vectors DF rebuilds on every
-- open; filters live on posted jobs; the coal tag is popped by
-- untagcoal or forgotten on recycle.
-- ==========================================

local repeatUtil = require('repeat-util')

local KEY_BTN   = 'refinish_fuel_bypass_button'
local KEY_WIDEN = 'refinish_fuel_bypass_widen'
local TAG       = 'FUEL BYPASS: '

local FUEL_CLASS = 'FUEL_MINERAL'

local last_bld   = -1
local n_injected = 0
local n_widened  = 0
local widened    = {}

local function log(m)
    if _G.refinish_log_event then _G.refinish_log_event(TAG .. m)
    else print(TAG .. m) end
end


-- ==========================================
-- BUTTON INJECTION
-- ==========================================
-- Clone every new_jobst button that currently carries a fuel
-- objection, with the objection blanked, and insert the clone
-- beside it. DF evaluates objection and pressability when it
-- builds the list. A button inserted afterwards was never
-- evaluated, so it may render clickable.
--
-- If the clone is ALSO orange, pressability is recomputed per
-- frame from the button's own fields and this whole approach is
-- dead. That is exactly what this measures.
-- ==========================================
local FUEL_WORDS = { 'fuel', 'coal', 'coke', 'charcoal' }

local function is_fuel_obj(s)
    local low = tostring(s):lower()
    for _, w in ipairs(FUEL_WORDS) do
        if low:find(w, 1, true) then return true end
    end
    return false
end

-- Copies every writable field from a vanilla button onto a fresh
-- one. Field list taken from df.d_interface.xml's
-- interface_button_building_new_jobst plus its bases.
local function clone_button(src, bld)
    local b = df.interface_button_building_new_jobst:new()
    local function cp(f)
        pcall(function() b[f] = src[f] end)
    end
    b.bd = bld
    for _, f in ipairs({
        'hotkey', 'leave_button', 'filter_str', 'alpha_order',
        'jobtype', 'mstring', 'itemtype', 'subtype', 'material',
        'matgloss', 'add_building_location', 'show_help_instead',
        'art_specifier', 'art_specifier_id1', 'art_specifier_id2',
        'list_priority',
    }) do cp(f) end
    -- Compounds copied field by field; assigning them wholesale
    -- copies a pointer, not a value.
    pcall(function() b.specflag.whole = src.specflag.whole end)
    pcall(function()
        b.specdata.hist_figure_id = src.specdata.hist_figure_id
        b.specdata.race           = src.specdata.race
        b.specdata.improvement    = src.specdata.improvement
    end)
    pcall(function() b.job_item_flag.whole = src.job_item_flag.whole end)
    b.objection = ''
    b.info      = ''
    return b
end

local function inject_tick()
    local ok, err = pcall(function()
        local mi = df.global.game.main_interface
        local mb, fb = mi.building.button, mi.building.filtered_button
        if #mb == 0 or #fb == 0 then last_bld = -1 return end

        local vs = mi.view_sheets
        if not vs.open then last_bld = -1 return end
        local bld = df.building.find(vs.viewing_bldid)
        if not bld then last_bld = -1 return end

        -- Buttons must already belong to THIS building, or the
        -- list has not been rebuilt yet for it.
        local okf, first_bd = pcall(function() return fb[0].bd end)
        if not okf or first_bd ~= bld then return end

        if bld.id == last_bld then return end

        -- Collect the fuel-objected buttons from the master list.
        local targets = {}
        for i = 0, #mb - 1 do
            local b = mb[i]
            if b._type == df.interface_button_building_new_jobst then
                local obj = ''
                pcall(function() obj = tostring(b.objection) end)
                if obj ~= '' and is_fuel_obj(obj) then
                    table.insert(targets, b)
                end
            end
        end

        if #targets == 0 then
            last_bld = bld.id
            return
        end

        for _, src in ipairs(targets) do
            local jt = '?'
            pcall(function() jt = tostring(df.job_type[src.jobtype]) end)
            mb:insert('#', clone_button(src, bld))
            fb:insert('#', clone_button(src, bld))
            n_injected = n_injected + 1
            log(string.format('injected clone of %s (was objected)', jt))
        end
        last_bld = bld.id
        log('LOOK AT THE MENU. Clones are appended at the BOTTOM.')
        log('White + clickable = bypass works. Orange = dead end.')
    end)
    if not ok then log('INJECT ERROR: ' .. tostring(err)) end
end


-- ==========================================
-- FILTER WIDENING
-- ==========================================
local function widen_tick()
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
                            local fuel = false
                            pcall(function()
                                if e.item_type == df.item_type.BAR
                                   and e.mat_type == df.builtin_mats.COAL
                                then fuel = true end
                            end)
                            if fuel then
                                e.item_type      = -1
                                e.item_subtype   = -1
                                e.mat_type       = -1
                                e.mat_index      = -1
                                e.reaction_class = FUEL_CLASS
                                e.vector_id      =
                                    df.job_item_vector_id.IN_PLAY
                                hits = hits + 1
                            end
                        end
                    end)
                    if hits > 0 then
                        widened[j.id] = true
                        n_widened = n_widened + 1
                        pcall(function() j.recheck_cntdn = 0 end)
                        local att = 0
                        pcall(function() att = #j.items end)
                        log(string.format(
                            'job %d %s: %d filter(s) widened%s',
                            j.id, tostring(df.job_type[j.job_type]),
                            hits, att > 0 and '  [ITEMS ALREADY'
                            .. ' ATTACHED, too late]' or ''))
                    end
                end
            end
            l = l.next
        end
        for id in pairs(widened) do
            if not live[id] then widened[id] = nil end
        end
    end)
    if not ok then log('WIDEN ERROR: ' .. tostring(err)) end
end


-- ==========================================
-- COAL TAGGING
-- ==========================================
local function coal_rc()
    local rc = nil
    pcall(function()
        rc = df.global.world.raws.mat_table
             .builtin[df.builtin_mats.COAL].reaction_class
    end)
    return rc
end


-- ==========================================
-- SCAN
-- ==========================================
-- Read the live list. Run with the workshop panel OPEN.
-- ==========================================
local function scan()
    local mi = df.global.game.main_interface
    local mb = mi.building.button
    local n = 0
    pcall(function() n = #mb end)
    if n == 0 then
        print(TAG .. 'button list empty. Open a workshop panel first.')
        return
    end
    print(TAG .. n .. ' button(s):')
    for i = 0, n - 1 do
        local b = mb[i]
        local ty, jt, obj, fs = '?', '', '', ''
        pcall(function() ty = tostring(b._type) end)
        pcall(function() jt = tostring(df.job_type[b.jobtype]) end)
        pcall(function() obj = tostring(b.objection) end)
        pcall(function() fs = tostring(b.filter_str) end)
        print(string.format('  [%2d] %-22s %-24s obj="%s"',
            i, fs ~= '' and fs or ty, jt, obj))
    end
end


-- ==========================================
-- COMMANDS
-- ==========================================
local args = {...}
local cmd = args[1]

if cmd == 'scan' then
    scan()

elseif cmd == 'inject' or cmd == 'all' then
    last_bld, n_injected = -1, 0
    repeatUtil.scheduleEvery(KEY_BTN, 1, 'frames', inject_tick)
    log('button injection armed. Open a fuel using workshop.')
    if cmd == 'all' then
        widened, n_widened = {}, 0
        repeatUtil.scheduleEvery(KEY_WIDEN, 5, 'frames', widen_tick)
        log('filter widening armed too.')
    end

elseif cmd == 'widen' then
    widened, n_widened = {}, 0
    repeatUtil.scheduleEvery(KEY_WIDEN, 5, 'frames', widen_tick)
    log('filter widening armed.')

elseif cmd == 'tagcoal' then
    local rc = coal_rc()
    if not rc then log('cannot reach builtin COAL') return end
    local have = false
    for _, s in ipairs(rc) do
        if tostring(s) == FUEL_CLASS then have = true end
    end
    if have then log('already tagged') else
        local ok = pcall(function() rc:insert('#', FUEL_CLASS) end)
        log(ok and 'builtin COAL tagged' or 'tag failed')
    end

elseif cmd == 'untagcoal' then
    local rc = coal_rc()
    if not rc then log('cannot reach builtin COAL') return end
    for i = #rc - 1, 0, -1 do
        if tostring(rc[i]) == FUEL_CLASS then
            pcall(function() rc:erase(i) end)
            log('tag removed')
            return
        end
    end
    log('was not tagged')

elseif cmd == 'stop' then
    repeatUtil.cancel(KEY_BTN)
    repeatUtil.cancel(KEY_WIDEN)
    last_bld, widened = -1, {}
    log(string.format('stopped. injected %d, widened %d.',
        n_injected, n_widened))

else
    print('usage: refinish-fuel-bypass-test'
        .. ' scan | inject | widen | all | tagcoal | untagcoal | stop')
end
