-- refinish-probe.lua
-- Diagnostic tool to map vanilla reaction reagent arrays.

local steel_rxn, plaster_rxn
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    if rxn.code == "STEEL_MAKING" then steel_rxn = rxn end
    if rxn.code == "MAKE_PLASTER_POWDER" then plaster_rxn = rxn end
    if steel_rxn and plaster_rxn then break end
end

if not steel_rxn or not plaster_rxn then
    print("PROBE ERROR: Could not find base templates.")
    return
end

print("==================================================")
print("PROBE: STEEL_MAKING REAGENTS (" .. #steel_rxn.reagents .. " total)")
for i, r in ipairs(steel_rxn.reagents) do
    print(string.format("  [%d] code: %-15s item_type: %d", i - 1, tostring(r.code), r.item_type))
end

print("--------------------------------------------------")
print("PROBE: MAKE_PLASTER_POWDER REAGENTS (" .. #plaster_rxn.reagents .. " total)")
for i, r in ipairs(plaster_rxn.reagents) do
    print(string.format("  [%d] code: %-15s item_type: %d", i - 1, tostring(r.code), r.item_type))
end
print("==================================================")