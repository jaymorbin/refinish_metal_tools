--@ module = true
-- refinish-permitted-job-enum.lua
-- ==========================================
-- IDENTIFY THE permitted_job INDEX ENUM
-- ==========================================
-- entity_raw.jobs.permitted_job has 135 slots and answers to string
-- keys like "POTTER" and "GLAZER". Those are not unit_labor names
-- (df.unit_labor.POTTER is nil), so the array is indexed by some
-- other enum. This identifies which, and shows exactly what RM's
-- mood gates have been reading instead.
--
-- Usage:
--   refinish-permitted-job-enum
--
-- No writes. Read only.
-- ==========================================

print("")
print("PERMITTED_JOB INDEX IDENTIFICATION")
print(string.rep("=", 68))

-- ---- STEP 1: SIZE THE CANDIDATE ENUMS ----
-- pairs() does not enumerate DFHack enums, so walk numerically until
-- the reverse lookup stops returning a name. That is a real count.
local function enum_size(enum, label)
    if not enum then
        print(string.format("  %-16s unavailable", label))
        return nil
    end
    local n = 0
    for i = 0, 2000 do
        local ok, name = pcall(function() return enum[i] end)
        if not ok or name == nil then break end
        n = i + 1
    end
    print(string.format("  %-16s %d entries", label, n))
    return n
end

print("")
print("ENUM SIZES")
print(string.rep("-", 68))
enum_size(df.profession, "df.profession")
enum_size(df.unit_labor, "df.unit_labor")
enum_size(df.job_type,   "df.job_type")

-- ---- STEP 2: NAME LOOKUPS ----
print("")
print("NAME -> INDEX")
print(string.rep("-", 68))
local function show(enum, ename, key)
    if not enum then return end
    local ok, v = pcall(function() return enum[key] end)
    print(string.format("  %-16s . %-14s = %s", ename, key, ok and tostring(v) or "ERROR"))
end
for _, k in ipairs({ "MASON", "POTTER", "GLAZER", "GLASSMAKER" }) do
    show(df.profession, "df.profession", k)
    show(df.unit_labor, "df.unit_labor", k)
end

-- ---- STEP 3: WHAT THE MOOD GATES ACTUALLY READ ----
-- Reverse-resolve the numeric indices the gates use, through the
-- enum that the array is actually indexed by.
print("")
print("WHAT THE MOOD GATE INDICES POINT AT")
print(string.rep("-", 68))
local moods = { "StrangeMoodForge", "StrangeMoodMagmaForge",
                "StrangeMoodMason", "StrangeMoodJeweller" }
for _, m in ipairs(moods) do
    local idx = df.job_type and df.job_type[m]
    local prof = "?"
    if type(idx) == "number" and df.profession then
        local ok, n = pcall(function() return df.profession[idx] end)
        if ok and n ~= nil then prof = tostring(n) end
    end
    print(string.format("  df.job_type.%-22s = %-5s -> profession[%s] = %s",
        m, tostring(idx), tostring(idx), prof))
end

-- ---- STEP 4: ONE CIV, DEDUPED ----
-- MOUNTAIN only. It has nearly everything set, which is what made
-- the bad reads look believable.
print("")
print("MOUNTAIN, READ BOTH WAYS")
print(string.rep("-", 68))
for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization
       and civ.entity_raw and civ.entity_raw.code == "MOUNTAIN" then
        local p = civ.entity_raw.jobs.permitted_job
        print(string.format("  array length = %d", #p))
        for _, k in ipairs({ "MASON", "POTTER", "GLAZER", "GLASSMAKER" }) do
            local pi = df.profession and df.profession[k]
            local by_name, by_idx = "ERROR", "n/a"
            local ok1, v1 = pcall(function() return p[k] end)
            if ok1 then by_name = tostring(v1) end
            if type(pi) == "number" then
                local ok2, v2 = pcall(function() return p[pi] end)
                if ok2 then by_idx = tostring(v2) end
            end
            print(string.format("    %-12s  p[\"%s\"] = %-6s  p[df.profession.%s = %s] = %s",
                k, k, by_name, k, tostring(pi), by_idx))
        end
        break
    end
end

print("")
print("VERDICT")
print(string.rep("=", 68))
print("  If df.profession's size matches the array length of 135, and")
print("  p[\"MASON\"] equals p[df.profession.MASON], the array is indexed")
print("  by df.profession.")
print("")
print("  In that case every df.job_type read against it is landing on an")
print("  unrelated profession slot, and STEP 3 above names exactly which")
print("  ones the SMELTER, KILN, FORGE and JEWELER gates were testing.")
print("")
