-- refinish-probe.lua
local target_code = "PIG_IRON_MAKING"
local rxn = nil

for _, r in ipairs(df.global.world.raws.reactions.reactions) do
    if r.code == target_code then
        rxn = r
        break
    end
end

if not rxn then
    print("Probe failed: Could not find " .. target_code)
    return
end

print("=== PROBING: " .. target_code .. " ===")
print("FLAGS:")
printall(rxn.flags)
print("---")
print("REAGENTS (" .. #rxn.reagents .. "):")
for i, rgt in ipairs(rxn.reagents) do
    print(string.format("[%d] Type: %s | Code: %s", i, df.class_name(rgt), tostring(rgt.code)))
end
print("====================================")