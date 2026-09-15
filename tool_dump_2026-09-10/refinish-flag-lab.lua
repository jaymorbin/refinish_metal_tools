-- refinish-flag-lab.lua
-- ==========================================
-- THE GATE LAB: TEST A JOB-ITEM FLAG BEFORE SHIPPING IT
-- ==========================================
-- Every reagent gate is a bit on the reaction that DF tests against
-- state on the item. This lab shows both sides live, so a flag's real
-- behaviour is measured in the menu before it goes anywhere near the
-- JSON. RAM only; a recycle clears everything it does.
--
-- COMMANDS (launcher, clear the input box first):
--   refinish-flag-lab inspect [item-id]
--       The selected item (or the given id): every item flag and
--       material family a gate can test, plus improvements, wear,
--       and contents. This is the "why did it match" command.
--   refinish-flag-lab set <flag> <reaction> [reagent-code]
--   refinish-flag-lab clear <flag> <reaction> [reagent-code]
--       Write one gate flag by NAME onto a reaction's reagents in
--       RAM. <reaction> is a code substring (ghost clones included
--       automatically). With no reagent-code, every reagent on the
--       reaction is touched. Prints each word before and after.
--   refinish-flag-lab undo
--       Restore every reagent this session touched.
--
-- TEST RECIPES for the open questions:
--   allow_buryable  inspect a create-item corpse, then a citizen's:
--                   the gate checks the item flag dead_dwarf, and a
--                   conjured corpse likely never carries it. The
--                   inspect line settles whose corpses the default
--                   protection actually covers.
--   unrotten        inspect old meat until rotten=true, then check
--                   the burn menu with and without the flag set.
--   allow_melt_dump designate junk for dumping, inspect (dump=true),
--                   set the flag on a burn, watch the menu.
--   solid           inspect a fat glob next to a pulp glob, then set
--                   solid on RETORT_GLOB and compare the menu.
--   empty_or_water  set on a bucket reagent; test an empty bucket, a
--                   water bucket, and a lye bucket.
-- ==========================================

local args = {...}
local cmd = args[1]

-- Undo state lives in _G so it survives across invocations of this
-- script within one session. Keyed reaction-code:reagent-index,
-- holding the three original flag words.
_G.refinish_flag_lab_undo = _G.refinish_flag_lab_undo or {}
local UNDO = _G.refinish_flag_lab_undo

local WORDS = { 'flags1', 'flags2', 'flags3' }

-- ==========================================
-- SHARED HELPERS
-- ==========================================
local function printf(fmt, ...) print(string.format(fmt, ...)) end

-- Which flag word carries this name? Bitfields error on unknown
-- keys, which is exactly the detection needed.
local function find_word(reagent, name)
    for _, w in ipairs(WORDS) do
        local ok = pcall(function() return reagent[w][name] end)
        if ok then return w end
    end
    return nil
end

