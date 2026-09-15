--@ module = true
-- refinish-desc-probe.lua
--
-- ==========================================
-- SELECTION PROBE FOR THE DESCRIPTION PANEL
-- ==========================================
-- One question: with a furnace's task-add or task list open, does
-- DF expose WHICH entry is highlighted, and as what? If yes, the
-- description overlay can follow the player's cursor and this file
-- retires. If no, the panel falls back to queued-job zero and we
-- say so honestly in its header.
--
-- READ ONLY. Walks main_interface, prints scalar fields and small
-- vectors, touches nothing. Run with the sheet open, move the
-- highlight, run again, diff the two dumps by eye: the field that
-- moved is the answer.
--
-- Console use is fine here; this is a dev probe, not a release
-- feature, and it deletes itself from the plan the day it answers.
-- ==========================================

local function say(s)
    if _G.refinish_log_event then _G.refinish_log_event('DESC PROBE: ' .. s) end
    print('DESC PROBE: ' .. s)
end

local function scalar(v)
    local t = type(v)
    return t == 'number' or t == 'boolean' or t == 'string'
end

-- Walks one struct level, printing scalars and naming the rest.
-- Depth capped hard: the point is a diffable page, not a dump.
local function walk(obj, label, depth)
    if depth <= 0 or obj == nil then return end
    local ok, err = pcall(function()
        for k, v in pairs(obj) do
            local key = tostring(k)
            if scalar(v) then
                say(('%s.%s = %s'):format(label, key, tostring(v)))
            elseif depth > 1 and (key:lower():find('sheet')
                    or key:lower():find('task')
                    or key:lower():find('build')
                    or key:lower():find('select')
                    or key:lower():find('scroll')
                    or key:lower():find('cursor')) then
                say(('%s.%s = <%s>  (descending)'):format(
                    label, key, tostring(v)))
                walk(v, label .. '.' .. key, depth - 1)
            end
        end
    end)
    if not ok then say(label .. '  walk stopped: ' .. tostring(err)) end
end

function scan()
    say('focus = ' .. tostring((dfhack.gui.getCurFocus() or {})[1]))
    walk(df.global.game.main_interface.view_sheets,
         'view_sheets', 3)
    say('--- scan complete. Move the highlight one row and run again. ---')
end

-- Direct invocation: typing the script name runs the scan.
if not dfhack_flags or not dfhack_flags.module then
    scan()
end