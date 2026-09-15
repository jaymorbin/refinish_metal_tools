--@ module = true
-- refinish-gate-delta.lua
-- ==========================================
-- CAPABILITY GATE: BEFORE AND AFTER
-- ==========================================
-- Read only. Changes nothing.
--
-- permitted_job is indexed by df.profession (135 entries, confirmed).
-- The mood gates index it with df.job_type values, so they read
-- unrelated professions:
--
--   StrangeMoodForge      = 55 -> LYE_MAKER
--   StrangeMoodMagmaForge = 56 -> WOOD_BURNER
--   StrangeMoodMason      = 60 -> BEEKEEPER
--   StrangeMoodJeweller   = 54 -> POTASH_MAKER
--
-- This prints, per civ, what each gate returns TODAY against what it
-- would return with the corrected profession, so the blast radius is
-- visible before anything is edited.
--
-- The SMELTER row matters most. boot Pass 3 uses the same two indices
-- for has_forge_mood, which gates the entire metal knowledge
-- evaluation for that civ. A change there reaches the base mod and
-- existing saves, not just the ArgMOD ports.
--
-- Usage:
--   refinish-gate-delta
-- ==========================================

-- Read a profession slot by name. Returns nil if the name is unknown,
-- which is itself worth seeing rather than silently treating as false.
local function prof(p, name)
    local idx = df.profession and df.profession[name]
    if type(idx) ~= "number" then return nil end
    local ok, v = pcall(function() return p[idx] end)
    if not ok then return nil end
    return v and true or false
end

-- Read a raw numeric slot, which is what the broken gates do.
local function raw(p, idx)
    local ok, v = pcall(function() return p[idx] end)
    if not ok then return nil end
    return v and true or false
end

-- true if any listed profession is set
local function any(p, names)
    for _, nm in ipairs(names) do
        if prof(p, nm) then return true end
    end
    return false
end

local function mark(now, proposed)
    if now == proposed then return "same" end
    return (proposed and "GAINS" or "LOSES")
end

print("")
print("CAPABILITY GATE DELTA")
print(string.rep("=", 78))
print("  'now' is what the gate returns today. 'proposed' is the corrected")
print("  profession read. Only rows marked GAINS or LOSES change behaviour.")

local seen = {}

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        local code = civ.entity_raw.code
        if not seen[code] then
            seen[code] = true
            local p = civ.entity_raw.jobs.permitted_job

            print("")
            print("CIV [" .. code .. "]")
            print(string.rep("-", 78))

            local function row(label, now, proposed, detail)
                print(string.format("  %-14s now=%-6s proposed=%-6s %-6s  %s",
                    label, tostring(now), tostring(proposed),
                    mark(now, proposed), detail or ""))
            end

            -- ---- SMELTER / FORGE ----
            -- Today: LYE_MAKER or WOOD_BURNER.
            -- Proposed: FURNACE_OPERATOR runs a smelter; METALSMITH and
            -- its specialisations run a forge. Both printed separately
            -- so the two buildings can be judged on their own.
            local smelt_now = (raw(p, 55) or raw(p, 56)) and true or false
            row("SMELTER", smelt_now, prof(p, "FURNACE_OPERATOR") or false,
                "LYE_MAKER/WOOD_BURNER -> FURNACE_OPERATOR")

            local forge_prof = any(p, { "METALSMITH", "WEAPONSMITH",
                                        "ARMORER", "BLACKSMITH", "METALCRAFTER" })
            row("FORGE", smelt_now, forge_prof,
                "LYE_MAKER/WOOD_BURNER -> METALSMITH family")

            -- ---- KILN (already changed in types.lua) ----
            row("KILN", raw(p, 60) or false,
                any(p, { "POTTER", "GLAZER" }),
                "BEEKEEPER -> POTTER/GLAZER")

            -- ---- GATES THAT WERE ALREADY CORRECT ----
            -- These use string access and are unaffected. Printed to
            -- confirm they read sensibly rather than assumed.
            print(string.format("  %-14s %s", "GLASS_FURNACE",
                "GLASSMAKER = " .. tostring(prof(p, "GLASSMAKER"))))
            print(string.format("  %-14s %s", "MASON",
                "MASON = " .. tostring(prof(p, "MASON"))))
            print(string.format("  %-14s %s", "CRAFTSMAN",
                "STONECRAFTER=" .. tostring(prof(p, "STONECRAFTER")) ..
                " WOODCRAFTER=" .. tostring(prof(p, "WOODCRAFTER")) ..
                " BONE_CARVER=" .. tostring(prof(p, "BONE_CARVER"))))
            print(string.format("  %-14s %s", "JEWELER",
                "JEWELER=" .. tostring(prof(p, "JEWELER")) ..
                " GEM_CUTTER=" .. tostring(prof(p, "GEM_CUTTER")) ..
                " GEM_SETTER=" .. tostring(prof(p, "GEM_SETTER"))))

            -- ---- boot Pass 3 civ_tech ----
            -- has_forge_mood gates the whole metal knowledge build.
            -- has_gem_mood currently reads POTASH_MAKER.
            print(string.format("  %-14s now=%-6s proposed=%-6s %s",
                "civ_tech metal", tostring(smelt_now),
                tostring(prof(p, "FURNACE_OPERATOR") or forge_prof),
                mark(smelt_now, (prof(p, "FURNACE_OPERATOR") or forge_prof) and true or false)))
            print(string.format("  %-14s now=%-6s proposed=%-6s %s",
                "civ_tech gems", tostring(raw(p, 54) or false),
                tostring(any(p, { "JEWELER", "GEM_CUTTER", "GEM_SETTER" })),
                mark(raw(p, 54) or false,
                     any(p, { "JEWELER", "GEM_CUTTER", "GEM_SETTER" }))))
        end
    end
end

print("")
print("WHAT TO LOOK FOR")
print(string.rep("=", 78))
print("  Any civ where 'civ_tech metal' says GAINS or LOSES will have its")
print("  entire known-metals set change when boot is corrected. That is the")
print("  one with reach beyond the ports, and it decides whether the boot")
print("  fix is safe to make at all.")
print("")
print("  A 'nil' anywhere means the profession name does not exist and the")
print("  proposed gate would be wrong. Nothing should be changed on a nil.")
print("")
