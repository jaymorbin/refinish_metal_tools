local g_red = _G.my_glove
local g_vanilla = _G.vanilla_glove

if not g_red or not g_vanilla then
    print("Error: Bind both _G.my_glove and _G.vanilla_glove first.")
    return
end

print("=== ITEM STRUCT DIFFERENCES ===")
for k, v in pairs(g_vanilla) do
    if type(v) ~= "table" and type(v) ~= "userdata" and type(v) ~= "function" then
        local ok, v_red = pcall(function() return g_red[k] end)
        if ok and v ~= v_red then
            -- Ignore basic unique identifiers and coordinates
            if k ~= "id" and k ~= "x" and k ~= "y" and k ~= "z" and k ~= "mat_index" and k ~= "age" and k ~= "stockpile_countdown" and k ~= "stockpile_delay" and k ~= "wear_timer" then
                print(string.format("%-25s | VANILLA: %-15s | RED: %-15s", tostring(k), tostring(v), tostring(v_red)))
            end
        end
    end
end