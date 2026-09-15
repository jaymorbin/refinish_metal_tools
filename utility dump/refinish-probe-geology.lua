--@ module = true
-- refinish-probe-geology.lua

local inorganics = df.global.world.raws.inorganics.all

print("==================================================")
print("GEOLOGY PROBE: ALUMINUM ORE CORRELATION")
print("==================================================")

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        local code = civ.entity_raw.code
        if code == "MOUNTAIN" or code == "PLAINS" or code == "EVIL" then
            local has_alum_metal = false
            local has_alum_ore = false

            -- Check Processed Metals Array
            if civ.resources and civ.resources.metals then
                for _, mat_idx in ipairs(civ.resources.metals) do
                    if inorganics[mat_idx] and inorganics[mat_idx].id == "ALUMINUM" then 
                        has_alum_metal = true 
                    end
                end
            end

            -- THE FIX: Check Raw Stones Array for the actual ore
            if civ.resources and civ.resources.stones then
                for _, mat_idx in ipairs(civ.resources.stones) do
                    if inorganics[mat_idx] and inorganics[mat_idx].id == "NATIVE_ALUMINUM" then 
                        has_alum_ore = true 
                    end
                end
            end

            print(string.format("CIV %3d (%-8s) | Alum Metal: %-5s | Native Alum Ore: %-5s", 
                civ.id, code, tostring(has_alum_metal), tostring(has_alum_ore)))
        end
    end
end
print("==================================================")