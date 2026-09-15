local mat = nil
for _, m in ipairs(df.global.world.raws.inorganics.all) do
    if m.id == "REFINISHED_STEEL_RED" then 
        mat = m.material
        break 
    end
end

if mat then
    print("=== RED STEEL COLOR ARRAYS ===")
    print("Solid State Color: " .. tostring(mat.state_color[0])) -- 0 is Solid state
    print("Basic Color [0]:   " .. tostring(mat.basic_color[0]))
    print("Basic Color [1]:   " .. tostring(mat.basic_color[1]))
    print("Build Color [0]:   " .. tostring(mat.build_color[0]))
    print("Tile Color [0]:    " .. tostring(mat.tile_color[0]))
else
    print("Could not find REFINISHED_STEEL_RED in memory.")
end