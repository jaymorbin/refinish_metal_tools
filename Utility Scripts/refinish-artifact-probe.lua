local file = io.open("refinish_artifact_probe.txt", "w")
if not file then return end

file:write("=== ARTIFACT & MEMORY VECTOR PROBE ===\n\n")

local inorganics = df.global.world.raws.inorganics.all
local count = 0

for _, item in ipairs(df.global.world.items.all) do
    local ok, m_idx = pcall(function() return item.mat_index end)
    if ok and type(m_idx) == 'number' and m_idx >= 0 and m_idx < #inorganics then
        local mat_id = inorganics[m_idx].id
        
        if string.find(mat_id, "REFINISH_STEEL_") then
            count = count + 1
            file:write(string.format("--- ITEM ID: %d ---\n", item.id))
            file:write(string.format("Current RAM State -> Mat Type: %d | Mat Index: %d | Mat String: %s\n", item:getActualMaterial(), m_idx, mat_id))
            
            -- Check for Immutable Artifact Record
            local is_artifact = false
            for _, ref in ipairs(item.general_refs) do
                if ref:getType() == df.general_ref_type.ARTIFACT then
                    is_artifact = true
                    local a_id = -1
                    pcall(function() a_id = ref.artifact_id end)
                    
                    if a_id ~= -1 then
                        local record = df.artifact_record.find(a_id)
                        if record then
                            local orig_mat_str = "UNKNOWN"
                            if record.item.mat_type == 0 and record.item.mat_index >= 0 and record.item.mat_index < #inorganics then
                                orig_mat_str = inorganics[record.item.mat_index].id
                            end
                            file:write(string.format("Secure Artifact Record -> Created: Year %d\n", record.item.year))
                            file:write(string.format("Original Forged State  -> Mat Type: %d | Mat Index: %d | Mat String: %s\n", record.item.mat_type, record.item.mat_index, orig_mat_str))
                            
                            if m_idx ~= record.item.mat_index then
                                file:write(">>> ANOMALY DETECTED: Item's material index was altered after creation! <<<\n")
                            else
                                file:write(">>> VECTOR OVERWRITE DETECTED: Item index matches, but the raw material at that index was overwritten! <<<\n")
                            end
                        end
                    end
                end
            end
            
            if not is_artifact then
                file:write("Not an artifact. Standard item.\n")
            end
            file:write("\n")
        end
    end
end

file:write(string.format("Total anomalies probed: %d\n", count))
file:write(string.format("Current total size of inorganics array: %d\n", #inorganics))
file:close()
print("Refinish Steel: Artifact probe complete. Check refinish_artifact_probe.txt")