local raws = df.global.world.raws.inorganics.all
local steel, red

for _, mat in ipairs(raws) do
    if mat.id == "STEEL" then steel = mat.material end
    if mat.id == "REFINISHED_STEEL_RED" then red = mat.material end
end

if not steel or not red then
    print("Error: Could not find materials in memory.")
    return
end

print("=== MATERIAL STRUCT DIFFERENCES ===")
for k, v in pairs(steel) do
    if type(v) ~= "table" and type(v) ~= "userdata" then
        local ok, v_red = pcall(function() return red[k] end)
        if ok and v ~= v_red then
            print(string.format("%-25s | STEEL: %-15s | RED: %-15s", tostring(k), tostring(v), tostring(v_red)))
        end
    end
end