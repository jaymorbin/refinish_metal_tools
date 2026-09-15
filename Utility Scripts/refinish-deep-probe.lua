local file = io.open("refinish_deep_probe.txt", "w")
if not file then return end

file:write("=== DEEP PROBE: REFINISH STEEL ITEMS ===\n\n")

local inorganics = df.global.world.raws.inorganics.all
local count = 0

-- Helper to safely translate names
local function safe_name(name_obj)
    if not name_obj then return "Unknown" end
    if dfhack.translation and dfhack.translation.translateName then
        return dfhack.translation.translateName(name_obj)
    elseif dfhack.TranslateName then
        return dfhack.TranslateName(name_obj)
    end
    return "Unknown"
end

for _, item in ipairs(df.global.world.items.all) do
    local ok, m_idx = pcall(function() return item.mat_index end)
    if ok and type(m_idx) == 'number' and m_idx >= 0 and m_idx < #inorganics then
        local mat_id = inorganics[m_idx].id
        if string.find(mat_id, "REFINISH_STEEL_") then
            count = count + 1
            file:write(string.format("--- ITEM #%d (ID: %d) ---\n", count, item.id))
            file:write(string.format("Material: %s\n", mat_id))
            file:write(string.format("Type: %s\n", tostring(df.item_type[item:getType()])))
            file:write(string.format("Position: [%d, %d, %d]\n", item.pos.x, item.pos.y, item.pos.z))

            -- Dump True Flags
            local flags_on = {}
            for k, v in pairs(item.flags) do
                if v == true then table.insert(flags_on, k) end
            end
            file:write("Active Flags: " .. table.concat(flags_on, ", ") .. "\n")

            -- Dump General References (Unit ownership, artifacts, etc.)
            file:write("General References:\n")
            local has_g_ref = false
            for _, ref in ipairs(item.general_refs) do
                has_g_ref = true
                local ref_type = tostring(df.general_ref_type[ref:getType()])
                file:write(string.format("  - Ref Type: %s", ref_type))

                if ref:getType() == df.general_ref_type.UNIT_HOLDER then
                    file:write(string.format(" (Unit ID: %d)", ref.unit_id))
                    local u = df.unit.find(ref.unit_id)
                    if u and u.name then
                        file:write(string.format(" -> Name: %s", safe_name(u.name)))
                    end
                elseif ref:getType() == df.general_ref_type.ENTITY_ART_IMAGE then
                    file:write(" (Entity Art Image)")
                elseif ref:getType() == df.general_ref_type.ARTIFACT then
                    -- Get Artifact ID (some properties differ by DFHack version, using safe fallback)
                    local a_id = -1
                    pcall(function() a_id = ref.artifact_id end)
                    file:write(string.format(" (Artifact ID: %d)", a_id))
                end
                file:write("\n")
            end
            if not has_g_ref then file:write("  None\n") end

            -- Dump Specific References (Job links, building links, etc.)
            file:write("Specific References:\n")
            local s_refs = item.specific_refs
            if s_refs and #s_refs > 0 then
                for _, sref in ipairs(s_refs) do
                    file:write("  - Type: " .. tostring(df.specific_ref_type[sref.type]) .. "\n")
                end
            else
                file:write("  None\n")
            end

            file:write("\n")
        end
    end
end

file:write(string.format("Total items probed: %d\n", count))
file:close()
print("Refinish Steel: Probe complete. Check refinish_deep_probe.txt")