-- refinish-color-probe.lua
-- READ-ONLY DIAGNOSTIC SCRIPT (UNRESTRICTED)

local function run_probe()
    local out = io.open('refinish_color_debug.txt', 'w')
    if not out then 
        qerror("Could not open output file in DF directory.") 
        return 
    end

    out:write("=== REFINISH COLOR PROBE (FULL DUMP) ===\n\n")
    
    local colors = df.global.world.raws.descriptors.colors
    local color_len = #colors
    out:write("1. GLOBAL COLOR VECTOR\n")
    out:write(" -> Total length of df.global.world.raws.descriptors.colors: " .. tostring(color_len) .. "\n\n")

    local inorganics = df.global.world.raws.inorganics.all
    out:write("2. SCANNING MODDED METALS WITH OUT-OF-BOUNDS COLORS\n")
    
    local found = 0
    for i, mat in ipairs(inorganics) do
        local c_idx = mat.material.state_color[0]
        
        -- Check if the color index is pointing to something beyond the known array
        if c_idx and c_idx >= color_len then
            out:write(string.format(" -> Metal ID: %s\n", mat.id))
            out:write(string.format("    - state_color[0] index: %d\n", c_idx))
            
            if mat.material.build_color then
                out:write(string.format("    - build_color[0] index: %d\n", mat.material.build_color[0]))
            end
            out:write("\n")
            found = found + 1
        end
    end

    if found == 0 then
        out:write(" -> No out-of-bounds indices found. Something else is causing the Unknown string.\n")
    else
        out:write(string.format(" -> Scan complete. Found %d out-of-bounds items.\n", found))
    end

    out:close()
    print("Probe complete. Check 'refinish_color_debug.txt' in your main Dwarf Fortress folder.")
end

run_probe()