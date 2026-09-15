if not df.global.pause_state then
    dfhack.run_command('pause')
end

print("==================================================")
print("REFINISH MOD: PREPARING FOR MANUAL NAMED SAVE")
print("==================================================")

-- 1. Secure the memory
dfhack.run_script('refinish-save')
dfhack.run_script('refinish-clear')

print("MEMORY SECURE. You may now use the Esc menu to save and name your game.")
print("(The mod will automatically restore your colors when you unpause.)")

-- 2. Wait for the player to finish saving and unpause
dfhack.timeout(1, 'ticks', function()
    print("Refinish Mod: Unpause detected. Rebuilding RAM...")
    dfhack.run_script('refinish_test')
    dfhack.run_script('refinish-load')
    print("Refinish Mod: Restoration Complete.")
end)