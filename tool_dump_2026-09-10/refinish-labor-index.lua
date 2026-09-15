--@ module = true
-- refinish-labor-index.lua
-- ==========================================
-- PERMITTED_JOB INDEX CHECK
-- ==========================================
-- Answers one question: is entity_raw.jobs.permitted_job indexed by
-- df.job_type, or by df.unit_labor?
--
-- It matters because RM's mood gates (SMELTER, KILN, FORGE) and boot
-- Pass 3's civ_tech evaluation both index it with df.job_type values.
-- If the array is actually unit_labor indexed, those reads land on
-- unrelated labors and every mood result is meaningless.
--
-- Usage:
--   refinish-labor-index
--
-- The test is direct. If the array is unit_labor indexed, then the
-- numeric slot for df.unit_labor.MASON must hold the same value as
-- the string key "MASON", and the array length must match the labor
-- count rather than the job count.
-- ==========================================

print("")
print("PERMITTED_JOB INDEX CHECK")
print(string.rep("=", 66))

-- ---- ENUM SIZES ----
-- Whichever enum the array length matches is the one indexing it.
local function enum_count(enum, label)
    if not enum then
        print(string.format("  %-14s not available", label))
        return nil
    end
    local n = 0
    for _ in pairs(enum) do n = n + 1 end
    print(string.format("  %-14s roughly %d entries", label, n))
    return n
end

print("")
print("ENUMS")
print(string.rep("-", 66))
enum_count(df.job_type,    "df.job_type")
enum_count(df.unit_labor,  "df.unit_labor")

print("")
print(string.format("  df.job_type.StrangeMoodMason = %s", tostring(df.job_type and df.job_type.StrangeMoodMason)))
print(string.format("  df.unit_labor.MASON          = %s", tostring(df.unit_labor and df.unit_labor.MASON)))
print(string.format("  df.unit_labor.POTTER         = %s", tostring(df.unit_labor and df.unit_labor.POTTER)))

-- ---- THE ACTUAL TEST ----
-- Take the first civ with a populated array and compare reads.
print("")
print("READS AGAINST A LIVE CIV")
print(string.rep("-", 66))

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        local p = civ.entity_raw.jobs.permitted_job
        print("")
        print("  CIV [" .. civ.entity_raw.code .. "]  array length = " .. tostring(#p))

        local function read(desc, key)
            local ok, v = pcall(function() return p[key] end)
            print(string.format("    %-42s = %s", desc, ok and tostring(v) or "ERROR"))
        end

        read('p["MASON"]', "MASON")
        if df.unit_labor and df.unit_labor.MASON then
            read('p[df.unit_labor.MASON]  (" .. df.unit_labor.MASON .. ")',
                 df.unit_labor.MASON)
        end
        if df.job_type and df.job_type.StrangeMoodMason then
            read('p[df.job_type.StrangeMoodMason]', df.job_type.StrangeMoodMason)
        end
        read('p["POTTER"]', "POTTER")
        read('p["GLAZER"]', "GLAZER")
        read('p["GLASSMAKER"]', "GLASSMAKER")

        -- Only need one civ with real data to settle it, but MOUNTAIN
        -- is the useful one since it has everything set.
        if civ.entity_raw.code == "MOUNTAIN" then break end
    end
end

print("")
print("VERDICT")
print(string.rep("=", 66))
print("  If p[\"MASON\"] and p[df.unit_labor.MASON] agree, and the array")
print("  length matches the unit_labor count, the array is unit_labor")
print("  indexed and every df.job_type read against it is wrong.")
print("")
print("  In that case the mood gates in refinish-module-types.lua and")
print("  the civ_tech evaluation in refinish-boot.lua lines 618-624 are")
print("  both reading unrelated labors.")
print("")
