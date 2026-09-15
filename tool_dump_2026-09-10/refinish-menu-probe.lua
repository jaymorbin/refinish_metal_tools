-- refinish-menu-probe.lua
-- ==========================================
-- THE FURNACE TASK MENU, READ OFF THE LIVE STRUCT
-- ==========================================
-- Two questions, one struct. df.global.game.main_interface.building
-- is a building_interfacest: `button` holds every entry the menu
-- knows, `filtered_button` holds what the current view shows, and
-- `current_custom_category_token` names the RM category folder that
-- is open, if any.
--
--   THE NAME. Hardcoded jobs are interface_button_building_new_jobst
--   with a jobtype and three writable strings (mstring, info,
--   filter_str). The caption is drawn by a virtual text() method,
--   so it may ignore all three - but one write settles what three
--   theories cannot. rename mode does that write.
--
--   THE LEAK. If MakeCharcoal sits in filtered_button while a
--   category token is set, the engine's filter passes hardcoded
--   jobs into every folder, and the fix is a pruner keyed on the
--   token. The two dumps below, one at top level and one inside a
--   folder, are the measurement.
--
-- USAGE (wood furnace selected, Add new task menu OPEN):
--   refinish-menu-probe               dump the menu state
--   refinish-menu-probe rename <text> write <text> onto the
--                                     MakeCharcoal button's three
--                                     strings, then look at the row
-- RAM only. A recycle, and likely a menu close, clears everything.
-- ==========================================

local args = {...}

local function printf(fmt, ...) print(string.format(fmt, ...)) end

-- The struct behind the building sheet. One known path; if it moves
-- in a future build, say so plainly rather than guessing.
local ok, bi = pcall(function()
    return df.global.game.main_interface.building
end)
if not ok or not bi then
    print('game.main_interface.building not reachable; report this line.')
    return
end

-- Class name without the userdata address noise.
local function classname(btn)
    local s = tostring(btn)            -- "<interface_button_building_new_jobst: 0x...>"
    return s:match('<([%w_]+):') or s
end

-- Read a field that only some button classes carry.
local function get(btn, field)
    local ok2, v = pcall(function() return btn[field] end)
    if not ok2 then return nil end
    return v
end

local function jobname(btn)
    local jt = get(btn, 'jobtype')
    if jt == nil then return nil end
    return df.job_type[jt] or tostring(jt)
end

-- ==========================================
-- RENAME MODE
-- ==========================================
if args[1] == 'rename' then
    local text = table.concat(args, ' ', 2)
    if text == '' then
        print('usage: refinish-menu-probe rename <new name>')
        return
    end
    local hit = 0
    for i = 0, #bi.button - 1 do
        local btn = bi.button[i]
        if get(btn, 'jobtype') == df.job_type.MakeCharcoal then
            -- All three at once. Whichever the text() method reads,
            -- if any, is the one that changes on screen; the others
            -- are inert and harmless in a struct this transient.
            btn.mstring = text
            btn.info = text
            btn.filter_str = text
            hit = hit + 1
            printf('button[%d] (%s): mstring, info, filter_str -> %q',
                i, classname(btn), text)
        end
    end
    if hit == 0 then
        print('no MakeCharcoal button in the open menu. Is the Add'
            .. ' new task list open on a wood furnace?')
    else
        print('now look at the Make Charcoal row. Unchanged means the'
            .. ' caption is built in code and the lever is an overlay.')
    end
    return
end

-- ==========================================
-- DUMP MODE
-- ==========================================
printf('')
printf('category=%s   custom token=%q',
    tostring(df.interface_category_building[bi.category] or bi.category),
    tostring(bi.current_custom_category_token))
printf('button=%d   filtered_button=%d   press_button=%d',
    #bi.button, #bi.filtered_button, #bi.press_button)
if #bi.button > 0 then
    -- Pointer stamp: run the probe twice without touching the menu
    -- and compare. Same stamp means the vectors persist between
    -- frames and a pruner would stick; a new stamp means the menu
    -- rebuilds and a pruner must re-run per build.
    printf('rebuild stamp: %s', tostring(bi.button[0]))
end

-- Group counts keep 300 reactions readable; full rows only for the
-- entries these two questions are about.
for _, vec_name in ipairs({ 'button', 'filtered_button' }) do
    local vec = bi[vec_name]
    printf('')
    printf('== %s ==', vec_name)
    local groups, order = {}, {}
    for i = 0, #vec - 1 do
        local btn = vec[i]
        local cls = classname(btn)
        local jt = jobname(btn)
        local label = cls .. (jt and (' / ' .. jt) or '')
        if not groups[label] then
            groups[label] = 0
            table.insert(order, label)
        end
        groups[label] = groups[label] + 1
    end
    for _, label in ipairs(order) do
        printf('   %4d  %s', groups[label], label)
    end
    -- The rows that matter, verbatim.
    local samples = 0
    for i = 0, #vec - 1 do
        local btn = vec[i]
        local jt = jobname(btn)
        local cls = classname(btn)
        local interesting =
            jt == 'MakeCharcoal' or jt == 'MakeAsh'
            or cls == 'interface_button_building_custom_category_selectorst'
        local sample = jt == 'CustomReaction' and samples < 3
        if interesting or sample then
            if sample then samples = samples + 1 end
            printf('   [%d] %s job=%s mstring=%q info=%q filter=%q'
                .. ' prio=%s token=%q',
                i, cls, tostring(jt),
                tostring(get(btn, 'mstring')),
                tostring(get(btn, 'info')),
                tostring(get(btn, 'filter_str')),
                tostring(get(btn, 'list_priority')),
                tostring(get(btn, 'custom_category_token')))
        end
    end
end
printf('')
