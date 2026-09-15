local was_open = false

local function menu_watcher()
    local is_open = df.global.game.main_interface.options.open
    
    if is_open and not was_open then
        print("ESC MENU OPENED - We can trigger the wash here!")
        was_open = true
    elseif not is_open and was_open then
        print("ESC MENU CLOSED - We can restore colors here!")
        was_open = false
    end
    
    dfhack.timeout(10, 'frames', menu_watcher)
end

menu_watcher()
print("Test watcher active. Press Esc in-game, then check this console.")