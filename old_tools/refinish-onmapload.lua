print("Refinish Mod: Initializing session controls...")

-- 1. Hotkey Bindings
dfhack.run_command('keybinding', 'add', 'Ctrl-Shift-S@dwarfmode', 'refinish-ghost-save')
dfhack.run_command('keybinding', 'add', 'Ctrl-Alt-S@dwarfmode', 'refinish-prep')
dfhack.run_command('keybinding', 'add', 'Ctrl-Shift-X@dwarfmode', 'refinish-shutdown')
dfhack.run_command('keybinding', 'add', 'Ctrl-Alt-X@dwarfmode', 'refinish-startup')

-- 2. Vanilla Autosave Kill-Switch
df.global.d_init.feature.autosave = -1 
print("Refinish Mod: Vanilla autosave disabled to prevent corruption.")

-- 3. The Custom Calendar Loop (Triggers every season)
local last_season = -1

local function calendar_loop()
    if dfhack.isMapLoaded() and not df.global.pause_state then
        local cur_tick = df.global.cur_year_tick
        -- A season is exactly 100,800 ticks. This gives us 0, 1, 2, or 3.
        local current_season = math.floor(cur_tick / 100800)
        
        if last_season == -1 then
            last_season = current_season -- Initialize so it doesn't instantly save on load
        elseif current_season ~= last_season then
            print("Refinish Mod: Seasonal milestone reached. Pausing engine...")
            last_season = current_season
            
            -- Force the pause first
            dfhack.run_command('pause')
            
            -- Wait 1 frame for the pause to physically lock in, THEN run the save
            dfhack.timeout(1, 'frames', function()
                dfhack.run_script('refinish-ghost-save')
            end)
        end
    end
    -- Check again in roughly 12 seconds
    dfhack.timeout(600, 'frames', calendar_loop)
end

calendar_loop()
print("Refinish Mod: Seasonal autosave active.")