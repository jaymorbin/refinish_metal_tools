--@ module = true
-- refinish-civ-capability.lua
-- ==========================================
-- CIV CAPABILITY DIAGNOSTIC
-- ==========================================
-- Dumps the raw capability data RM's permission gates are built on,
-- for every civilization in the loaded world.
--
-- Written to answer one question directly: when the gate says a civ
-- "lacks KILN capability", is that true, or is RM reading the wrong
-- field?
--
-- Usage:
--   refinish-civ-capability
--
-- Reports four things per civ:
--
--   1. SHAPE OF permitted_job
--      The mood gate indexes this array by NUMBER (df.job_type), the
--      permitted_job gate indexes it by STRING ("GLASSMAKER"). Both
--      cannot be correct. This prints which access actually works, so
--      we stop guessing. The string path is wrapped in pcall inside
--      the gate and fails closed, so if it is wrong it rejects
--      silently and looks exactly like a real capability failure.
--
--   2. MOOD JOBS
--      Every StrangeMood* entry the civ actually has. This is what
--      the SMELTER, KILN and FORGE gates test against.
--
--   3. CRAFT JOBS
--      The named jobs the permitted_job gates test against, if named
--      access turns out to work at all.
--
--   4. PERMITTED BUILDINGS
--      The custom workshops the civ may build, resolved to codes.
--      This is the direct signal for custom workshops, and it is what
--      [PERMITTED_BUILDING:...] in an entity raw writes to. Note that
--      vanilla workshops such as the kiln do NOT appear here, so an
--      empty list does not mean a civ cannot use a kiln.
-- ==========================================

-- Jobs the gates currently test. Kept in one place so the output
-- lines up with BUILDING_CAPABILITY_GATES in refinish-module-types.
local MOOD_JOBS = {
    "StrangeMoodForge", "StrangeMoodMagmaForge",
    "StrangeMoodMason", "StrangeMoodJeweller",
    "StrangeMoodCarpenter", "StrangeMoodCraftsdwarf",
    "StrangeMoodGlassmaker", "StrangeMoodWeaver",
    "StrangeMoodLeatherworker", "StrangeMoodBonecarver",
}

local CRAFT_JOBS = {
    "MASON", "GLASSMAKER", "STONECRAFTER", "WOODCRAFTER",
    "BONE_CARVER", "JEWELER", "GEM_CUTTER", "GEM_SETTER",
    "POTTER", "WOOD_BURNER",
}


-- Resolve a custom workshop id to its code string.
local function workshop_code(bid)
    local ok, shops = pcall(function()
        return df.global.world.raws.buildings.workshops
    end)
    if not ok or not shops then return "?" end
    for _, ws in ipairs(shops) do
        local got, id = pcall(function() return ws.id end)
        if got and id == bid then return ws.code end
    end
    -- Fall back to vector position if the struct has no id field.
    if shops[bid] then return shops[bid].code .. " (by position)" end
    return "unresolved:" .. tostring(bid)
end


print("")
print("CIV CAPABILITY DUMP")
print(string.rep("=", 74))

local seen = {}

for _, civ in ipairs(df.global.world.entities.all) do
    if civ.type == df.historical_entity_type.Civilization and civ.entity_raw then
        local code = civ.entity_raw.code
        if not seen[code] then
            seen[code] = true

            print("")
            print("CIV [" .. code .. "]")
            print(string.rep("-", 74))

            local permitted = civ.entity_raw.jobs.permitted_job

            -- ---- 1. SHAPE OF permitted_job ----
            -- Try both access patterns and report which one works.
            local num_ok = false
            local num_val
            local ok_n = pcall(function()
                num_val = permitted[df.job_type.StrangeMoodForge]
            end)
            num_ok = ok_n and (num_val ~= nil)

            local str_ok = false
            local str_val
            local ok_s = pcall(function()
                str_val = permitted["MASON"]
            end)
            str_ok = ok_s and (str_val ~= nil)

            print(string.format("  access by NUMBER (df.job_type): %s",
                num_ok and ("works, returns " .. tostring(num_val)) or "FAILS or returns nil"))
            print(string.format("  access by STRING (\"MASON\")    : %s",
                str_ok and ("works, returns " .. tostring(str_val)) or "FAILS or returns nil"))

            -- ---- 2. MOOD JOBS ----
            local moods = {}
            for _, name in ipairs(MOOD_JOBS) do
                local jid = df.job_type[name]
                if type(jid) == "number" and jid >= 0 and jid < #permitted then
                    if permitted[jid] then
                        table.insert(moods, name)
                    end
                end
            end
            print("  mood jobs      : " .. (#moods > 0 and table.concat(moods, ", ") or "NONE"))

            -- ---- 3. CRAFT JOBS ----
            -- Only meaningful if string access works. Printed either
            -- way so the failure is visible rather than assumed.
            local crafts = {}
            for _, name in ipairs(CRAFT_JOBS) do
                local got, val = pcall(function() return permitted[name] end)
                if got and val then
                    table.insert(crafts, name)
                end
            end
            print("  craft jobs     : " .. (#crafts > 0 and table.concat(crafts, ", ")
                                            or "NONE (or string access unsupported)"))

            -- ---- 4. PERMITTED BUILDINGS ----
            local blds = {}
            local ok_b, list = pcall(function()
                return civ.entity_raw.workshops.permitted_building_id
            end)
            if ok_b and list then
                for _, bid in ipairs(list) do
                    table.insert(blds, workshop_code(bid))
                end
            end
            print("  custom workshops: " .. (#blds > 0 and table.concat(blds, ", ") or "none"))

            local ok_r, rlist = pcall(function()
                return civ.entity_raw.workshops.permitted_reaction_id
            end)
            print("  permitted reactions: " .. ((ok_r and rlist) and #rlist or "?"))
        end
    end
end

print("")
print("HOW TO READ THIS")
print(string.rep("=", 74))
print("  If STRING access fails, the permitted_job gates (GLASS_FURNACE,")
print("  MASON, CRAFTSMAN, JEWELER) are rejecting everything silently and")
print("  need to resolve through df.job_type like the mood gates do.")
print("")
print("  If a civ shows no StrangeMoodMason, the KILN gate is reporting")
print("  something real. If it shows one and was still rejected, the gate")
print("  is wrong.")
print("")
print("  Custom workshops listed here are what [PERMITTED_BUILDING:...]")
print("  granted. Vanilla workshops never appear, so this list cannot be")
print("  used to gate a kiln or a glass furnace.")
print("")
