--@ module = false
-- refinish-flag-probe.lua
local utils = require('utils')

-- Grab the very first vanilla reaction to use as a structural dummy
local template = df.global.world.raws.reactions.reactions[0]
if not template or not template.reagents[0] then
    print("PROBE FAILED: Could not find a template reagent to inspect.")
    return
end

local reagent = template.reagents[0]

print("==================================================")
print("PROBING JOB_ITEM_FLAGS BITFIELDS")
print("==================================================")

print("\n--- FLAGS 1 ---")
local ok1, err1 = pcall(function() utils.printall(reagent.flags1) end)
if not ok1 then print("Could not read flags1: " .. tostring(err1)) end

print("\n--- FLAGS 2 ---")
local ok2, err2 = pcall(function() utils.printall(reagent.flags2) end)
if not ok2 then print("Could not read flags2: " .. tostring(err2)) end

print("\n--- FLAGS 3 ---")
local ok3, err3 = pcall(function() utils.printall(reagent.flags3) end)
if not ok3 then print("Could not read flags3: " .. tostring(err3)) end

print("==================================================")