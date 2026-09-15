--@ module = true
-- refinish-improvement-inspect.lua
-- ==========================================
-- IMPROVEMENT PRODUCT INSPECTOR
-- ==========================================
-- Read only. Changes nothing.
--
-- Injected glazing reactions run but do not apply the improvement.
-- This dumps three things side by side so the difference is visible
-- rather than guessed at:
--
--   1. The donor RM picks. find_improvement_donor returns the FIRST
--      improvement product it finds scanning all reactions in raws
--      order. That is not necessarily a glaze. build_improvement_product
--      deliberately keeps the donor's flag bits, so if the donor
--      resolves its material a different way, our get_material fields
--      are set but never consulted.
--
--   2. A working vanilla glazing reaction, as the reference.
--
--   3. An injected ARGGC glazing reaction, as built.
--
-- Reagents are dumped too, because an improvement needs a target
-- reagent to attach to and the failure could be on that side.
--
-- Usage:
--   refinish-improvement-inspect
-- ==========================================

-- Enumerate the fields of a DFHack struct without hardcoding names.
-- Falls back to a probe list if introspection is unavailable; every
-- access is guarded so an absent field is skipped rather than thrown.
local PROBE = {
    "target_reagent", "product_token", "product_to_container",
    "part_token", "improvement_type", "improvement_specific_type",
    "probability", "mat_type", "mat_index", "product_dimension",
    "count", "flags", "get_material",
}

local function field_names(obj, typ)
    local names, seen = {}, {}
    local ok, flds = pcall(function() return typ._fields end)
    if ok and flds then
        for name, _ in pairs(flds) do
            if not seen[name] then seen[name] = true; table.insert(names, name) end
        end
    end
    if #names == 0 then
        for _, name in ipairs(PROBE) do
            local got = pcall(function() return obj[name] end)
            if got and not seen[name] then
                seen[name] = true; table.insert(names, name)
            end
        end
    end
    table.sort(names)
    return names
end

-- Render one field value as a single readable line.
local function render(obj, name)
    local ok, v = pcall(function() return obj[name] end)
    if not ok then return "<error>" end
    if v == nil then return "nil" end

    local tv = type(v)
    if tv == "number" or tv == "boolean" or tv == "string" then
        return tostring(v)
    end

    -- Bitfields: list only the bits that are set.
    local set = {}
    local okb = pcall(function()
        for bit, on in pairs(v) do
            if on == true then table.insert(set, tostring(bit)) end
        end
    end)
    if okb and #set > 0 then
        table.sort(set)
        return "{" .. table.concat(set, ", ") .. "}"
    end

    -- Sub-struct: try the two fields we care about on get_material.
    local parts = {}
    for _, sub in ipairs({ "reagent_code", "product_code", "mat_type", "mat_index" }) do
        local oks, sv = pcall(function() return v[sub] end)
        if oks and sv ~= nil then
            table.insert(parts, sub .. "=" .. tostring(sv))
        end
    end
    if #parts > 0 then return "{" .. table.concat(parts, ", ") .. "}" end

    if okb then return "{}" end
    return "<" .. tv .. ">"
end

local function dump_improvement(label, prod, owner)
    print("")
    print(label)
    print(string.rep("-", 74))
    if not prod then
        print("  not found")
        return
    end
    if owner then print("  from reaction: " .. owner) end
    for _, name in ipairs(field_names(prod, df.reaction_product_item_improvementst)) do
        print(string.format("    %-28s %s", name, render(prod, name)))
    end
end

local function dump_reagents(label, rxn)
    print("")
    print(label)
    print(string.rep("-", 74))
    if not rxn then print("  not found"); return end
    for i, rg in ipairs(rxn.reagents) do
        local bits = {}
        local ok = pcall(function()
            for bit, on in pairs(rg.flags) do
                if on == true then table.insert(bits, tostring(bit)) end
            end
        end)
        table.sort(bits)
        print(string.format("    [%d] code=%-14s type=%-6s subtype=%-4s mat=%s/%s",
            i - 1, tostring(rg.code), tostring(rg.item_type),
            tostring(rg.item_subtype), tostring(rg.mat_type), tostring(rg.mat_index)))
        print(string.format("        reaction_class=%-14s has_mat_product=%s",
            tostring(rg.reaction_class), tostring(rg.has_material_reaction_product)))
        print(string.format("        flags=%s", ok and ("{" .. table.concat(bits, ", ") .. "}") or "<error>"))
    end
end

-- ---- LOCATE THE THREE SUBJECTS ----
local donor, donor_owner
local vanilla, vanilla_rxn
local injected, injected_rxn

for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    for _, prod in ipairs(rxn.products) do
        if df.reaction_product_item_improvementst:is_instance(prod) then
            if not donor then
                donor = prod
                donor_owner = rxn.code
            end
            local code = tostring(rxn.code)
            if not vanilla and code:find("GLAZE", 1, true)
               and not code:find("ARGGC", 1, true)
               and not code:find("ARGMOD", 1, true) then
                vanilla, vanilla_rxn = prod, rxn
            end
            if not injected and code:find("ARGGC", 1, true) then
                injected, injected_rxn = prod, rxn
            end
        end
    end
end

print("")
print("IMPROVEMENT PRODUCT INSPECTOR")
print(string.rep("=", 74))

dump_improvement("1. DONOR RM CLONES FROM (first improvement in raws order)",
                 donor, donor_owner and tostring(donor_owner))
dump_improvement("2. VANILLA GLAZING PRODUCT (reference)",
                 vanilla, vanilla_rxn and tostring(vanilla_rxn.code))
dump_improvement("3. INJECTED ARGGC PRODUCT (as built)",
                 injected, injected_rxn and tostring(injected_rxn.code))

dump_reagents("VANILLA REAGENTS: " ..
    (vanilla_rxn and tostring(vanilla_rxn.code) or "not found"), vanilla_rxn)
dump_reagents("INJECTED REAGENTS: " ..
    (injected_rxn and tostring(injected_rxn.code) or "not found"), injected_rxn)

print("")
print("WHAT TO COMPARE")
print(string.rep("=", 74))
print("  Block 1 against block 2. If the donor is not itself a glazing")
print("  product, its flags are wrong for our purpose and every injected")
print("  improvement inherited them.")
print("")
print("  Block 3 against block 2, field by field. The vanilla one works.")
print("  Anything that differs is a candidate, and the flags and")
print("  get_material rows are the ones to read first.")
print("")
print("  In the reagent blocks, check that the injected target_reagent")
print("  names a reagent code that actually exists in that reaction, and")
print("  that the reagent carrying the glaze declares the same material")
print("  reaction product the improvement asks for.")
print("")
