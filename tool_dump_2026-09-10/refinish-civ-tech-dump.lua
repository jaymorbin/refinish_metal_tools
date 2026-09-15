--@ module = true
-- refinish-civ-tech-dump.lua
-- ==========================================
-- CIV_TECH VS PANEL DUMP
-- ==========================================
-- Read only. Changes nothing.
--
-- Prints, per civilization raw, exactly what boot Pass 3 stored in
-- civ_tech, and then recomputes what refinish-panel-civs derives from
-- it, using the same expressions the panel uses.
--
-- The point is to locate a divergence rather than argue about one.
-- Kobolds show smelted metals but no finish count, which is only
-- consistent if metal_tech is true and no ACTIVE BASE metal is in
-- their known set, or if metal_tech is false despite known_metals
-- being populated. Those are different bugs and this tells them
-- apart.
--
-- Panel expressions mirrored here:
--   data.rs_metal      = civ_cache.metal_tech        (panel line 84)
--   finish gate        = if data.rs_metal then       (panel line 101)
--   finish accumulate  = known_metals[base_id]       (panel line 103)
--   is_unskilled       = not (has_forge or has_mason or has_gem)
--
-- Usage:
--   refinish-civ-tech-dump
-- ==========================================

local bp = _G.refinish_blueprint

print("")
print("CIV_TECH VS PANEL")
print(string.rep("=", 78))

if not bp or not bp.civ_tech then
    print("  _G.refinish_blueprint.civ_tech is not populated.")
    print("  Boot Pass 3 has not run, or RM is not online yet.")
    return
end

local ui_dict = bp.ui_dict or {}
local finish_counts = ui_dict.finish_counts or {}
local metal_names   = ui_dict.metal_names or {}
local ore_map       = ui_dict.ore_map or {}

-- ---- THE ACTIVE BASE SET ----
-- finish_counts is keyed by base metal. If a civ knows none of these,
-- it gets zero finishes no matter how many metals it can smelt, and
-- that may well be correct rather than a fault.
print("")
print("ACTIVE BASE METALS (keys of ui_dict.finish_counts)")
print(string.rep("-", 78))
local n_bases = 0
for base_id, total in pairs(finish_counts) do
    n_bases = n_bases + 1
    print(string.format("  %-28s %d finishes   %s",
        base_id, total,
        ore_map[base_id] and "(smeltable from ore)" or "(ALLOY: needs a permitted reaction)"))
end
if n_bases == 0 then
    print("  none. No civ can show a finish count.")
end

-- ---- PER CIV ----
print("")
print("PER CIV")
print(string.rep("-", 78))

local function yn(v) return v and "yes" or "no" end

-- Stable output order so runs are comparable.
local codes = {}
for code, _ in pairs(bp.civ_tech) do table.insert(codes, code) end
table.sort(codes)

for _, code in ipairs(codes) do
    local t = bp.civ_tech[code]
    local known = t.known_metals or {}

    local n_known, n_ore, n_alloy = 0, 0, 0
    for id, _ in pairs(known) do
        n_known = n_known + 1
        if ore_map[id] then n_ore = n_ore + 1 else n_alloy = n_alloy + 1 end
    end

    -- Recompute the panel's finish total exactly as the panel does.
    local panel_finishes = 0
    local matched_bases  = {}
    if t.metal_tech then
        for base_id, total in pairs(finish_counts) do
            if known[base_id] then
                panel_finishes = panel_finishes + total
                table.insert(matched_bases, base_id)
            end
        end
    end

    print("")
    print("CIV [" .. code .. "]")
    print(string.format("  has_smelter %-4s  has_forge %-4s  has_mason %-4s  has_gem %-4s",
        yn(t.has_smelter), yn(t.has_forge), yn(t.has_mason), yn(t.has_gem)))
    print(string.format("  metal_tech  %-4s  stone_tech %-4s  gem_tech %-4s",
        yn(t.metal_tech), yn(t.stone_tech), yn(t.gem_tech)))
    print(string.format("  known_metals: %d total  (%d from ore, %d alloys)",
        n_known, n_ore, n_alloy))
    print(string.format("  panel token row would read: M=%s S=%s G=%s   unskilled=%s",
        t.has_forge and "M" or "-",
        t.has_mason and "S" or "-",
        t.has_gem   and "G" or "-",
        yn(not (t.has_forge or t.has_mason or t.has_gem))))

    if not t.metal_tech then
        print("  finishes: 0   REASON: metal_tech is false, so the panel skips the")
        print("                whole finish block regardless of known_metals.")
    elseif panel_finishes == 0 then
        print("  finishes: 0   REASON: metal_tech is true, but this civ knows none")
        print("                of the active base metals listed above.")
    else
        print(string.format("  finishes: %d   from base(s): %s",
            panel_finishes, table.concat(matched_bases, ", ")))
    end
end

print("")
print("HOW TO READ THIS")
print(string.rep("=", 78))
print("  If a civ shows metal_tech=no while known_metals is greater than zero,")
print("  boot is inconsistent and that is a real fault.")
print("")
print("  If metal_tech=yes and finishes are 0 because no active base is in its")
print("  known set, the panel is telling the truth: that civ cannot produce the")
print("  base metal RM refinishes, so it has nothing to refinish.")
print("")
print("  has_forge governs grinding metal only. A civ with has_forge=no should")
print("  not be showing any metal-grinding capability anywhere in the UI.")
print("")
