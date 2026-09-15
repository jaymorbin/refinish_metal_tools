--@ module = false
-- refinish-probe.lua

local utils = require('utils')

local function dump_reaction(rxn_code)
    local target = nil
    for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
        if string.find(rxn.code, rxn_code) then
            target = rxn
            break
        end
    end

    if not target then
        print("PROBE FAILED: Could not find reaction matching: " .. rxn_code)
        return
    end

    print("==================================================")
    print("PROBE RESULTS FOR: " .. target.code)
    print("==================================================")

    print("\n--- REAGENTS ---")
    for i, r in ipairs(target.reagents) do
        print(string.format("Reagent [%d]: Class %s", i, tostring(r._type)))
        utils.printall(r)
    end

    print("\n--- PRODUCTS ---")
    for i, p in ipairs(target.products) do
        print(string.format("Product [%d]: Class %s", i, tostring(p._type)))
        utils.printall(p)
    end
    print("==================================================")
end

print("Initiating Refinish Steel Deep Probe...")

-- 1. Probe the Vanilla Base
dump_reaction("MAKE_GLASS_CLEAR")

-- 2. Probe the Custom Blueprint
local found_custom = false
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    -- Target one of your generated colour finishes or the old template
    if string.find(rxn.code, "REFINISH_STEEL_RXN_") and not string.find(rxn.code, "GRIND") then
        dump_reaction(rxn.code)
        found_custom = true
        break
    end
end

-- Fallback to the old hardcoded raw if the dynamic ones aren't generated right now
if not found_custom then
    dump_reaction("MAKE_DYE")
end