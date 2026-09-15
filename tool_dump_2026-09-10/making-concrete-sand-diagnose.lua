-- making-concrete-sand-diagnose.lua
-- ==========================================
-- SAND BAG DIAGNOSTIC DUMP
-- ==========================================
-- Dumps every field on:
--   1. Every bag containing sand powder
--   2. Every sand powder item in those bags
--   3. A vanilla plaster powder for comparison (known working)
--   4. The plaster's bag for comparison
--
-- Output goes to Dwarf Fortress/sand_diagnose.txt
-- Run once, check the file, compare fields.
-- ==========================================

local OUTPUT_PATH = 'sand_diagnose.txt'
local file = io.open(OUTPUT_PATH, 'w')

if not file then
    print("ERROR: Cannot open " .. OUTPUT_PATH)
    return
end

local function w(msg)
    file:write(msg .. "\n")
end

-- ==========================================
-- DUMP ALL FIELDS ON AN ITEM
-- ==========================================
local function dump_item(item, label)
    w("")
    w("========== " .. label .. " ==========")
    w("_type: " .. tostring(item._type))
    w("id: " .. item.id)

    -- Walk every field via pairs
    for k, v in pairs(item) do
        local val = tostring(v)

        -- For flags, expand the bits
        if k == "flags" then
            w(k .. ": " .. val)
            for i = 0, 31 do
                local ok, name = pcall(function() return df.item_flags[i] end)
                local fname = (ok and name) or tostring(i)
                w("  flags." .. fname .. " = " .. tostring(item.flags[i]))
            end
        elseif k == "flags2" then
            w(k .. ": " .. val)
            for i = 0, 31 do
                local ok, name = pcall(function() return df.item_flags2[i] end)
                local fname = (ok and name) or tostring(i)
                w("  flags2." .. fname .. " = " .. tostring(item.flags2[i]))
            end
        elseif k == "pos" then
            w(k .. ": x=" .. item.pos.x .. " y=" .. item.pos.y .. " z=" .. item.pos.z)
        elseif k == "temperature" then
            w(k .. ": whole=" .. item.temperature.whole .. " fraction=" .. item.temperature.fraction)
        elseif k == "weight" then
            w(k .. ": whole=" .. item.weight.whole .. " fraction=" .. item.weight.fraction)
        elseif k == "general_refs" then
            w(k .. ": [" .. #item.general_refs .. " refs]")
            for i = 0, #item.general_refs - 1 do
                local ref = item.general_refs[i]
                local ref_id = -1
                pcall(function() ref_id = ref.item_id end)
                w("  [" .. i .. "] " .. tostring(ref._type) .. " item_id=" .. ref_id)
            end
        elseif k == "specific_refs" then
            w(k .. ": [" .. #item.specific_refs .. " refs]")
        elseif k == "improvements" then
            w(k .. ": [" .. #item.improvements .. " improvements]")
            for i = 0, #item.improvements - 1 do
                local imp = item.improvements[i]
                w("  [" .. i .. "] " .. tostring(imp._type) .. " mat_type=" .. imp.mat_type .. " mat_index=" .. imp.mat_index)
            end
        elseif k == "contaminants" then
            if item.contaminants then
                w(k .. ": [" .. #item.contaminants .. " contaminants]")
            else
                w(k .. ": nil")
            end
        elseif k == "dye_profile" then
            local ok, ci = pcall(function() return item.dye_profile.color_index end)
            w(k .. ": color_index=" .. (ok and tostring(ci) or "?"))
        elseif k == "lp_flags" then
            w(k .. ": " .. val)
            for i = 0, 31 do
                local bit = false
                pcall(function() bit = item.lp_flags[i] end)
                if bit then
                    w("  lp_flags[" .. i .. "] = true")
                end
            end
        elseif k == "history_info" or k == "magic" then
            w(k .. ": " .. (v and tostring(v) or "nil"))
        else
            w(k .. ": " .. val)
        end
    end
end

-- ==========================================
-- FIND AND DUMP SAND BAGS
-- ==========================================
w("####################################")
w("# SAND BAG DIAGNOSTIC DUMP")
w("# Frame: " .. df.global.world.frame_counter)
w("####################################")

local sand_count = 0
for _, item in ipairs(df.global.world.items.all) do
    if item:getType() == df.item_type.BAG then
        local contents = dfhack.items.getContainedItems(item)
        local has_sand = false
        for _, c in ipairs(contents) do
            if c:getType() == df.item_type.POWDER_MISC and c.mat_type == 0 then
                local mat = df.global.world.raws.inorganics.all[c.mat_index]
                if mat and mat.flags.SOIL_SAND then
                    has_sand = true
                    break
                end
            end
        end
        if has_sand then
            dump_item(item, "SAND BAG id=" .. item.id .. " (" .. #contents .. " contents)")
            for _, c in ipairs(contents) do
                dump_item(c, "SAND POWDER id=" .. c.id .. " in bag " .. item.id)
            end
            sand_count = sand_count + #contents
        end
    end
end

-- ==========================================
-- FIND AND DUMP A PLASTER BAG FOR COMPARISON
-- ==========================================
-- Plaster is a vanilla powder that displays correctly in bags.
-- mat_id PLASTER, mat_type 0 (INORGANIC).
w("")
w("####################################")
w("# PLASTER COMPARISON (KNOWN GOOD)")
w("####################################")

local found_plaster = false
for _, item in ipairs(df.global.world.items.all) do
    if item:getType() == df.item_type.BAG and not found_plaster then
        local contents = dfhack.items.getContainedItems(item)
        for _, c in ipairs(contents) do
            if c:getType() == df.item_type.POWDER_MISC then
                -- Check if it's plaster by name
                local mat = df.global.world.raws.inorganics.all[c.mat_index]
                if mat and mat.id == "ITE_CALCIUM_OXIDE" then
                    -- Close enough — any non-sand powder in a bag
                    dump_item(item, "PLASTER BAG id=" .. item.id)
                    dump_item(c, "PLASTER POWDER id=" .. c.id)
                    found_plaster = true
                    break
                end
            end
        end
    end
end

-- If no plaster found, try any non-sand powder
if not found_plaster then
    for _, item in ipairs(df.global.world.items.all) do
        if item:getType() == df.item_type.BAG and not found_plaster then
            local contents = dfhack.items.getContainedItems(item)
            for _, c in ipairs(contents) do
                if c:getType() == df.item_type.POWDER_MISC and c.mat_type == 0 then
                    local mat = df.global.world.raws.inorganics.all[c.mat_index]
                    if mat and not mat.flags.SOIL_SAND then
                        dump_item(item, "NON-SAND POWDER BAG id=" .. item.id .. " material=" .. mat.id)
                        dump_item(c, "NON-SAND POWDER id=" .. c.id .. " material=" .. mat.id)
                        found_plaster = true
                        break
                    end
                end
            end
        end
    end
end

if not found_plaster then
    w("")
    w("NO PLASTER OR NON-SAND POWDER FOUND FOR COMPARISON")
    w("Make some plaster at the kiln for a known-good reference.")
end

file:close()
print("Dump written to " .. OUTPUT_PATH)
print("Sand items found: " .. sand_count)
