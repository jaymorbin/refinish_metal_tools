--@ module = true
-- refinish-improvement-enum.lua
-- ==========================================
-- IMPROVEMENT ENUM AND PREFIX RESOLVER
-- ==========================================
-- Read only. Changes nothing.
--
-- Three questions, all of which have to be answered before the
-- improvement builder can be corrected:
--
--   1. What are the members of df.improvement_type, and is GLAZED one
--      of them? The working vanilla glazing product has
--      improvement_type = 1 and carries a GLAZED bit in its FLAGS, so
--      glaze looks like a flag on a type rather than a type of its
--      own. The module schema currently asks for improvement_type
--      "GLAZED". If that name does not resolve, build_improvement_product
--      returns nil and no product is inserted at all.
--
--   2. What bits exist on the improvement product's flag field? The
--      builder needs to set them explicitly instead of inheriting
--      whatever the donor happened to have, and that means knowing
--      the full set.
--
--   3. Which prefix is actually installed, ARGGC or ARGGGC? The
--      previous inspection searched for ARGGC and found nothing.
--      ARGGC is not a substring of ARGGGC, so a stale prefix would
--      produce the same empty result as a missing product. These are
--      different faults and this tells them apart.
--
-- Usage:
--   refinish-improvement-enum
-- ==========================================

print("")
print("IMPROVEMENT ENUM AND PREFIX RESOLVER")
print(string.rep("=", 74))

-- ---- 1. df.improvement_type ----
print("")
print("1. df.improvement_type MEMBERS")
print(string.rep("-", 74))
local n = 0
for i = 0, 60 do
    local ok, name = pcall(function() return df.improvement_type[i] end)
    if not ok or name == nil then break end
    print(string.format("    %-3d %s", i, tostring(name)))
    n = i + 1
end
print(string.format("    (%d members)", n))

print("")
for _, probe in ipairs({ "GLAZED", "COVERED", "ART_IMAGE", "ITEMSPECIFIC" }) do
    local ok, v = pcall(function() return df.improvement_type[probe] end)
    print(string.format("    df.improvement_type.%-14s = %s",
        probe, (ok and v ~= nil) and tostring(v) or "nil  (does not exist)"))
end

-- ---- 2. flag bits on the improvement product ----
-- Read the full bit set off a live vanilla glazing product, which is
-- the one known-good example in the raws.
print("")
print("2. FLAG BITS ON reaction_product_item_improvementst")
print(string.rep("-", 74))

local glaze_prod, glaze_owner
for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    for _, prod in ipairs(rxn.products) do
        if df.reaction_product_item_improvementst:is_instance(prod) then
            local code = tostring(rxn.code)
            if code:find("GLAZE", 1, true) and not code:find("ARG", 1, true) then
                glaze_prod, glaze_owner = prod, code
                break
            end
        end
    end
    if glaze_prod then break end
end

if not glaze_prod then
    print("    no vanilla glazing product found")
else
    print("    read from: " .. glaze_owner)
    local names = {}
    local ok = pcall(function()
        for bit, val in pairs(glaze_prod.flags) do
            table.insert(names, string.format("    %-34s %s", tostring(bit), tostring(val)))
        end
    end)
    if ok then
        table.sort(names)
        for _, line in ipairs(names) do print(line) end
    else
        print("    could not enumerate flags")
    end
end

-- ---- 3. installed prefix ----
print("")
print("3. INSTALLED MODULE PREFIX")
print(string.rep("-", 74))

local counts = { ARGGC = 0, ARGGGC = 0 }
local sample = {}
local glaze_rxn_arggc, glaze_rxn_argggc

for _, rxn in ipairs(df.global.world.raws.reactions.reactions) do
    local code = tostring(rxn.code)
    -- Check the longer one first: ARGGC is not a substring of ARGGGC,
    -- but testing in this order keeps the intent obvious.
    if code:find("ARGGGC", 1, true) then
        counts.ARGGGC = counts.ARGGGC + 1
        if not sample.ARGGGC then sample.ARGGGC = code end
        if not glaze_rxn_argggc and code:find("GLAZE", 1, true) then
            glaze_rxn_argggc = rxn
        end
    elseif code:find("ARGGC", 1, true) then
        counts.ARGGC = counts.ARGGC + 1
        if not sample.ARGGC then sample.ARGGC = code end
        if not glaze_rxn_arggc and code:find("GLAZE", 1, true) then
            glaze_rxn_arggc = rxn
        end
    end
end

print(string.format("    reactions with ARGGC_  : %d   %s",
    counts.ARGGC, sample.ARGGC or ""))
print(string.format("    reactions with ARGGGC_ : %d   %s",
    counts.ARGGGC, sample.ARGGGC or ""))

-- ---- 4. does the injected glazing reaction have ANY product? ----
print("")
print("4. PRODUCTS ON AN INJECTED GLAZING REACTION")
print(string.rep("-", 74))

local target = glaze_rxn_arggc or glaze_rxn_argggc
if not target then
    print("    no injected glazing reaction found under either prefix")
else
    print("    reaction: " .. tostring(target.code))
    print(string.format("    product count: %d", #target.products))
    if #target.products == 0 then
        print("")
        print("    ZERO PRODUCTS. The improvement product was not built, so")
        print("    the reaction injected with nothing to produce. That is")
        print("    consistent with improvement_type failing to resolve.")
    else
        for i, prod in ipairs(target.products) do
            local kind = "reaction_product_itemst"
            if df.reaction_product_item_improvementst:is_instance(prod) then
                kind = "reaction_product_item_improvementst"
            end
            print(string.format("    [%d] %s", i - 1, kind))
        end
    end
end

print("")
print("WHAT THIS DECIDES")
print(string.rep("=", 74))
print("  If GLAZED is not in df.improvement_type, the schema is asking")
print("  for a type that does not exist, the builder returns nil, and the")
print("  fix is to use the real type plus the GLAZED flag.")
print("")
print("  Section 4 confirms it directly: zero products means nothing was")
print("  built, rather than something built wrongly.")
print("")
print("  Section 3 rules out the alternative, that the earlier inspection")
print("  simply searched for a prefix that is not installed.")
print("")