-- ==========================================
-- INSPECT: THE ITEM SIDE OF EVERY GATE
-- ==========================================
-- One block per concern, each labelled with the gate that reads it.
local function inspect(item)
    printf('')
    printf('== %s (id %d) ==', dfhack.items.getDescription(item, 0), item.id)
    printf('type %s', df.item_type[item:getType()] or item:getType())

    -- Material: the family bits (plant, silk, bone, yarn...) test
    -- MATERIAL flags, not item flags, so the token and families are
    -- printed here rather than guessed at.
    local mi = dfhack.matinfo.decode(item)
    if mi then
        printf('material %s', mi:getToken())
        local fams = {}
        for _, f in ipairs({ 'SILK', 'LEATHER', 'BONE', 'SHELL', 'YARN',
                             'TOOTH', 'HORN', 'PEARL', 'SOAP',
                             'ITEMS_HARD', 'ITEMS_SOFT' }) do
            local ok, v = pcall(function() return mi.material.flags[f] end)
            if ok and v then table.insert(fams, f) end
        end
        printf('material families: %s',
            #fams > 0 and table.concat(fams, ', ') or '(none of the gated ones)')
        printf('plant-mode material: %s', tostring(mi.mode == 'plant'))
    else
        printf('material: (no matinfo)')
    end

    -- Item flags, each tagged with the gate that reads it.
    local checks = {
        { 'rotten',      'unrotten (refuses when true)' },
        { 'dead_dwarf',  'allow_buryable (refused unless the gate is on)' },
        { 'dump',        'allow_melt_dump (refused unless the gate is on)' },
        { 'melt',        'allow_melt_dump / melt_designated' },
        { 'forbid',      'no gate: forbidden is refused outright' },
        { 'spider_web',  'undisturbed / collected' },
        { 'on_ground',   'on_ground' },
        { 'in_inventory','carried right now' },
        { 'in_building', 'held by a building (unreachable, like a placed chest)' },
        { 'in_job',      'claimed by a job' },
        { 'container',   'empty (holding something when true)' },
        { 'artifact',    'non_artifact' },
    }
    printf('item flags:')
    for _, c in ipairs(checks) do
        local ok, v = pcall(function() return item.flags[c[1]] end)
        printf('   %-13s %-5s  %s', c[1], ok and tostring(v) or '??', c[2])
    end

    -- Contents: what empty actually counts.
    local kids = dfhack.items.getContainedItems(item)
    printf('contains %d item(s)', #kids)

    -- Improvements: what unimproved and written_on actually test.
    -- Glaze, decoration, sewn images and WRITING all live here.
    local n = 0
    pcall(function() n = #item.improvements end)
    printf('improvements: %d', n)
    for i = 0, n - 1 do
        pcall(function()
            local imp = item.improvements[i]
            printf('   [%d] %s', i,
                df.improvement_type[imp:getType()] or tostring(imp:getType()))
        end)
    end

    printf('wear level: %s', tostring(item.wear))
    printf('')
end

local function run_inspect()
    local item
    if args[2] then
        item = df.item.find(tonumber(args[2]) or -1)
        if not item then printf('no item with id %s', args[2]) return end
    else
        item = dfhack.gui.getSelectedItem(true)
        if not item then
            printf('select an item first, or pass an id:')
            printf('   refinish-flag-lab inspect 12345')
            return
        end
    end
    inspect(item)
end

-- ==========================================
-- SET / CLEAR: THE REACTION SIDE
-- ==========================================
local function run_patch(turn_on)
    local name, needle, code_filter = args[2], args[3], args[4]
    if not name or not needle then
        printf('usage: refinish-flag-lab %s <flag> <reaction> [reagent-code]',
            turn_on and 'set' or 'clear')
        return
    end
    local touched, matched = 0, 0
    for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
        local rcode = tostring(rxn.code)
        if rcode:find(needle, 1, true) then
            matched = matched + 1
            for i = 0, #rxn.reagents - 1 do
                local g = rxn.reagents[i]
                local gcode = tostring(g.code)
                if not code_filter or gcode == code_filter then
                    local w = find_word(g, name)
                    if not w then
                        -- Report once per reaction, on the first
                        -- reagent, rather than spamming.
                        if i == 0 then
                            printf('%s: no flag named %q in flags1/2/3',
                                rcode, name)
                        end
                    else
                        local key = rcode .. ':' .. i
                        if not UNDO[key] then
                            UNDO[key] = {
                                g.flags1.whole, g.flags2.whole, g.flags3.whole
                            }
                        end
                        local before = g[w].whole
                        g[w][name] = turn_on
                        touched = touched + 1
                        -- Ghost clones patch silently; bases print.
                        if not rcode:find('_GHOST_', 1, true) then
                            printf('%s[%d].%s  %s.%s  0x%08X -> 0x%08X',
                                rcode, i, gcode, w, name, before, g[w].whole)
                        end
                    end
                end
            end
        end
    end
    if matched == 0 then
        printf('no reaction code contains %q', needle)
    else
        printf('%d reagent(s) written. RAM only; recycle clears it,'
            .. ' or: refinish-flag-lab undo', touched)
    end
end

-- ==========================================
-- UNDO
-- ==========================================
local function run_undo()
    local n = 0
    for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
        local rcode = tostring(rxn.code)
        for i = 0, #rxn.reagents - 1 do
            local orig = UNDO[rcode .. ':' .. i]
            if orig then
                local g = rxn.reagents[i]
                g.flags1.whole, g.flags2.whole, g.flags3.whole =
                    orig[1], orig[2], orig[3]
                n = n + 1
                UNDO[rcode .. ':' .. i] = nil
            end
        end
    end
    printf('%d reagent(s) restored.', n)
end

-- ==========================================
-- DISPATCH
-- ==========================================
if cmd == 'inspect' then
    run_inspect()
elseif cmd == 'set' then
    run_patch(true)
elseif cmd == 'clear' then
    run_patch(false)
elseif cmd == 'undo' then
    run_undo()
else
    printf('refinish-flag-lab inspect [item-id]')
    printf('refinish-flag-lab set <flag> <reaction> [reagent-code]')
    printf('refinish-flag-lab clear <flag> <reaction> [reagent-code]')
    printf('refinish-flag-lab undo')
end
