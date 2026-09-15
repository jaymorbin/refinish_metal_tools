-- refinish-probe-fuel.lua
local target = nil
for _, r in ipairs(df.global.world.raws.reactions.reactions) do
    if string.find(r.code, "BRONZE_MAKING") then
        target = r
        break
    end
end

if not target then
    print("Probe failed: Could not find any bronze making reaction.")
    return
end

print("=== DIAGNOSTIC: " .. target.code .. " ===")
print("ACTIVE FLAGS:")
for k,v in pairs(target.flags) do
    if v then print(" - " .. k) end
end
print("---")
print("REAGENTS (" .. #target.reagents .. "):")
for i, rgt in ipairs(target.reagents) do
    local type_name = tostring(rgt.item_type) or "UNKNOWN"
    local code_name = rgt.code or "none"
    print(string.format("[%d] Class: %s | Code: %s | ItemType: %s", i, df.class_name(rgt), code_name, type_name))
end
print("====================================")