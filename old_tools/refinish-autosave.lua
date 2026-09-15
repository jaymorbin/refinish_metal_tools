local repeatUtil = require('repeat-util')
local GLOBAL_KEY = 'refinish_autosave'
local AUTOSAVE_MINUTES = 15 -- Change this to whatever interval you want

local function trigger_ghost_save()
    local mins_since_save = dfhack.persistent.getUnsavedSeconds() // 60
    if mins_since_save >= AUTOSAVE_MINUTES then
        print("[Refinish Autosave] " .. AUTOSAVE_MINUTES .. " minutes elapsed. Triggering Ghost Save...")
        dfhack.run_script('refinish-ghost-save')
    end
end

-- This checks the clock every 500 ticks
repeatUtil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY, 500, 'ticks', trigger_ghost_save)
print("Refinish Mod: Custom Ghost Autosave loop engaged (" .. AUTOSAVE_MINUTES .. " min).")