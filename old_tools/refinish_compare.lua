local glove = _G.my_glove
local bar = _G.my_bar

if not glove or not bar then
    print("Error: Make sure both _G.my_glove and _G.my_bar are bound in the console.")
    return
end

print("=== CORE FIELD DIFFERENCES ===")
for k, v_glove in pairs(glove) do
    -- Safely attempt to read the corresponding field on the bar
    local ok, v_bar = pcall(function() return bar[k] end)
    
    -- If the field doesn't exist on the bar, pcall returns false. We treat the value as nil.
    if not ok then 
        v_bar = nil 
    end

    -- Only print if the field exists in both and they are different
    if v_bar ~= nil and (type(v_glove) == "boolean" or type(v_glove) == "number" or type(v_glove) == "string") then
        if v_glove ~= v_bar then
            print(string.format("%-22s | GLOVE: %-15s | BAR: %-15s", tostring(k), tostring(v_glove), tostring(v_bar)))
        end
    end
end

print("\n=== UNPACKING GENERAL REFS ===")
print("GLOVE Refs: " .. #glove.general_refs)
for i, ref in ipairs(glove.general_refs) do
    local ok, ref_id = pcall(function() return ref.id end)
    if not ok then ref_id = "N/A" end
    print(string.format(" [%d] Type: %s (ID: %s)", i, tostring(df.general_ref_type[ref:getType()]), tostring(ref_id)))
end

print("\nBAR Refs: " .. #bar.general_refs)
for i, ref in ipairs(bar.general_refs) do
    local ok, ref_id = pcall(function() return ref.id end)
    if not ok then ref_id = "N/A" end
    print(string.format(" [%d] Type: %s (ID: %s)", i, tostring(df.general_ref_type[ref:getType()]), tostring(ref_id)))
end

print("\n=== UNPACKING SPECIFIC REFS ===")
print("GLOVE Refs: " .. #glove.specific_refs)
for i, ref in ipairs(glove.specific_refs) do
    local ok, ref_type = pcall(function() return df.specific_ref_type[ref.type] end)
    print(string.format(" [%d] Type: %s", i, ok and tostring(ref_type) or "Unknown"))
end

print("\nBAR Refs: " .. #bar.specific_refs)
for i, ref in ipairs(bar.specific_refs) do
    local ok, ref_type = pcall(function() return df.specific_ref_type[ref.type] end)
    print(string.format(" [%d] Type: %s", i, ok and tostring(ref_type) or "Unknown"))
end